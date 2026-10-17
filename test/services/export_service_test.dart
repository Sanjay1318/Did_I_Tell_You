import 'dart:convert';

import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../database/db_test_support.dart' show makeMemory;

/// Reads CSV text the way a spreadsheet would: quoted cells, doubled quotes
/// for a literal quote, and line breaks allowed inside quotes.
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

void main() {
  group('ExportService.csvCell', () {
    test('wraps the value in quotes', () {
      expect(ExportService.csvCell('hello'), '"hello"');
    });

    test('doubles quotes inside the value', () {
      expect(ExportService.csvCell('say "hi"'), '"say ""hi"""');
    });

    test('keeps commas (they are safe inside quotes)', () {
      expect(ExportService.csvCell('a, b'), '"a, b"');
    });

    test('turns line breaks into spaces', () {
      expect(ExportService.csvCell('one\ntwo'), '"one two"');
      expect(ExportService.csvCell('one\r\ntwo'), '"one two"');
      expect(ExportService.csvCell('one\rtwo'), '"one two"');
    });

    test('null becomes an empty cell', () {
      expect(ExportService.csvCell(null), '""');
    });

    test('numbers are written as text', () {
      expect(ExportService.csvCell(500.0), '"500.0"');
      expect(ExportService.csvCell(7), '"7"');
    });

    test('non-English text and emoji pass through untouched', () {
      expect(ExportService.csvCell('₹500 రూపాయలు 🧠'), '"₹500 రూపాయలు 🧠"');
    });
  });

  group('ExportService.buildCsv', () {
    test('an empty list gives just the header', () {
      expect(ExportService.buildCsv([]),
          'id,text,person,amount,category,created_at,location\n');
    });

    test('writes one row per memory in the column order of the header', () {
      final csv = ExportService.buildCsv([
        makeMemory(
          id: 5,
          text: 'Lent Rahul 500',
          person: 'Rahul',
          amount: 500,
          category: 'money',
          location: 'Cafe',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      expect(
        csv,
        'id,text,person,amount,category,created_at,location\n'
        '"5","Lent Rahul 500","Rahul","500.0","money",'
        '"2026-01-01T00:00:00.000Z","Cafe"\n',
      );
    });

    test('missing values become empty cells', () {
      final csv = ExportService.buildCsv([makeMemory(text: 'plain')]);
      final row = parseCsv(csv)[1];
      expect(row, ['', 'plain', '', '', 'general', '2026-01-01T00:00:00.000Z', '']);
    });

    test('quotes, commas and line breaks in the text keep each memory on one row',
        () {
      final csv = ExportService.buildCsv([
        makeMemory(id: 1, text: 'He said "pay me, today"\nthen left'),
        makeMemory(id: 2, text: 'second'),
      ]);
      final rows = parseCsv(csv);
      expect(rows, hasLength(3));
      expect(rows[1][1], 'He said "pay me, today" then left');
      expect(rows[2][1], 'second');
    });

    test('quotes and commas in the person and location are escaped too', () {
      final csv = ExportService.buildCsv([
        makeMemory(
          id: 1,
          person: 'Rahul "Rocky" K',
          location: 'Cafe, MG Road',
        ),
      ]);
      final row = parseCsv(csv)[1];
      expect(row, hasLength(7));
      expect(row[2], 'Rahul "Rocky" K');
      expect(row[6], 'Cafe, MG Road');
    });

    test('many memories give header + one row each, every row 7 cells wide',
        () {
      final csv = ExportService.buildCsv([
        for (var i = 0; i < 25; i++)
          makeMemory(id: i, text: 'note $i, with "quotes"', person: 'P$i'),
      ]);
      final rows = parseCsv(csv);
      expect(rows, hasLength(26));
      expect(rows.every((r) => r.length == 7), isTrue);
    });
  });

  group('ExportService.buildJson', () {
    test('writes a JSON list with one object per memory', () {
      final json = ExportService.buildJson([
        makeMemory(id: 1, text: 'a'),
        makeMemory(id: 2, text: 'b'),
      ]);
      final decoded = jsonDecode(json) as List;
      expect(decoded, hasLength(2));
      expect((decoded[0] as Map)['original_text'], 'a');
      expect((decoded[1] as Map)['id'], 2);
    });

    test('an empty list is an empty JSON list', () {
      expect(jsonDecode(ExportService.buildJson([])), isEmpty);
    });
  });

  group('ExportService.parseJsonBackup', () {
    List<int> bytesOf(Object value) => utf8.encode(jsonEncode(value));

    test('a full export can be read back without losing anything', () {
      final original = makeMemory(
        id: 3,
        text: 'Lent Rahul ₹500 🧠',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        category: 'money',
        person: 'Rahul',
        amount: 500,
        extractedDate: '2026-01-03T00:00:00.000',
        location: 'Cafe',
        isPinned: true,
        reminderAt: '2026-02-01T09:00:00.000',
        moneyStatus: 'settled',
        tags: ['loan', 'friends'],
        attachmentPaths: ['/a.jpg'],
        taskAction: 'collect',
        taskStatus: 'pending',
        recurrence: 'monthly',
        metadata: {'keywords': 'lent,rahul'},
      );

      final restored = ExportService.parseJsonBackup(
          utf8.encode(ExportService.buildJson([original]))).single;

      expect(restored.toMap(), original.toMap());
      expect(restored.createdAt, original.createdAt);
    });

    test('reads several memories in order', () {
      final result = ExportService.parseJsonBackup(utf8.encode(
          ExportService.buildJson([
        makeMemory(text: 'one'),
        makeMemory(text: 'two'),
      ])));
      expect(result.map((m) => m.originalText), ['one', 'two']);
    });

    test('an empty list is a valid, empty backup', () {
      expect(ExportService.parseJsonBackup(bytesOf([])), isEmpty);
    });

    test('rejects JSON that is not a list', () {
      expect(
        () => ExportService.parseJsonBackup(bytesOf({'a': 1})),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'The selected file is not a memory backup.')),
      );
    });

    test('rejects text that is not JSON at all', () {
      expect(() => ExportService.parseJsonBackup(utf8.encode('not json')),
          throwsFormatException);
    });

    test('skips list entries that are not objects', () {
      final result = ExportService.parseJsonBackup(bytesOf([
        1,
        'text',
        null,
        {
          'original_text': 'kept',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      ]));
      expect(result.map((m) => m.originalText), ['kept']);
    });

    test('an old backup without the newer columns gets sensible defaults', () {
      final memory = ExportService.parseJsonBackup(bytesOf([
        {
          'original_text': 'old note',
          'created_at': '2025-01-01T00:00:00.000Z',
          'updated_at': '2025-01-01T00:00:00.000Z',
        },
      ])).single;

      expect(memory.category, 'general');
      expect(memory.status, 'active');
      expect(memory.isPinned, isFalse);
      expect(memory.moneyStatus, 'open');
      expect(memory.tags, isEmpty);
      expect(memory.attachmentPaths, isEmpty);
      expect(memory.taskStatus, 'none');
      expect(memory.metadata, isEmpty);
    });

    test('an entry without text fails the whole import', () {
      expect(
        () => ExportService.parseJsonBackup(bytesOf([
          {'created_at': '2026-01-01T00:00:00.000Z'},
        ])),
        throwsA(isA<TypeError>()),
      );
    });

    test('returns real Memory objects', () {
      final result = ExportService.parseJsonBackup(bytesOf([
        {
          'original_text': 'x',
          'created_at': '2026-01-01T00:00:00.000Z',
          'updated_at': '2026-01-01T00:00:00.000Z',
        },
      ]));
      expect(result.single, isA<Memory>());
    });
  });

  group('ExportService.buildBackup', () {
    final fixedNow = DateTime.utc(2026, 10, 17, 8, 30);

    Map<String, dynamic> decode(String json) =>
        jsonDecode(json) as Map<String, dynamic>;

    test('is an object with the app, a version, the memories and the photos',
        () {
      final data = decode(ExportService.buildBackup(
          [makeMemory(id: 1, text: 'a')], const {},
          now: fixedNow));

      expect(data['app'], 'did_i_tell_you');
      expect(data['version'], 2);
      expect(data['exported_at'], '2026-10-17T08:30:00.000Z');
      expect((data['memories'] as List).single['original_text'], 'a');
      expect(data['attachments'], isEmpty);
    });

    test('holds photos next to the memories and refers to them by name', () {
      final json = ExportService.buildBackup(
        [
          makeMemory(
              text: 'with photo',
              attachmentPaths: ['/data/app/attachments/memory_1.jpg']),
        ],
        {
          '/data/app/attachments/memory_1.jpg': [1, 2, 3],
        },
      );

      final backup = ExportService.parseBackup(utf8.encode(json));
      expect(backup.memories.single.attachmentPaths, ['memory_1.jpg']);
      expect(backup.files, {
        'memory_1.jpg': [1, 2, 3]
      });
    });

    test('leaves out a photo that is no longer on the phone', () {
      final json = ExportService.buildBackup(
        [
          makeMemory(attachmentPaths: ['/gone/a.jpg', '/here/b.jpg']),
        ],
        {
          '/here/b.jpg': [9],
        },
      );

      final backup = ExportService.parseBackup(utf8.encode(json));
      expect(backup.memories.single.attachmentPaths, ['b.jpg']);
      expect(backup.files.keys, ['b.jpg']);
    });

    test('gives photos with the same file name different names', () {
      final json = ExportService.buildBackup(
        [
          makeMemory(text: 'one', attachmentPaths: ['/a/photo.jpg']),
          makeMemory(text: 'two', attachmentPaths: ['/b/photo.jpg']),
        ],
        {
          '/a/photo.jpg': [1],
          '/b/photo.jpg': [2],
        },
      );

      final backup = ExportService.parseBackup(utf8.encode(json));
      expect(backup.memories[0].attachmentPaths, ['photo.jpg']);
      expect(backup.memories[1].attachmentPaths, ['photo_2.jpg']);
      expect(backup.files, {
        'photo.jpg': [1],
        'photo_2.jpg': [2],
      });
    });

    test('stores a photo used by two memories once', () {
      final json = ExportService.buildBackup(
        [
          makeMemory(text: 'one', attachmentPaths: ['/a/photo.jpg']),
          makeMemory(text: 'two', attachmentPaths: ['/a/photo.jpg']),
        ],
        {
          '/a/photo.jpg': [1],
        },
      );

      final backup = ExportService.parseBackup(utf8.encode(json));
      expect(backup.files.keys, ['photo.jpg']);
      expect(backup.memories.map((m) => m.attachmentPaths),
          [['photo.jpg'], ['photo.jpg']]);
    });

    test('takes the file name from a Windows style path too', () {
      final json = ExportService.buildBackup(
        [
          makeMemory(attachmentPaths: [r'C:\data\attachments\pic.png']),
        ],
        {
          r'C:\data\attachments\pic.png': [5],
        },
      );

      final backup = ExportService.parseBackup(utf8.encode(json));
      expect(backup.memories.single.attachmentPaths, ['pic.png']);
    });

    test('keeps archived memories and every other field', () {
      final original = makeMemory(
        id: 4,
        text: 'Old parking spot',
        status: 'archived',
        isPinned: true,
        tags: ['car'],
        taskStatus: 'pending',
        recurrence: 'weekly',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final restored = ExportService.parseBackup(utf8.encode(
              ExportService.buildBackup([original], const {})))
          .memories
          .single;

      expect(restored.toMap(), original.toMap());
    });
  });

  group('ExportService.parseBackup', () {
    List<int> bytesOf(Object value) => utf8.encode(jsonEncode(value));
    final memoryJson = {
      'original_text': 'kept',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    };

    test('reads an older backup (a bare list) with no photos', () {
      final backup = ExportService.parseBackup(bytesOf([memoryJson]));

      expect(backup.memories.single.originalText, 'kept');
      expect(backup.files, isEmpty);
    });

    test('reads an object that has memories but no attachments', () {
      final backup = ExportService.parseBackup(bytesOf({
        'memories': [memoryJson],
      }));

      expect(backup.memories.single.originalText, 'kept');
      expect(backup.files, isEmpty);
    });

    test('rejects an object that has no list of memories', () {
      expect(
        () => ExportService.parseBackup(bytesOf({'memories': 'nope'})),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'The selected file is not a memory backup.')),
      );
    });

    test('skips a damaged photo and keeps the rest', () {
      final backup = ExportService.parseBackup(bytesOf({
        'memories': [memoryJson],
        'attachments': {
          'good.jpg': base64Encode([7, 8]),
          'bad.jpg': '***not base64***',
          'number.jpg': 42,
        },
      }));

      expect(backup.memories, hasLength(1));
      expect(backup.files, {
        'good.jpg': [7, 8]
      });
    });
  });

  group('ExportService.restoreAttachments', () {
    late List<MapEntry<String, List<int>>> writes;

    Future<void> write(String path, List<int> bytes) async =>
        writes.add(MapEntry(path, bytes));

    setUp(() => writes = []);

    test('writes each photo into the folder and points the memory at it',
        () async {
      final memory = makeMemory(text: 'x', attachmentPaths: ['a.jpg']);
      final backup = BackupData([memory], {
        'a.jpg': [1, 2],
      });

      final restored = await ExportService.restoreAttachments(
          backup, [memory], '/restore', write);

      final target = p.join('/restore', 'a.jpg');
      expect(restored.single.attachmentPaths, [target]);
      expect(writes.map((w) => w.key), [target]);
      expect(writes.single.value, [1, 2]);
    });

    test('writes a photo shared by two memories once', () async {
      final one = makeMemory(text: 'one', attachmentPaths: ['a.jpg']);
      final two = makeMemory(text: 'two', attachmentPaths: ['a.jpg']);
      final backup = BackupData([one, two], {
        'a.jpg': [1],
      });

      final restored = await ExportService.restoreAttachments(
          backup, [one, two], '/restore', write);

      expect(writes, hasLength(1));
      expect(restored[0].attachmentPaths, restored[1].attachmentPaths);
    });

    test('drops a photo that the backup does not contain', () async {
      final memory = makeMemory(
          text: 'x', attachmentPaths: ['missing.jpg', '/old/phone/a.jpg']);
      final backup = BackupData([memory]);

      final restored = await ExportService.restoreAttachments(
          backup, [memory], '/restore', write);

      expect(restored.single.attachmentPaths, isEmpty);
      expect(writes, isEmpty);
    });

    test('only ever writes inside the folder, whatever the file is called',
        () async {
      final memory =
          makeMemory(text: 'x', attachmentPaths: ['../../evil.jpg']);
      final backup = BackupData([memory], {
        '../../evil.jpg': [6],
      });

      final restored = await ExportService.restoreAttachments(
          backup, [memory], '/restore', write);

      final target = p.join('/restore', 'evil.jpg');
      expect(writes.map((w) => w.key), [target]);
      expect(restored.single.attachmentPaths, [target]);
    });

    test('leaves everything else about the memory alone', () async {
      final memory = makeMemory(
        id: 3,
        text: 'x',
        tags: ['t'],
        isPinned: true,
        attachmentPaths: ['a.jpg'],
      );
      final backup = BackupData([memory], {
        'a.jpg': [1],
      });

      final restored = (await ExportService.restoreAttachments(
              backup, [memory], '/restore', write))
          .single;

      expect({...restored.toMap()}..remove('attachment_paths'),
          {...memory.toMap()}..remove('attachment_paths'));
    });
  });
}

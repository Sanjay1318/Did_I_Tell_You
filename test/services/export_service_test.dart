import 'dart:convert';

import 'package:did_i_tell_you/models/memory.dart';
import 'package:did_i_tell_you/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

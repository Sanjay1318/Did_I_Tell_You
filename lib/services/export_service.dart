import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/memory.dart';

/// What a backup file holds: the memories and the photo files they refer to
/// (file name -> bytes). Old backups are a bare list and carry no photos.
class BackupData {
  const BackupData(this.memories, [this.files = const {}]);

  final List<Memory> memories;
  final Map<String, List<int>> files;
}

class ExportService {
  static Future<BackupData?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    return parseBackup(bytes);
  }

  /// Turns the bytes of a backup file into memories and photos. Understands
  /// the current format (an object with "memories" and "attachments") and the
  /// older one (a bare list of memories). Throws a [FormatException] if the
  /// file is neither.
  static BackupData parseBackup(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    List<dynamic> list;
    final files = <String, List<int>>{};
    if (decoded is List) {
      list = decoded;
    } else if (decoded is Map && decoded['memories'] is List) {
      list = decoded['memories'] as List;
      final attachments = decoded['attachments'];
      if (attachments is Map) {
        for (final entry in attachments.entries) {
          final name = entry.key;
          final data = entry.value;
          if (name is! String || data is! String) continue;
          try {
            files[name] = base64Decode(data);
          } on FormatException {
            // A damaged photo is left out; the memory itself still restores.
          }
        }
      }
    } else {
      throw const FormatException('The selected file is not a memory backup.');
    }
    final memories = list
        .whereType<Map>()
        .map((item) => Memory.fromMap(Map<String, dynamic>.from(item)))
        .toList();
    return BackupData(memories, files);
  }

  /// The memories of a backup file, without its photos.
  static List<Memory> parseJsonBackup(List<int> bytes) =>
      parseBackup(bytes).memories;

  /// The file name of [path], whichever slash it uses; null if it names no
  /// file ("", ".", "..").
  static String? _fileName(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    return (name.isEmpty || name == '.' || name == '..') ? null : name;
  }

  /// [name], or [name] with a number added before the extension if [used]
  /// already has it. The chosen name is added to [used].
  static String _uniqueName(String name, Set<String> used) {
    var candidate = name;
    var counter = 1;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final extension = dot > 0 ? name.substring(dot) : '';
    while (!used.add(candidate)) {
      counter++;
      candidate = '${stem}_$counter$extension';
    }
    return candidate;
  }

  /// A complete backup: every memory plus the photos in [photoBytes] (keyed
  /// by the path the memory stores). Photo paths in the file are replaced by
  /// bare file names so the backup works on any phone. A photo that is not in
  /// [photoBytes] (deleted from the phone) is left out of its memory.
  static String buildBackup(
    List<Memory> memories,
    Map<String, List<int>> photoBytes, {
    DateTime? now,
  }) {
    final used = <String>{};
    final nameByPath = <String, String>{};
    final photos = <String, String>{};
    final items = <Map<String, dynamic>>[];
    for (final memory in memories) {
      final names = <String>[];
      for (final path in memory.attachmentPaths) {
        final bytes = photoBytes[path];
        final baseName = _fileName(path);
        if (bytes == null || baseName == null) continue;
        final name =
            nameByPath.putIfAbsent(path, () => _uniqueName(baseName, used));
        photos.putIfAbsent(name, () => base64Encode(bytes));
        if (!names.contains(name)) names.add(name);
      }
      items.add({...memory.toMap(), 'attachment_paths': jsonEncode(names)});
    }
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'did_i_tell_you',
      'version': 2,
      'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'memories': items,
      'attachments': photos,
    });
  }

  /// Puts the photos of [backup] into [directory] (through [write]) and
  /// returns [memories] pointing at the new files. Only the file name of each
  /// photo is used, so a damaged or hostile backup cannot write elsewhere. A
  /// path whose photo is not in the backup (an older backup, or a damaged
  /// photo) is dropped: it would point at a file that is gone, and a stored
  /// path is later deleted along with its memory.
  static Future<List<Memory>> restoreAttachments(
    BackupData backup,
    List<Memory> memories,
    String directory,
    Future<void> Function(String path, List<int> bytes) write,
  ) async {
    final written = <String, String>{};
    final restored = <Memory>[];
    for (final memory in memories) {
      final paths = <String>[];
      for (final path in memory.attachmentPaths) {
        final bytes = backup.files[path];
        final name = _fileName(path);
        if (bytes != null && name != null) {
          var target = written[path];
          if (target == null) {
            target = p.join(directory, name);
            await write(target, bytes);
            written[path] = target;
          }
          paths.add(target);
        }
      }
      restored.add(memory.copyWith(attachmentPaths: paths));
    }
    return restored;
  }

  /// Reads the photos from disk and shares one JSON file that holds the
  /// memories and the photos.
  static Future<void> exportBackup(List<Memory> memories) async {
    final photoBytes = <String, List<int>>{};
    for (final path in memories.expand((m) => m.attachmentPaths).toSet()) {
      final file = File(path);
      if (await file.exists()) photoBytes[path] = await file.readAsBytes();
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/memory_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(buildBackup(memories, photoBytes));

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'My Memories Backup',
    );
  }

  /// Copies the photos of [backup] into the app's photo folder and returns
  /// [memories] pointing at them.
  static Future<List<Memory>> restorePhotos(
      BackupData backup, List<Memory> memories) async {
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(docs.path, 'attachments'));
    await directory.create(recursive: true);
    return restoreAttachments(backup, memories, directory.path,
        (path, bytes) => File(path).writeAsBytes(bytes));
  }

  /// The memories alone as a plain JSON list, the format of older backups.
  static String buildJson(List<Memory> memories) {
    final data = memories.map((m) => m.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// One CSV cell: always quoted, inner quotes doubled, line breaks flattened
  /// to spaces so every memory stays on one row.
  static String csvCell(Object? value) {
    final text = (value ?? '')
        .toString()
        .replaceAll('"', '""')
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
    return '"$text"';
  }

  static String buildCsv(List<Memory> memories) {
    final buffer = StringBuffer();
    buffer.writeln('id,text,person,amount,category,created_at,location');
    for (final m in memories) {
      buffer.writeln([
        m.id,
        m.originalText,
        m.person,
        m.amount,
        m.category,
        m.createdAt.toIso8601String(),
        m.location,
      ].map(csvCell).join(','));
    }
    return buffer.toString();
  }

  static Future<void> exportToCsv(List<Memory> memories) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/memory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buildCsv(memories));

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'My Memories Export (CSV)',
    );
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/memory.dart';

class ExportService {
  static Future<List<Memory>?> pickJsonBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    return parseJsonBackup(bytes);
  }

  /// Turns the bytes of a JSON backup file into memories. Throws a
  /// [FormatException] if the file is not a JSON list.
  static List<Memory> parseJsonBackup(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw const FormatException('The selected file is not a memory backup.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => Memory.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

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

  static Future<void> exportToJson(List<Memory> memories) async {
    final jsonStr = buildJson(memories);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/memory_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'My Memories Export',
    );
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

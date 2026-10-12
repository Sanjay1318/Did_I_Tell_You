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
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw const FormatException('The selected file is not a memory backup.');
    }
    return decoded
        .whereType<Map>()
        .map((item) => Memory.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<void> exportToJson(List<Memory> memories) async {
    final data = memories.map((m) => m.toMap()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

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
    final buffer = StringBuffer();
    buffer.writeln('id,text,person,amount,category,created_at,location');
    for (final m in memories) {
      final text = m.originalText.replaceAll('"', '""').replaceAll('\n', ' ');
      buffer.writeln(
          '"${m.id}","$text","${m.person ?? ''}","${m.amount ?? ''}","${m.category}","${m.createdAt.toIso8601String()}","${m.location ?? ''}"');
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/memory_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'My Memories Export (CSV)',
    );
  }
}

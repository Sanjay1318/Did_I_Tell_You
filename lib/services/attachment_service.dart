import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AttachmentService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImage(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (image == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    final attachmentDirectory =
        Directory(path.join(directory.path, 'attachments'));
    await attachmentDirectory.create(recursive: true);
    final extension = path.extension(image.path).isEmpty
        ? '.jpg'
        : path.extension(image.path);
    final destination = path.join(
      attachmentDirectory.path,
      'memory_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(image.path).copy(destination);
    return destination;
  }

  static Future<void> deleteFiles(Iterable<String> paths) async {
    for (final filePath in paths) {
      try {
        await File(filePath).delete();
      } catch (_) {
        // Missing files do not prevent the memory record from being updated.
      }
    }
  }
}

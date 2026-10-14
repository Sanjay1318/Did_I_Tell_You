import 'dart:io';

import 'package:did_i_tell_you/services/attachment_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Taking or choosing a photo needs the real camera and gallery, so that part
// stays on the manual checklist. Deleting the saved files is plain file work.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('attachment_service_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File makeFile(String name) =>
      File('${dir.path}/$name')..writeAsStringSync('data');

  group('AttachmentService.deleteFiles', () {
    test('deletes every listed file', () async {
      final a = makeFile('a.jpg');
      final b = makeFile('b.jpg');

      await AttachmentService.deleteFiles([a.path, b.path]);

      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isFalse);
    });

    test('leaves other files alone', () async {
      final doomed = makeFile('doomed.jpg');
      final safe = makeFile('safe.jpg');

      await AttachmentService.deleteFiles([doomed.path]);

      expect(safe.existsSync(), isTrue);
    });

    test('ignores files that do not exist and still deletes the rest',
        () async {
      final real = makeFile('real.jpg');

      await AttachmentService.deleteFiles(
          ['${dir.path}/missing.jpg', real.path]);

      expect(real.existsSync(), isFalse);
    });

    test('an empty list does nothing', () async {
      final file = makeFile('a.jpg');
      await AttachmentService.deleteFiles([]);
      expect(file.existsSync(), isTrue);
    });

    test('a path that is a folder does not stop the rest', () async {
      final sub = Directory('${dir.path}/sub')..createSync();
      final real = makeFile('real.jpg');

      await AttachmentService.deleteFiles([sub.path, real.path]);

      expect(real.existsSync(), isFalse);
    });
  });
}

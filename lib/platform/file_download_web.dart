import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Makes the browser download [content] as a file called [fileName].
void downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'application/json',
}) {
  final blob = web.Blob(
    <JSAny>[content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}

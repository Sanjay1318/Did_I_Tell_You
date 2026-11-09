/// Saving a file by download only exists in a browser.
void downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'application/json',
}) {
  throw UnsupportedError('Downloads are only available in a browser.');
}

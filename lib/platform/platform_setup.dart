import 'package:flutter/foundation.dart';

import 'web_database_stub.dart'
    if (dart.library.js_interop) 'web_database.dart';

/// Per-platform setup that must run before the database is opened.
Future<void> configurePlatform() async {
  if (kIsWeb) useWebDatabase();
}

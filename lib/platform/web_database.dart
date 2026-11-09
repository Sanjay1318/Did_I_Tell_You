import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// In a browser, SQLite runs as WebAssembly and keeps its data in IndexedDB.
/// The no-worker variant needs only `sqlite3.wasm` next to the app.
void useWebDatabase() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

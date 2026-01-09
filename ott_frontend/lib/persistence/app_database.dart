import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const int _schemaVersion = 1;
  static const String _dbName = 'streamease.db';

  Database? _db;

  Database get db {
    final Database? d = _db;
    if (d == null) {
      throw StateError('Database not opened. Call open() first.');
    }
    return d;
  }

  // PUBLIC_INTERFACE
  Future<void> open() async {
    if (_db != null) return;

    final String databasesPath = await getDatabasesPath();
    final String path = p.join(databasesPath, _dbName);

    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE downloads (
  id TEXT PRIMARY KEY,
  content_id TEXT NOT NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL,
  progress REAL NOT NULL,
  bytes_downloaded INTEGER NOT NULL,
  total_bytes INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');

        await db.execute('''
CREATE TABLE download_queue (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  paused INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');

        await db.execute('INSERT INTO download_queue(id, paused, updated_at_ms) VALUES (1, 0, 0)');

        await db.execute('''
CREATE TABLE watch_history (
  content_id TEXT PRIMARY KEY,
  position_seconds INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)
''');
      },
    );
  }

  // PUBLIC_INTERFACE
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

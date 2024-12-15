import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'database_interface.dart';
import 'models/database_record.dart';

/// SQLite implementation of [DatabaseInterface]
class SQLiteDatabase implements DatabaseInterface {
  static const String _tableName = 'records';
  sqflite.Database? _db;

  /// Get the database instance
  sqflite.Database get db {
    if (_db == null) {
      throw const PhxDatabaseException(
          'Database not initialized. Call init() first.');
    }
    return _db!;
  }

  @override
  Future<void> init() async {
    try {
      final databasesPath = await sqflite.getDatabasesPath();
      final path = join(databasesPath, 'phx_sync.db');

      _db = await sqflite.openDatabase(
        path,
        version: 1,
        onCreate: (sqflite.Database db, int version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT NOT NULL,
              version INTEGER NOT NULL,
              timestamp INTEGER NOT NULL,
              editor_id TEXT NOT NULL,
              sync_status INTEGER NOT NULL
            )
          ''');
        },
      );
    } catch (e) {
      throw PhxDatabaseException('Failed to initialize database', e);
    }
  }

  @override
  Future<DatabaseRecord> insert({
    required String data,
    required String editorId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final record = {
        'data': data,
        'version': 1,
        'timestamp': timestamp,
        'editor_id': editorId,
        'sync_status': SyncStatus.pending.index,
      };

      final id = await db.insert(_tableName, record);
      return DatabaseRecord.fromMap({
        'id': id,
        ...record,
      });
    } catch (e) {
      throw PhxDatabaseException('Failed to insert record', e);
    }
  }

  @override
  Future<DatabaseRecord> update({
    required int id,
    required String data,
    required String editorId,
  }) async {
    try {
      final existing = await get(id);
      if (existing == null) {
        throw PhxDatabaseException('Record not found: $id');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final record = {
        'data': data,
        'version': existing.version + 1,
        'timestamp': timestamp,
        'editor_id': editorId,
        'sync_status': SyncStatus.pending.index,
      };

      await db.update(
        _tableName,
        record,
        where: 'id = ?',
        whereArgs: [id],
      );

      return DatabaseRecord.fromMap({
        'id': id,
        ...record,
      });
    } catch (e) {
      throw PhxDatabaseException('Failed to update record', e);
    }
  }

  @override
  Future<void> delete({
    required int id,
    required String editorId,
  }) async {
    try {
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw PhxDatabaseException('Failed to delete record', e);
    }
  }

  @override
  Future<DatabaseRecord?> get(int id) async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        return null;
      }

      return DatabaseRecord.fromMap(maps.first);
    } catch (e) {
      throw PhxDatabaseException('Failed to get record', e);
    }
  }

  @override
  Future<List<DatabaseRecord>> getAll() async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(_tableName);
      return maps.map((map) => DatabaseRecord.fromMap(map)).toList();
    } catch (e) {
      throw PhxDatabaseException('Failed to get all records', e);
    }
  }

  @override
  Future<List<DatabaseRecord>> getPendingRecords() async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.pending.index],
      );
      return maps.map((map) => DatabaseRecord.fromMap(map)).toList();
    } catch (e) {
      throw PhxDatabaseException('Failed to get pending records', e);
    }
  }

  @override
  Future<List<DatabaseRecord>> getConflictedRecords() async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.conflict.index],
      );
      return maps.map((map) => DatabaseRecord.fromMap(map)).toList();
    } catch (e) {
      throw PhxDatabaseException('Failed to get conflicted records', e);
    }
  }

  @override
  Future<void> markAsSynced(int id) async {
    try {
      await db.update(
        _tableName,
        {'sync_status': SyncStatus.synced.index},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw PhxDatabaseException('Failed to mark record as synced', e);
    }
  }

  @override
  Future<void> markAsConflict(int id) async {
    try {
      await db.update(
        _tableName,
        {'sync_status': SyncStatus.conflict.index},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw PhxDatabaseException('Failed to mark record as conflict', e);
    }
  }

  @override
  Future<void> close() async {
    try {
      await db.close();
      _db = null;
    } catch (e) {
      throw PhxDatabaseException('Failed to close database', e);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await db.delete(_tableName);
    } catch (e) {
      throw PhxDatabaseException('Failed to clear database', e);
    }
  }
}

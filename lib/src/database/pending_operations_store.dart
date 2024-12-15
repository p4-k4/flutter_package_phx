import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'models/pending_operation.dart';

/// Stores and manages pending operations using SQLite
class PendingOperationsStore {
  static const String _tableName = 'pending_operations';
  sqflite.Database? _db;
  bool _initialized = false;
  final String? _testDbPath;
  static sqflite.Database? _sharedTestDb;

  PendingOperationsStore([this._testDbPath]);

  /// Get the database instance
  sqflite.Database get db {
    if (!_initialized || _db == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Reset shared test database
  static Future<void> resetSharedTestDb() async {
    if (_sharedTestDb != null) {
      await _sharedTestDb!.close();
      _sharedTestDb = null;
    }
  }

  /// Initialize the store
  Future<void> init() async {
    if (_initialized) return;

    try {
      if (_testDbPath != null) {
        if (_testDbPath == ':memory:') {
          // Use shared in-memory database for tests
          if (_sharedTestDb != null) {
            _db = _sharedTestDb;
            // Clear any existing data
            await _db!.delete(_tableName);
          } else {
            _db = await sqflite.openDatabase(
              ':memory:',
              version: 1,
              onCreate: _createDb,
              singleInstance: true,
            );
            _sharedTestDb = _db;
          }
        } else {
          // Use file-based database for persistence tests
          _db = await sqflite.openDatabase(
            _testDbPath!,
            version: 1,
            onCreate: _createDb,
            singleInstance: false,
          );
        }
      } else {
        final databasesPath = await sqflite.getDatabasesPath();
        final path = join(databasesPath, 'phx_pending_operations.db');
        _db = await sqflite.openDatabase(
          path,
          version: 1,
          onCreate: _createDb,
          singleInstance: false,
        );
      }

      _initialized = true;
    } catch (e) {
      print('Error initializing database: $e');
      _initialized = false;
      _db = null;
      rethrow;
    }
  }

  Future<void> _createDb(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic TEXT NOT NULL,
        event TEXT NOT NULL,
        payload TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  /// Add a pending operation
  Future<PendingOperation> add(PendingOperation operation) async {
    try {
      final map = operation.toJson();
      map['payload'] = jsonEncode(operation.payload);

      final id = await db.transaction((txn) async {
        return await txn.insert(_tableName, map);
      });

      return operation.copyWith(id: id);
    } catch (e) {
      print('Error adding operation: $e');
      await _handleError(e);
      rethrow;
    }
  }

  /// Remove a pending operation
  Future<void> remove(PendingOperation operation) async {
    try {
      if (operation.id == null) return;
      await db.transaction((txn) async {
        await txn.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [operation.id],
        );
      });
    } catch (e) {
      print('Error removing operation: $e');
      await _handleError(e);
      rethrow;
    }
  }

  /// Get all pending operations ordered by timestamp
  Future<List<PendingOperation>> getAll() async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        orderBy: 'timestamp ASC',
      );

      return maps.map((map) {
        final json = Map<String, dynamic>.from(map);
        json['payload'] = jsonDecode(map['payload'] as String);
        return PendingOperation.fromJson(json);
      }).toList();
    } catch (e) {
      print('Error getting operations: $e');
      await _handleError(e);
      rethrow;
    }
  }

  /// Remove all pending operations
  Future<void> clear() async {
    try {
      await db.transaction((txn) async {
        await txn.delete(_tableName);
      });
    } catch (e) {
      print('Error clearing operations: $e');
      await _handleError(e);
      rethrow;
    }
  }

  /// Close the store
  Future<void> close() async {
    if (_initialized && _db != null) {
      try {
        if (_testDbPath == ':memory:' && _db == _sharedTestDb) {
          // Don't close shared in-memory database
          return;
        }
        await _db!.close();
      } catch (e) {
        print('Error closing database: $e');
      } finally {
        if (_testDbPath != ':memory:' || _db != _sharedTestDb) {
          _db = null;
          _initialized = false;
        }
      }
    }
  }

  /// Remove operations that match the given criteria
  Future<void> removeWhere({
    required String topic,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final encodedPayload = jsonEncode(payload);
      await db.transaction((txn) async {
        await txn.delete(
          _tableName,
          where: 'topic = ? AND event = ? AND payload = ?',
          whereArgs: [topic, event, encodedPayload],
        );
      });
    } catch (e) {
      print('Error removing operations by criteria: $e');
      await _handleError(e);
      rethrow;
    }
  }

  /// Handle database errors
  Future<void> _handleError(dynamic error) async {
    // If we get a database lock or I/O error, try to close and reopen
    if (error is sqflite.DatabaseException &&
        (error.toString().contains('database is locked') ||
            error.toString().contains('disk I/O error'))) {
      await close();
      await init();
    }
  }
}

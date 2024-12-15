import 'database_interface.dart';
import 'models/database_record.dart';
import 'strategies/sync_strategy.dart';

/// Manages database operations and sync coordination
class DatabaseManager {
  final DatabaseInterface _database;
  final SyncStrategy _syncStrategy;

  /// Whether the database has been initialized
  bool _initialized = false;

  /// Create a new database manager
  DatabaseManager({
    required DatabaseInterface database,
    required SyncStrategy syncStrategy,
  })  : _database = database,
        _syncStrategy = syncStrategy;

  /// Initialize the database manager
  Future<void> init() async {
    if (_initialized) return;
    await _database.init();
    _initialized = true;
  }

  /// Insert a new record
  Future<DatabaseRecord> insert({
    required String data,
    required String editorId,
  }) async {
    _ensureInitialized();
    return _database.insert(
      data: data,
      editorId: editorId,
    );
  }

  /// Update an existing record
  Future<DatabaseRecord> update({
    required int id,
    required String data,
    required String editorId,
  }) async {
    _ensureInitialized();
    return _database.update(
      id: id,
      data: data,
      editorId: editorId,
    );
  }

  /// Delete a record
  Future<void> delete({
    required int id,
    required String editorId,
  }) async {
    _ensureInitialized();
    await _database.delete(
      id: id,
      editorId: editorId,
    );
  }

  /// Get a record by ID
  Future<DatabaseRecord?> get(int id) async {
    _ensureInitialized();
    return _database.get(id);
  }

  /// Get all records
  Future<List<DatabaseRecord>> getAll() async {
    _ensureInitialized();
    return _database.getAll();
  }

  /// Get records with pending changes
  Future<List<DatabaseRecord>> getPendingRecords() async {
    _ensureInitialized();
    return _database.getPendingRecords();
  }

  /// Get records with conflicts
  Future<List<DatabaseRecord>> getConflictedRecords() async {
    _ensureInitialized();
    return _database.getConflictedRecords();
  }

  /// Handle sync conflict between local and server records
  Future<DatabaseRecord> handleConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) async {
    _ensureInitialized();

    final resolution = await _syncStrategy.resolveConflict(
      local: local,
      server: server,
    );

    if (resolution.shouldApply) {
      if (resolution.record == local) {
        // Keep local changes, mark as pending
        await _database.update(
          id: local.id,
          data: local.data,
          editorId: local.editorId,
        );
      } else {
        // Use server version
        await _database.update(
          id: server.id,
          data: server.data,
          editorId: server.editorId,
        );
        await _database.markAsSynced(server.id);
      }
    }

    return resolution.record;
  }

  /// Mark a record as synced with the server
  Future<void> markAsSynced(int id) async {
    _ensureInitialized();
    await _database.markAsSynced(id);
  }

  /// Mark a record as having a conflict
  Future<void> markAsConflict(int id) async {
    _ensureInitialized();
    await _database.markAsConflict(id);
  }

  /// Close the database
  Future<void> close() async {
    if (!_initialized) return;
    await _database.close();
    _initialized = false;
  }

  /// Clear all records (useful for testing)
  Future<void> clear() async {
    _ensureInitialized();
    await _database.clear();
  }

  /// Ensure the database manager is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw const PhxDatabaseException(
        'DatabaseManager not initialized. Call init() first.',
      );
    }
  }
}

import 'models/database_record.dart';

/// Interface for database operations with sync support
abstract class DatabaseInterface {
  /// Initialize the database
  Future<void> init();

  /// Insert a new record
  Future<DatabaseRecord> insert({
    required String data,
    required String editorId,
  });

  /// Update an existing record
  Future<DatabaseRecord> update({
    required int id,
    required String data,
    required String editorId,
  });

  /// Delete a record
  Future<void> delete({
    required int id,
    required String editorId,
  });

  /// Get a record by ID
  Future<DatabaseRecord?> get(int id);

  /// Get all records
  Future<List<DatabaseRecord>> getAll();

  /// Get records with pending changes
  Future<List<DatabaseRecord>> getPendingRecords();

  /// Get records with conflicts
  Future<List<DatabaseRecord>> getConflictedRecords();

  /// Mark a record as synced
  Future<void> markAsSynced(int id);

  /// Mark a record as having a conflict
  Future<void> markAsConflict(int id);

  /// Close the database
  Future<void> close();

  /// Delete all records (useful for testing)
  Future<void> clear();
}

/// Exception thrown when a database operation fails
class PhxDatabaseException implements Exception {
  final String message;
  final dynamic error;

  const PhxDatabaseException(this.message, [this.error]);

  @override
  String toString() =>
      'PhxDatabaseException: $message${error != null ? ' ($error)' : ''}';
}

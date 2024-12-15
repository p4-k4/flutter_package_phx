/// Represents the sync status of a record in the database
enum SyncStatus {
  /// Record is synced with the server
  synced,

  /// Record has pending changes to be synced
  pending,

  /// Record has conflicts that need resolution
  conflict,
}

/// Base class for database records with sync support
class DatabaseRecord {
  /// Unique identifier for the record
  final int id;

  /// JSON encoded data for the record
  final String data;

  /// Version number for tracking changes
  final int version;

  /// Timestamp of last modification (milliseconds since epoch)
  final int timestamp;

  /// ID of the user/entity that last modified the record
  final String editorId;

  /// Current sync status of the record
  final SyncStatus syncStatus;

  DatabaseRecord({
    required this.id,
    required this.data,
    required this.version,
    required this.timestamp,
    required this.editorId,
    required this.syncStatus,
  });

  /// Create a record from a database map
  factory DatabaseRecord.fromMap(Map<String, dynamic> map) {
    return DatabaseRecord(
      id: map['id'] as int,
      data: map['data'] as String,
      version: map['version'] as int,
      timestamp: map['timestamp'] as int,
      editorId: map['editor_id'] as String,
      syncStatus: SyncStatus.values[map['sync_status'] as int],
    );
  }

  /// Convert record to a database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data,
      'version': version,
      'timestamp': timestamp,
      'editor_id': editorId,
      'sync_status': syncStatus.index,
    };
  }

  /// Create a copy of this record with updated fields
  DatabaseRecord copyWith({
    int? id,
    String? data,
    int? version,
    int? timestamp,
    String? editorId,
    SyncStatus? syncStatus,
  }) {
    return DatabaseRecord(
      id: id ?? this.id,
      data: data ?? this.data,
      version: version ?? this.version,
      timestamp: timestamp ?? this.timestamp,
      editorId: editorId ?? this.editorId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

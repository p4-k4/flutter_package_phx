import '../models/database_record.dart';

/// Result of conflict resolution
class ConflictResolution {
  /// The resolved record to use
  final DatabaseRecord record;

  /// Whether the resolution should be applied
  final bool shouldApply;

  ConflictResolution({
    required this.record,
    required this.shouldApply,
  });

  /// Create a resolution that applies the given record
  factory ConflictResolution.apply(DatabaseRecord record) {
    return ConflictResolution(record: record, shouldApply: true);
  }

  /// Create a resolution that skips applying changes
  factory ConflictResolution.skip(DatabaseRecord record) {
    return ConflictResolution(record: record, shouldApply: false);
  }
}

/// Interface for sync conflict resolution strategies
abstract class SyncStrategy {
  /// Name of the strategy
  String get name;

  /// Description of how the strategy works
  String get description;

  /// Resolve a conflict between local and server records
  ///
  /// [local] is the local version of the record
  /// [server] is the server version of the record
  /// Returns a [ConflictResolution] indicating how to resolve the conflict
  Future<ConflictResolution> resolveConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  });
}

/// Strategy that always takes the most recently modified version
class LastWriteWinsStrategy implements SyncStrategy {
  @override
  String get name => 'Last Write Wins';

  @override
  String get description =>
      'Uses the most recently modified version of the record';

  @override
  Future<ConflictResolution> resolveConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) async {
    if (local.timestamp >= server.timestamp) {
      return ConflictResolution.apply(local);
    } else {
      return ConflictResolution.apply(server);
    }
  }
}

/// Strategy that always takes the server version
class ServerWinsStrategy implements SyncStrategy {
  @override
  String get name => 'Server Wins';

  @override
  String get description => 'Always uses the server version of the record';

  @override
  Future<ConflictResolution> resolveConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) async {
    return ConflictResolution.apply(server);
  }
}

/// Strategy that always takes the local version
class ClientWinsStrategy implements SyncStrategy {
  @override
  String get name => 'Client Wins';

  @override
  String get description => 'Always uses the local version of the record';

  @override
  Future<ConflictResolution> resolveConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) async {
    return ConflictResolution.apply(local);
  }
}

/// Strategy that attempts to merge changes with custom logic
class MergeStrategy implements SyncStrategy {
  final Future<ConflictResolution> Function({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) _resolveCallback;

  MergeStrategy(this._resolveCallback);

  @override
  String get name => 'Custom Merge';

  @override
  String get description => 'Uses custom logic to merge changes';

  @override
  Future<ConflictResolution> resolveConflict({
    required DatabaseRecord local,
    required DatabaseRecord server,
  }) async {
    return _resolveCallback(local: local, server: server);
  }
}

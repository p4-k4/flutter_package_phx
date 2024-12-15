import 'dart:async';
import 'package:phx/src/database/database.dart';
import 'package:phx/src/phx_client.dart';

/// Represents the current state of the sync manager
enum SyncState {
  /// Not connected to the server
  disconnected,

  /// Connected to the server and ready to process operations
  connected,

  /// Currently syncing operations with the server
  syncing,
}

/// Manages synchronization between local and remote state
class SyncManager {
  final String endpoint;
  final PhxClient client;
  final String? testDbPath;
  final bool autoConnect;
  final _stateController = StreamController<SyncState>.broadcast();
  final Map<String, bool> _joinedChannels = {};
  late final PendingOperationsStore _store;
  bool _disposed = false;
  SyncState _currentState = SyncState.disconnected;

  SyncManager({
    required this.endpoint,
    required this.client,
    this.testDbPath,
    this.autoConnect = true,
  }) {
    _store = PendingOperationsStore(testDbPath);
  }

  /// Initialize the sync manager
  Future<void> init() async {
    if (_disposed) return;

    await _store.init();

    // Listen for connection state changes
    client.connectionStateStream?.listen((connected) {
      if (_disposed) return;

      if (connected) {
        _handleConnect();
      } else {
        _handleDisconnect();
      }
    });

    // Auto connect if enabled
    if (autoConnect) {
      await connect();
    }
  }

  /// Get the current sync state
  SyncState get currentState => _currentState;

  /// Get the sync state stream
  Stream<SyncState> get syncStateStream => _stateController.stream;

  /// Get all pending operations
  Future<List<PendingOperation>> get pendingOperations async {
    return await _store.getAll();
  }

  /// Connect to the server
  Future<void> connect() async {
    if (_disposed) return;

    try {
      _setState(SyncState.syncing);
      await client.connect();
      _setState(SyncState.connected);

      // Process any pending operations
      final operations = await _store.getAll();
      if (operations.isNotEmpty) {
        print('Processing ${operations.length} pending operations...');
        _setState(SyncState.syncing);
        for (final operation in operations) {
          await _processOperation(operation);
        }
        _setState(SyncState.connected);
      }
    } catch (e) {
      print('Connection error: $e');
      _setState(SyncState.disconnected);
    }
  }

  /// Join a channel
  Future<Map<String, dynamic>> joinChannel(String topic) async {
    if (_disposed) return {'status': 'error', 'reason': 'disposed'};

    if (!client.isConnected()) {
      print('Not connected, cannot join channel: $topic');
      return {'status': 'offline'};
    }

    try {
      final result = await client.joinChannel(topic);
      if (result['status'] == 'ok') {
        _joinedChannels[topic] = true;
      }
      return result;
    } catch (e) {
      print('Error joining channel: $e');
      return {'status': 'error', 'reason': e.toString()};
    }
  }

  /// Push an event to a channel
  Future<Map<String, dynamic>> push(
    String topic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (_disposed) return {'status': 'error', 'reason': 'disposed'};

    if (!client.isConnected() || !_joinedChannels.containsKey(topic)) {
      print('Not connected or channel not joined queueing operation: $event');
      final operation = PendingOperation(
        topic: topic,
        event: event,
        payload: payload,
      );
      await _store.add(operation);
      return {'status': 'queued'};
    }

    try {
      return await client.push(topic, event, payload);
    } catch (e) {
      print('Error pushing event: $e');
      return {'status': 'error', 'reason': e.toString()};
    }
  }

  /// Process a pending operation
  Future<void> _processOperation(PendingOperation operation) async {
    if (_disposed) return;

    try {
      // Ensure channel is joined before processing operation
      if (!_joinedChannels.containsKey(operation.topic)) {
        print(
            'Channel ${operation.topic} not joined joining before processing operation');
        await _rejoinChannel(operation.topic);
      }

      print('Processing operation: ${operation.event} on ${operation.topic}');
      final result = await client.push(
        operation.topic,
        operation.event,
        operation.payload,
      );

      if (result['status'] == 'ok') {
        await _store.remove(operation);
      }
    } catch (e) {
      print('Error processing operation: $e');
    }
  }

  /// Rejoin a channel
  Future<void> _rejoinChannel(String topic) async {
    if (_disposed) return;

    try {
      print('Rejoining channel: $topic');
      final result = await joinChannel(topic);
      if (result['status'] == 'ok') {
        print('Successfully rejoined channel: $topic');
      } else {
        print('Failed to rejoin channel: $topic');
      }
    } catch (e) {
      print('Error rejoining channel: $e');
    }
  }

  /// Handle server connection
  void _handleConnect() {
    if (_disposed) return;
    _setState(SyncState.connected);
  }

  /// Handle server disconnection
  void _handleDisconnect() {
    if (_disposed) return;
    _joinedChannels.clear();
    _setState(SyncState.disconnected);
  }

  /// Update the sync state
  void _setState(SyncState newState) {
    if (_disposed) return;
    if (_currentState != newState) {
      print('SyncManager state changing from $_currentState to $newState');
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  /// Clean up resources
  Future<void> dispose() async {
    if (_disposed) return;
    print('Disposing SyncManager');
    _disposed = true;
    await _stateController.close();
    await _store.close();
  }
}

import 'dart:async';
import 'dart:io';
// import 'package:flutter/foundation.dart';
import 'package:phx/src/phx_client.dart';

enum SyncState {
  connected,
  disconnected,
  syncing,
}

/// Represents a pending operation that needs to be synced with the server
class PendingOperation {
  final String topic;
  final String event;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  PendingOperation({
    required this.topic,
    required this.event,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'topic': topic,
        'event': event,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      topic: json['topic'] as String,
      event: json['event'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class SyncManager {
  final String endpoint;
  final PhxClient client;
  final _syncStateController = StreamController<SyncState>.broadcast();
  final Map<String, Map<String, Function(Map<String, dynamic>)>> _handlers = {};
  final List<PendingOperation> _pendingOperations = [];
  final Map<String, bool> _joinedChannels = {};
  bool _initialized = false;
  bool _disposed = false;
  SyncState _currentState = SyncState.disconnected;
  Timer? _reconnectTimer;
  Timer? _connectionCheckTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 1;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _connectionCheckInterval = Duration(seconds: 5);
  StreamSubscription? _messageSubscription;
  bool _isReconnecting = false;

  SyncManager({
    required this.endpoint,
    required this.client,
  }) {
    _setupMessageListener();
    _startConnectionCheck();
  }

  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(_connectionCheckInterval, (_) async {
      if (!_disposed && !_isReconnecting) {
        print('Checking connection status...');
        try {
          final socket = await WebSocket.connect('$endpoint?vsn=2.0.0')
              .timeout(const Duration(seconds: 2));
          await socket.close();
          print('Server is available');

          if (_currentState == SyncState.disconnected) {
            print('Attempting reconnect...');
            _attemptReconnect();
          }
        } catch (e) {
          print('Server not available: $e');
          if (_currentState != SyncState.disconnected) {
            _handleDisconnect();
          }
        }
      }
    });
  }

  Future<void> _attemptReconnect() async {
    if (_disposed || _isReconnecting) return;

    try {
      _isReconnecting = true;
      await connect();
      _isReconnecting = false;
    } catch (e) {
      print('Reconnection attempt failed: $e');
      _isReconnecting = false;
      _handleDisconnect();
    }
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();
    _messageSubscription = client.messageStream?.listen(
      (message) {
        // Handle incoming messages
        if (!_disposed) {
          if (message.topic == "phoenix") {
            // Handle Phoenix system messages
            if (_currentState != SyncState.connected && !_isReconnecting) {
              _setState(SyncState.connected);
            }
          } else {
            // Handle application messages
            if (_currentState != SyncState.connected) {
              _setState(SyncState.connected);
            }
          }
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
        if (!_isReconnecting) {
          _handleDisconnect();
        }
      },
      onDone: () {
        print('WebSocket connection closed');
        if (!_isReconnecting) {
          _handleDisconnect();
        }
      },
    );

    // Also listen to client's connection state
    client.connectionStateStream?.listen((connected) {
      if (!connected && _currentState != SyncState.disconnected) {
        _handleDisconnect();
      }
    });
  }

  Stream<SyncState> get syncStateStream => _syncStateController.stream;
  SyncState get currentState => _currentState;
  List<PendingOperation> get pendingOperations =>
      List.unmodifiable(_pendingOperations);

  Future<void> init() async {
    if (_initialized || _disposed) return;
    _initialized = true;

    try {
      await connect();
    } catch (e) {
      print('Initial connection failed: $e');
      _setState(SyncState.disconnected);
      // Don't rethrow - let the app continue in offline mode
    }
  }

  Future<void> connect() async {
    if (_disposed) return;

    try {
      _setState(SyncState.syncing);
      await client.connect();
      _joinedChannels.clear();

      // Re-join channels and re-establish handlers after reconnection
      for (final topic in _handlers.keys) {
        await _rejoinChannel(topic);
      }

      _setState(SyncState.connected);
      _reconnectAttempts = 0;

      // Process any pending operations after successful connection and channel joins
      if (_pendingOperations.isNotEmpty) {
        await _processPendingOperations();
      }
    } catch (e) {
      print('Connection error: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) return;

    print('Processing ${_pendingOperations.length} pending operations...');
    _setState(SyncState.syncing);

    try {
      // Sort operations by timestamp
      _pendingOperations.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Process each operation in order
      final operations = List.from(_pendingOperations);
      for (final op in operations) {
        try {
          // Ensure channel is joined before processing operation
          if (!_joinedChannels.containsKey(op.topic) ||
              !_joinedChannels[op.topic]!) {
            print(
                'Channel ${op.topic} not joined, joining before processing operation');
            await _rejoinChannel(op.topic);
          }

          print('Processing operation: ${op.event} on ${op.topic}');
          await client.push(op.topic, op.event, op.payload);
          _pendingOperations.remove(op);
        } catch (e) {
          print('Failed to process operation: $e');
          // Keep operation in queue if it fails
          break;
        }
      }
    } finally {
      if (_currentState != SyncState.disconnected) {
        _setState(SyncState.connected);
      }
    }
  }

  Future<void> _rejoinChannel(String topic) async {
    try {
      print('Rejoining channel: $topic');
      await client.joinChannel(topic);
      _joinedChannels[topic] = true;

      final handlers = _handlers[topic];
      if (handlers != null) {
        for (final entry in handlers.entries) {
          print('Re-establishing handler for event: ${entry.key}');
          client.on(topic, entry.key, (payload) {
            if (!_disposed) {
              print('Received event ${entry.key} with payload: $payload');
              entry.value(payload);
            }
          });
        }
      }
      print('Successfully rejoined channel: $topic');
    } catch (e) {
      print('Failed to rejoin channel $topic: $e');
      _joinedChannels[topic] = false;
      throw Exception('Failed to rejoin channel: $e');
    }
  }

  void _handleDisconnect() {
    if (_disposed || _isReconnecting) return;

    _setState(SyncState.disconnected);
    _joinedChannels.clear();

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_disposed) return;

      if (_currentState == SyncState.disconnected) {
        _reconnectAttempts++;
        print('Attempting to reconnect (attempt $_reconnectAttempts)...');
        connect().catchError((e) {
          print('Reconnection attempt failed: $e');
          // Error is handled by connect() method
        });
      }
    });
  }

  Future<Map<String, dynamic>> joinChannel(
    String topic, {
    Map<String, Function(Map<String, dynamic>)>? handlers,
  }) async {
    if (_disposed) {
      throw StateError('SyncManager has been disposed');
    }

    if (handlers != null) {
      print('Setting up handlers for channel: $topic');
      _handlers[topic] = handlers;
      for (final entry in handlers.entries) {
        print('Adding handler for event: ${entry.key}');
        client.on(topic, entry.key, (payload) {
          if (!_disposed) {
            print('Received event ${entry.key} with payload: $payload');
            entry.value(payload);
          }
        });
      }
    }

    if (_currentState != SyncState.connected) {
      _joinedChannels[topic] = false;
      return {'status': 'offline'};
    }

    final result = await client.joinChannel(topic);
    _joinedChannels[topic] = true;
    return result;
  }

  Future<Map<String, dynamic>> push(
    String topic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (_disposed) {
      throw StateError('SyncManager has been disposed');
    }

    // Create operation
    final operation = PendingOperation(
      topic: topic,
      event: event,
      payload: payload,
    );

    if (_currentState != SyncState.connected ||
        !_joinedChannels.containsKey(topic) ||
        !_joinedChannels[topic]!) {
      print(
          'Not connected or channel not joined, queueing operation: ${operation.event}');
      _pendingOperations.add(operation);
      return {'status': 'queued', 'operation': operation.toJson()};
    }

    print('Pushing event: $event to topic: $topic with payload: $payload');
    try {
      final result = await client.push(topic, event, payload);
      // Operation succeeded, remove any pending duplicates
      _pendingOperations.removeWhere((op) =>
          op.topic == topic && op.event == event && op.payload == payload);
      return result;
    } catch (e) {
      print('Error pushing event: $e');
      // Queue operation for retry and handle disconnect
      _pendingOperations.add(operation);
      _handleDisconnect();
      return {'status': 'queued', 'operation': operation.toJson()};
    }
  }

  void _setState(SyncState newState) {
    if (_disposed) return;

    if (_currentState != newState) {
      print('SyncManager state changing from $_currentState to $newState');
      _currentState = newState;
      _syncStateController.add(newState);
    }
  }

  void dispose() {
    print('Disposing SyncManager');
    _disposed = true;
    _reconnectTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _messageSubscription?.cancel();
    _syncStateController.close();
    client.disconnect();
  }
}

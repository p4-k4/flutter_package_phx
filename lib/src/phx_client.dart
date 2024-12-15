import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum PhxMessageType {
  join,
  leave,
  heartbeat,
  event,
  reply,
  error,
}

class PhxMessage {
  final String topic;
  final PhxMessageType type;
  final Map<String, dynamic> payload;

  PhxMessage({
    required this.topic,
    required this.type,
    required this.payload,
  });
}

class PhxClient {
  final String endpoint;
  final Duration heartbeatInterval;
  WebSocket? _socket;
  Timer? _heartbeatTimer;
  final _messageController = StreamController<PhxMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  int _ref = 0;
  bool _connected = false;
  bool _disposed = false;
  final Map<String, Completer<Map<String, dynamic>>> _pendingResponses = {};
  final Map<String, Map<String, Function(Map<String, dynamic>)>>
      _channelHandlers = {};

  PhxClient(
    this.endpoint, {
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  Stream<PhxMessage>? get messageStream => _messageController.stream;
  Stream<bool>? get connectionStateStream => _connectionStateController.stream;

  bool isConnected() => _connected && _socket != null && !_disposed;

  Future<void> connect() async {
    if (_disposed) {
      throw Exception('Client is disposed');
    }

    if (_socket != null) {
      await _cleanup();
    }

    try {
      _socket = await WebSocket.connect('$endpoint?vsn=2.0.0');
      _connected = true;
      _connectionStateController.add(true);

      _socket!.listen(
        (data) => _handleMessage(data as String),
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _startHeartbeat();
    } catch (e) {
      print('Failed to connect: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  Future<void> _cleanup() async {
    _connected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Clear all pending responses
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection cleanup');
      }
    }
    _pendingResponses.clear();

    // Clear channel handlers
    _channelHandlers.clear();

    // Close existing socket
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
  }

  void _handleDisconnect() {
    if (_disposed) return;

    _connected = false;
    _socket = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _connectionStateController.add(false);

    // Fail all pending responses
    for (final completer in _pendingResponses.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection lost');
      }
    }
    _pendingResponses.clear();

    // Clear channel handlers on disconnect
    _channelHandlers.clear();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_connected && !_disposed) {
        push('phoenix', 'heartbeat', {}).catchError((e) {
          print('Heartbeat failed: $e');
        });
      }
    });
  }

  void _handleMessage(String rawMessage) {
    if (_disposed) return;

    final data = json.decode(rawMessage);
    final topic = data[2] as String;
    final event = data[3] as String;
    final payload = data[4] as Map<String, dynamic>;
    final ref = data[1];

    PhxMessageType type;
    switch (event) {
      case 'phx_join':
        type = PhxMessageType.join;
        break;
      case 'phx_leave':
        type = PhxMessageType.leave;
        break;
      case 'heartbeat':
        type = PhxMessageType.heartbeat;
        break;
      case 'phx_reply':
        type = PhxMessageType.reply;
        if (ref != null) {
          final completer = _pendingResponses.remove(ref.toString());
          if (completer != null && !completer.isCompleted) {
            if (payload['status'] == 'ok') {
              completer.complete(payload['response'] ?? {});
            } else {
              completer.completeError(payload['response'] ?? 'Error');
            }
          }
        }
        break;
      case 'phx_error':
        type = PhxMessageType.error;
        break;
      default:
        type = PhxMessageType.event;
        // Handle channel events
        final handlers = _channelHandlers[topic];
        if (handlers != null && handlers.containsKey(event)) {
          handlers[event]!(payload);
        }
    }

    _messageController.add(PhxMessage(
      topic: topic,
      type: type,
      payload: payload,
    ));
  }

  Future<Map<String, dynamic>> joinChannel(String topic) async {
    if (_disposed) {
      throw Exception('Client is disposed');
    }

    if (!_connected) {
      throw Exception('Not connected');
    }

    final ref = (++_ref).toString();
    final completer = Completer<Map<String, dynamic>>();
    _pendingResponses[ref] = completer;

    _socket!.add(json.encode([
      ref,
      ref,
      topic,
      'phx_join',
      {},
    ]));

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingResponses.remove(ref);
        throw TimeoutException('Channel join timeout');
      },
    );
  }

  Future<Map<String, dynamic>> push(
    String topic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (_disposed) {
      throw Exception('Client is disposed');
    }

    if (!_connected) {
      throw Exception('Not connected');
    }

    final ref = (++_ref).toString();
    final completer = Completer<Map<String, dynamic>>();
    _pendingResponses[ref] = completer;

    try {
      _socket!.add(json.encode([
        ref,
        ref,
        topic,
        event,
        payload,
      ]));
    } catch (e) {
      _handleDisconnect();
      throw Exception('Failed to send message: $e');
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _pendingResponses.remove(ref);
        throw TimeoutException('Message timeout');
      },
    );
  }

  void on(
    String topic,
    String event,
    Function(Map<String, dynamic>) callback,
  ) {
    if (_disposed) return;

    _channelHandlers.putIfAbsent(topic, () => {});
    _channelHandlers[topic]![event] = callback;
  }

  Future<void> disconnect() async {
    if (_disposed) return;

    _disposed = true;
    await _cleanup();
    await _messageController.close();
    await _connectionStateController.close();
  }
}

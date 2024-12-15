import 'dart:async';
import 'package:phx/phx.dart';
import 'mock_web_socket.dart';

/// Mock PhxClient for testing
class MockPhxClient extends PhxClient {
  final MockWebSocket mockSocket;
  final _messageController = StreamController<PhxMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  bool _connected = false;
  bool _disposed = false;

  MockPhxClient(String endpoint, this.mockSocket) : super(endpoint);

  @override
  Stream<PhxMessage>? get messageStream => _messageController.stream;

  @override
  Stream<bool>? get connectionStateStream => _connectionStateController.stream;

  @override
  bool isConnected() => _connected;

  @override
  Future<void> connect() async {
    if (_disposed) return;

    if (mockSocket.isConnected) {
      _connected = true;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(true);
      }
    } else {
      throw Exception('Connection refused');
    }
  }

  @override
  Future<Map<String, dynamic>> joinChannel(String topic) async {
    if (_disposed) return {'status': 'error', 'reason': 'disposed'};
    if (!_connected) {
      throw Exception('Not connected');
    }

    mockSocket.add({
      'event': 'phx_join',
      'topic': topic,
    });
    return {'status': 'ok'};
  }

  @override
  Future<Map<String, dynamic>> push(
    String topic,
    String event,
    Map<String, dynamic> payload,
  ) async {
    if (_disposed) return {'status': 'error', 'reason': 'disposed'};
    if (!_connected) {
      throw Exception('Not connected');
    }

    mockSocket.add({
      'event': event,
      'topic': topic,
      'payload': payload,
    });
    return {'status': 'ok'};
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _disposed = true;
    _connected = false;

    // Clean up resources
    if (!_messageController.isClosed) {
      await _messageController.close();
    }
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  /// Simulate receiving a message
  void receiveMessage(PhxMessage message) {
    if (!_disposed && _connected && !_messageController.isClosed) {
      _messageController.add(message);
    }
  }

  /// Clear sent messages
  void clearMessages() {
    mockSocket.clearMessages();
  }

  /// Clean up resources
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }
}

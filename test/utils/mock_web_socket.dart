import 'dart:async';

/// Mock WebSocket for testing
class MockWebSocket {
  final _controller = StreamController<dynamic>.broadcast();
  final List<Map<String, dynamic>> _sentMessages = [];
  bool _isConnected = true;

  /// Stream of messages received from the server
  Stream get stream => _controller.stream;

  /// Whether the socket is connected
  bool get isConnected => _isConnected;

  /// Messages sent through the socket
  List<Map<String, dynamic>> get sentMessages =>
      List.unmodifiable(_sentMessages);

  /// Add a message to the socket
  void add(dynamic message) {
    if (!_isConnected) {
      throw Exception('WebSocket is closed');
    }
    if (message is Map<String, dynamic>) {
      _sentMessages.add(message);
    }
  }

  /// Close the socket
  void close() {
    _isConnected = false;
    _controller.add('close');
  }

  /// Open the socket
  void open() {
    _isConnected = true;
  }

  /// Clear sent messages
  void clearMessages() {
    _sentMessages.clear();
  }

  /// Send a message from the server
  void receiveMessage(dynamic message) {
    if (_isConnected) {
      _controller.add(message);
    }
  }

  /// Dispose the mock socket
  void dispose() {
    _controller.close();
  }
}

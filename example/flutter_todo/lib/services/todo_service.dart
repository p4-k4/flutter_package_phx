import 'package:flutter/foundation.dart';
import 'package:phx/phx.dart';
import '../models/todo.dart';

class TodoService extends ChangeNotifier {
  late final SyncManager _syncManager;
  late final PhxClient _client;
  final _todoChannel = 'todo:list';
  List<Todo> _todos = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _error;
  bool _isOffline = false;
  SyncState _syncState = SyncState.disconnected;
  DateTime? _lastSynced;
  bool _processingPendingOperations = false;
  bool _channelJoined = false;
  bool _isInitialized = false;

  // Use 127.0.0.1 instead of localhost for iOS simulator
  final _serverUrl = 'ws://127.0.0.1:4000/socket/websocket';

  TodoService() {
    _client = PhxClient(_serverUrl);
    _syncManager = SyncManager(
      endpoint: _serverUrl,
      client: _client,
    );

    // Listen for messages from the server
    _client.messageStream?.listen((PhxMessage message) {
      if (message.topic == _todoChannel &&
          message.type == PhxMessageType.event) {
        _handleMessage(message.payload);
      }
    });
    _client.connectionStateStream?.listen(_handleConnectionState);

    // Listen for sync state changes
    _syncManager.syncStateStream?.listen((state) async {
      final previousState = _syncState;
      _syncState = state;

      // Only process operations and refresh todos when transitioning to connected state
      // and not already processing operations
      if (state == SyncState.connected &&
          !_processingPendingOperations &&
          _isInitialized) {
        _processingPendingOperations = true;
        try {
          // Ensure channel is joined before refreshing todos
          if (!_channelJoined) {
            final result = await _syncManager.joinChannel(_todoChannel);
            if (result['status'] == 'ok') {
              _channelJoined = true;
            } else {
              print('Failed to join channel: $result');
              return;
            }
          }

          // Get fresh todos from server after processing operations
          await _refreshTodos();
          _lastSynced = DateTime.now();
        } finally {
          _processingPendingOperations = false;
        }
      }
      notifyListeners();
    });
  }

  // Getters
  List<Todo> get todos => _todos;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get error => _error;
  bool get isOffline => _isOffline;
  SyncState get syncState => _syncState;
  DateTime? get lastSynced => _lastSynced;

  String get statusText {
    switch (_syncState) {
      case SyncState.connected:
        final lastSync = _lastSynced;
        if (lastSync != null) {
          final difference = DateTime.now().difference(lastSync);
          if (difference.inSeconds < 60) {
            return 'Connected • Last synced just now';
          } else if (difference.inMinutes < 60) {
            return 'Connected • Last synced ${difference.inMinutes}m ago';
          } else {
            return 'Connected • Last synced ${difference.inHours}h ago';
          }
        }
        return 'Connected';
      case SyncState.disconnected:
        return 'Offline';
      case SyncState.syncing:
        return 'Syncing...';
      default:
        return '';
    }
  }

  Future<void> _refreshTodos() async {
    try {
      final result = await _client.push(_todoChannel, 'get_todos', {});
      if (result.containsKey('response')) {
        final response = result['response'] as Map<String, dynamic>;
        if (response.containsKey('todos')) {
          final todosList = response['todos'] as List;
          final todos = todosList
              .map((todo) => Todo.fromJson(todo as Map<String, dynamic>))
              .toList();
          _setTodos(todos);
        }
      }
    } catch (e) {
      print('Error refreshing todos: $e');
    }
  }

  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();
      await _syncManager.init();

      // Join channel only once during initialization
      if (!_channelJoined) {
        final result = await _syncManager.joinChannel(_todoChannel);
        if (result['status'] == 'ok') {
          _channelJoined = true;
        } else {
          print('Failed to join channel during initialization: $result');
        }
      }

      _isInitialized = true;

      // If we're already connected after hot reload, refresh todos immediately
      if (_syncManager.currentState == SyncState.connected &&
          !_processingPendingOperations) {
        _processingPendingOperations = true;
        try {
          await _refreshTodos();
          _lastSynced = DateTime.now();
        } finally {
          _processingPendingOperations = false;
        }
      }
    } catch (e, stackTrace) {
      print('Error in initialize: $e');
      print('Stack trace: $stackTrace');
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addTodo(String text) async {
    try {
      _clearError();
      final result = await _syncManager.push(
        _todoChannel,
        'add_todo',
        {'text': text},
      );
      print('Add todo result: $result');
    } catch (e) {
      print('Error adding todo: $e');
      _setError(e.toString());
    }
  }

  Future<void> toggleTodo(Todo todo) async {
    try {
      _clearError();
      final result = await _syncManager.push(
        _todoChannel,
        'update_todo',
        {
          'id': todo.id,
          'completed': !todo.completed,
        },
      );
      print('Toggle todo result: $result');
    } catch (e) {
      print('Error toggling todo: $e');
      _setError(e.toString());
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      _clearError();
      final result = await _syncManager.push(
        _todoChannel,
        'update_todo',
        todo.toJson(),
      );
      print('Update todo result: $result');
    } catch (e) {
      print('Error updating todo: $e');
      _setError(e.toString());
    }
  }

  Future<void> deleteTodo(Todo todo) async {
    try {
      _clearError();
      final result = await _syncManager.push(
        _todoChannel,
        'delete_todo',
        {'id': todo.id},
      );
      print('Delete todo result: $result');
    } catch (e) {
      print('Error deleting todo: $e');
      _setError(e.toString());
    }
  }

  Future<void> clearDatabases() async {
    try {
      // Close existing connections
      await _syncManager.dispose();

      // Create a new SQLiteDatabase instance to clear records
      final db = SQLiteDatabase();
      await db.init();
      await db.clear();
      await db.close();

      // Create a new PendingOperationsStore instance to clear operations
      final store = PendingOperationsStore();
      await store.init();
      await store.clear();
      await store.close();

      // Reinitialize sync manager
      _client = PhxClient(_serverUrl);
      _syncManager = SyncManager(
        endpoint: _serverUrl,
        client: _client,
      );

      // Reset state
      _channelJoined = false;
      _isInitialized = false;
      _todos = [];

      // Reinitialize
      await initialize();

      notifyListeners();
    } catch (e) {
      print('Error clearing databases: $e');
      _setError(e.toString());
    }
  }

  void _handleMessage(Map<String, dynamic> payload) {
    try {
      print('Received message: $payload');
      if (payload.isEmpty) {
        print('Empty payload received');
        return;
      }

      final event = payload['event'];
      if (event == null) {
        print('No event in payload');
        return;
      }

      final response = payload['response'] as Map<String, dynamic>?;
      if (response == null) {
        print('No response in payload');
        return;
      }

      switch (event) {
        case 'todo_added':
        case 'todo_updated':
        case 'todo_deleted':
          // Refresh todos from server for any change
          _refreshTodos();
          break;
        default:
          print('Unknown event: $event');
      }
    } catch (e, stackTrace) {
      print('Error handling message: $e');
      print('Stack trace: $stackTrace');
      print('Payload: $payload');
    }
  }

  void _handleConnectionState(bool connected) {
    _isOffline = !connected;
    if (!connected) {
      _channelJoined = false;
    }
    notifyListeners();
  }

  void _setTodos(List<Todo> todos) {
    _todos = todos;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _hasError = true;
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _hasError = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() async {
    // Clear pending operations before disposing
    final store = PendingOperationsStore();
    try {
      await store.init();
      await store.clear();
    } catch (e) {
      print('Error clearing pending operations on dispose: $e');
    } finally {
      await store.close();
      await _syncManager.dispose();
      super.dispose();
    }
  }
}

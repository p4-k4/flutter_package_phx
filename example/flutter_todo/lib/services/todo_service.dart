import 'package:flutter/foundation.dart';
import 'package:phx/phx.dart';
import '../models/todo.dart';

class TodoService extends ChangeNotifier {
  final SyncManager _syncManager;
  List<Todo> _todos = [];
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;
  bool _isInitialized = false;

  TodoService()
      : _syncManager = SyncManager(
          endpoint: 'ws://localhost:4000/socket/websocket',
          client: PhxClient(
            'ws://localhost:4000/socket/websocket',
            heartbeatInterval: const Duration(seconds: 30),
          ),
        );

  List<Todo> get todos => List.unmodifiable(_todos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isOffline => _isOffline;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Initialize and connect sequentially
      await _syncManager.init();
      await _syncManager.connect();

      // Listen for sync state changes
      _syncManager.syncStateStream.listen((state) {
        _isOffline = state != SyncState.connected;
        if (!_isOffline && _error != null) {
          _error = null;
        }
        notifyListeners();
      });

      // Join the todos channel and set up handlers
      final response = await _syncManager.joinChannel(
        'todos:list',
        handlers: {
          'todo_created': (payload) {
            print('Received todo_created: $payload');
            final todo = Todo.fromJson(Map<String, dynamic>.from(payload));

            // Remove any optimistic todo with a matching temporary ID
            _todos.removeWhere((t) => t.id.startsWith('temp_'));

            // Add the new todo at the beginning of the list
            _todos.insert(0, todo);
            notifyListeners();
          },
          'todo_updated': (payload) {
            print('Received todo_updated: $payload');
            final updatedTodo =
                Todo.fromJson(Map<String, dynamic>.from(payload));

            final index =
                _todos.indexWhere((todo) => todo.id == updatedTodo.id);
            if (index != -1) {
              _todos[index] = updatedTodo;
              notifyListeners();
            }
          },
          'todo_deleted': (payload) {
            print('Received todo_deleted: $payload');
            final deletedTodo =
                Todo.fromJson(Map<String, dynamic>.from(payload));

            final index =
                _todos.indexWhere((todo) => todo.id == deletedTodo.id);
            if (index != -1) {
              _todos.removeAt(index);
              notifyListeners();
            }
          },
        },
      );

      // Handle initial todos from join response
      if (response.containsKey('todos')) {
        final todosList = response['todos'] as List;
        _todos = todosList
            .map((todo) => Todo.fromJson(Map<String, dynamic>.from(todo)))
            .toList();
      }

      _isInitialized = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addTodo(String title) async {
    if (title.isEmpty) return;

    try {
      // Create an optimistic todo
      final optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticTodo = Todo(
        id: optimisticId,
        title: title,
        completed: false,
      );

      // Add optimistically
      _todos.insert(0, optimisticTodo);
      notifyListeners();

      try {
        await _syncManager.push(
          'todos:list',
          'event',
          {
            'event': 'new_todo',
            'title': title,
          },
        );
      } catch (e) {
        // Remove optimistic todo on error
        _todos.removeWhere((todo) => todo.id == optimisticId);
        notifyListeners();

        if (e.toString().contains('Not connected')) {
          _isOffline = true;
          _error = 'Failed to sync: Device is offline';
        } else {
          _error = 'Failed to add todo: $e';
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to add todo: $e';
      notifyListeners();
    }
  }

  Future<void> toggleTodo(Todo todo) async {
    try {
      // Optimistically update
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index == -1) return;

      final updatedTodo = todo.copyWith(completed: !todo.completed);
      _todos[index] = updatedTodo;
      notifyListeners();

      try {
        await _syncManager.push(
          'todos:list',
          'event',
          {
            'event': 'update_todo',
            'id': todo.id,
            'completed': !todo.completed,
          },
        );
      } catch (e) {
        // Revert on error
        _todos[index] = todo;
        notifyListeners();

        if (e.toString().contains('Not connected')) {
          _isOffline = true;
          _error = 'Failed to sync: Device is offline';
        } else {
          _error = 'Failed to update todo: $e';
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update todo: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTodo(Todo todo) async {
    try {
      // Remove optimistically
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index == -1) return;

      final deletedTodo = _todos.removeAt(index);
      notifyListeners();

      try {
        await _syncManager.push(
          'todos:list',
          'event',
          {
            'event': 'delete_todo',
            'id': todo.id,
          },
        );
      } catch (e) {
        // Restore on error
        _todos.insert(index, deletedTodo);
        notifyListeners();

        if (e.toString().contains('Not connected')) {
          _isOffline = true;
          _error = 'Failed to sync: Device is offline';
        } else {
          _error = 'Failed to delete todo: $e';
        }
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to delete todo: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncManager.dispose();
    super.dispose();
  }
}

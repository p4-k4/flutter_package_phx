import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phx/phx.dart';
import 'services/todo_service.dart';
import 'models/todo.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => TodoService(),
      child: const TodoApp(),
    ),
  );
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Todo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TodoList(),
    );
  }
}

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  TodoListState createState() => TodoListState();
}

class TodoListState extends State<TodoList> {
  final _textController = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        context.read<TodoService>().initialize();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Todo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Data',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data'),
                  content: const Text(
                    'This will clear all todos and pending operations. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await context.read<TodoService>().clearDatabases();
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24.0),
          child: Consumer<TodoService>(
            builder: (context, todoService, child) {
              final textColor = Theme.of(context).colorScheme.onPrimary;
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      todoService.syncState == SyncState.connected
                          ? Icons.cloud_done
                          : todoService.syncState == SyncState.syncing
                              ? Icons.cloud_sync
                              : Icons.cloud_off,
                      color: textColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      todoService.statusText,
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: Consumer<TodoService>(
        builder: (context, todoService, child) {
          if (todoService.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting to server...'),
                ],
              ),
            );
          }

          if (todoService.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      todoService.error ?? 'An error occurred',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => todoService.initialize(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Add a new todo',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (text) {
                          if (text.isNotEmpty) {
                            todoService.addTodo(text);
                            _textController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_textController.text.isNotEmpty) {
                          todoService.addTodo(_textController.text);
                          _textController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: todoService.todos.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No todos yet\nAdd your first todo above',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: todoService.todos.length,
                        itemBuilder: (context, index) {
                          final todo = todoService.todos[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: todo.completed,
                                onChanged: (_) => todoService.toggleTodo(todo),
                              ),
                              title: Text(
                                todo.text,
                                style: TextStyle(
                                  decoration: todo.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => todoService.deleteTodo(todo),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/todo_service.dart';
import 'models/todo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TodoService(),
      child: MaterialApp(
        title: 'Flutter Todo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const TodoScreen(),
      ),
    );
  }
}

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTodoService();
    });
  }

  Future<void> _initializeTodoService() async {
    try {
      await context.read<TodoService>().initialize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Consumer<TodoService>(
            builder: (context, service, child) {
              if (service.isOffline) {
                return Container(
                  width: double.infinity,
                  color: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: const Text(
                    'Offline - Changes will sync when online',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      body: Consumer<TodoService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.hasError && service.todos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    service.error ?? 'An error occurred',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeTodoService,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'What needs to be done?',
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            service.addTodo(value);
                            _textController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_textController.text.isNotEmpty) {
                          service.addTodo(_textController.text);
                          _textController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (service.hasError)
                Container(
                  width: double.infinity,
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    service.error ?? 'An error occurred',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: service.todos.length,
                  itemBuilder: (context, index) {
                    final todo = service.todos[index];
                    return TodoItem(
                      key: ValueKey(todo.id),
                      todo: todo,
                      onToggle: () => service.toggleTodo(todo),
                      onDelete: () => service.deleteTodo(todo),
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

class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOptimistic = todo.id.startsWith('temp_');

    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Checkbox(
              value: todo.completed,
              onChanged: (_) => onToggle(),
            ),
            if (isOptimistic)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.completed ? TextDecoration.lineThrough : null,
            color: todo.completed ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

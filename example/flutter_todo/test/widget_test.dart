import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_todo/main.dart';
import 'package:flutter_todo/services/todo_service.dart';
import 'package:flutter_todo/models/todo.dart';
import 'package:phx/phx.dart';

void main() {
  testWidgets('Todo app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that we start with a loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Rebuild the widget after the frame
    await tester.pump();

    // Verify that we have a text field for adding todos
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('Can add todo', (WidgetTester tester) async {
    // Create a TodoService with a mock implementation
    final todoService = TodoService();
    await todoService.initialize();

    // Build our app and trigger a frame
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: todoService,
        child: const MaterialApp(
          home: TodoScreen(),
        ),
      ),
    );

    // Enter text in the TextField
    await tester.enterText(find.byType(TextField), 'Test Todo');

    // Tap the add button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that the todo was added with an optimistic ID
    expect(find.text('Test Todo'), findsOneWidget);
    expect(
      todoService.todos.any((todo) => todo.title == 'Test Todo'),
      isTrue,
    );
  });

  testWidgets('Can toggle todo', (WidgetTester tester) async {
    // Create a TodoService with a mock implementation
    final todoService = TodoService();
    await todoService.initialize();

    // Add a todo directly to the service
    await todoService.addTodo('Test Todo');
    await tester.pump();

    // Build our app and trigger a frame
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: todoService,
        child: const MaterialApp(
          home: TodoScreen(),
        ),
      ),
    );

    // Find and tap the checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    // Verify that the todo was toggled
    expect(
      todoService.todos.first.completed,
      isTrue,
    );
  });

  testWidgets('Can delete todo', (WidgetTester tester) async {
    // Create a TodoService with a mock implementation
    final todoService = TodoService();
    await todoService.initialize();

    // Add a todo directly to the service
    await todoService.addTodo('Test Todo');
    await tester.pump();

    // Build our app and trigger a frame
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: todoService,
        child: const MaterialApp(
          home: TodoScreen(),
        ),
      ),
    );

    // Find and tap the delete button
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    // Verify that the todo was removed
    expect(find.text('Test Todo'), findsNothing);
    expect(todoService.todos.isEmpty, isTrue);
  });

  testWidgets('Shows offline indicator when offline',
      (WidgetTester tester) async {
    // Create a TodoService with a mock implementation
    final todoService = TodoService();
    await todoService.initialize();

    // Build our app and trigger a frame
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: todoService,
        child: const MaterialApp(
          home: TodoScreen(),
        ),
      ),
    );

    // Verify that the offline indicator is shown when offline
    expect(todoService.isOffline, isFalse);
    expect(
      find.text('Offline - Changes will sync when online'),
      findsNothing,
    );

    // Force offline state by disconnecting
    todoService.dispose();
    await tester.pump();

    expect(todoService.isOffline, isTrue);
    expect(
      find.text('Offline - Changes will sync when online'),
      findsOneWidget,
    );
  });
}

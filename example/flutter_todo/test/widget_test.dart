import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_todo/services/todo_service.dart';
import 'package:flutter_todo/main.dart';

void main() {
  testWidgets('Todo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TodoService(),
        child: const TodoApp(),
      ),
    );

    expect(find.text('Flutter Todo'), findsOneWidget);
    expect(find.text('No todos yet'), findsOneWidget);
  });

  testWidgets('Can add todo', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TodoService(),
        child: const TodoApp(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Test todo');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Test todo'), findsOneWidget);
  });

  testWidgets('Can toggle todo', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TodoService(),
        child: const TodoApp(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Test todo');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('Can delete todo', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => TodoService(),
        child: const TodoApp(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Test todo');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Test todo'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pump();

    expect(find.text('Test todo'), findsNothing);
  });
}

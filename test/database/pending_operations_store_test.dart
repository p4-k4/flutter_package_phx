import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:phx/src/database/database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/fake_path_provider.dart';

void main() {
  late PendingOperationsStore store;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Set global factory
    databaseFactory = databaseFactoryFfi;
    // Register fake path provider
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    // Reset shared test database
    await PendingOperationsStore.resetSharedTestDb();

    // Create fresh store for each test
    store = PendingOperationsStore(':memory:');
    await store.init();
  });

  tearDown(() async {
    // Clean up resources
    try {
      await store.clear();
      await store.close();
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  tearDownAll(() async {
    // Reset shared test database
    await PendingOperationsStore.resetSharedTestDb();
  });

  group('PendingOperationsStore', () {
    test('adds and retrieves operations', () async {
      final operation = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data'},
      );

      final saved = await store.add(operation);
      expect(saved.id, isNotNull);
      expect(saved.topic, operation.topic);
      expect(saved.event, operation.event);
      expect(saved.payload, operation.payload);

      final operations = await store.getAll();
      expect(operations.length, 1);
      expect(operations.first.id, saved.id);
      expect(operations.first.topic, operation.topic);
      expect(operations.first.event, operation.event);
      expect(operations.first.payload, operation.payload);
    });

    test('removes operations', () async {
      final operation = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data'},
      );

      final saved = await store.add(operation);
      var operations = await store.getAll();
      expect(operations.length, 1);

      await store.remove(saved);
      operations = await store.getAll();
      expect(operations.length, 0);
    });

    test('removes operations by criteria', () async {
      final operation1 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data1'},
      );

      final operation2 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data2'},
      );

      await store.add(operation1);
      await store.add(operation2);

      var operations = await store.getAll();
      expect(operations.length, 2);

      await store.removeWhere(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data1'},
      );

      operations = await store.getAll();
      expect(operations.length, 1);
      expect(operations.first.payload, {'test': 'data2'});
    });

    test('clears all operations', () async {
      final operation1 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data1'},
      );

      final operation2 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data2'},
      );

      await store.add(operation1);
      await store.add(operation2);

      var operations = await store.getAll();
      expect(operations.length, 2);

      await store.clear();

      operations = await store.getAll();
      expect(operations.length, 0);
    });

    test('orders operations by timestamp', () async {
      final now = DateTime.now();
      final operation1 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data1'},
        timestamp: now.subtract(const Duration(minutes: 1)),
      );

      final operation2 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data2'},
        timestamp: now,
      );

      // Add in reverse order
      await store.add(operation2);
      await store.add(operation1);

      final operations = await store.getAll();
      expect(operations.length, 2);
      expect(operations[0].payload, {'test': 'data1'});
      expect(operations[1].payload, {'test': 'data2'});
    });

    test('handles complex JSON payloads', () async {
      final operation = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {
          'string': 'test',
          'number': 42,
          'boolean': true,
          'null': null,
          'array': [1, 2, 3],
          'object': {
            'nested': {
              'deep': 'value',
            },
          },
        },
      );

      final saved = await store.add(operation);
      final operations = await store.getAll();
      expect(operations.length, 1);
      expect(operations.first.payload, operation.payload);
    });

    test('handles database errors gracefully', () async {
      // Add an operation
      final operation = PendingOperation(
        topic: 'test:topic',
        event: 'test_event',
        payload: {'test': 'data'},
      );

      await store.add(operation);

      // Force close the database to simulate an error
      await store.close();

      // Next operation should recover
      final operation2 = PendingOperation(
        topic: 'test:topic',
        event: 'test_event2',
        payload: {'test': 'data2'},
      );

      // Reinitialize and clear any existing data
      await store.init();
      await store.clear();

      // Add new operation
      final saved = await store.add(operation2);
      expect(saved.id, isNotNull);

      final operations = await store.getAll();
      expect(operations.length, 1);
      expect(operations.first.event, 'test_event2');
    });
  });
}

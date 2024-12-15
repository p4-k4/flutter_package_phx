import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:phx/phx.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;

import 'utils/fake_path_provider.dart';
import 'utils/mock_phx_client.dart';
import 'utils/mock_web_socket.dart';

void main() {
  late SyncManager syncManager;
  late MockPhxClient client;
  late MockWebSocket mockSocket;

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

    // Create fresh instances for each test
    mockSocket = MockWebSocket();
    client = MockPhxClient('ws://localhost:4000/socket/websocket', mockSocket);
    syncManager = SyncManager(
      endpoint: 'ws://localhost:4000/socket/websocket',
      client: client,
      testDbPath: ':memory:', // Use in-memory database
      autoConnect: false,
    );

    // Initialize sync manager (starts disconnected)
    await syncManager.init();
  });

  tearDown(() async {
    // Clean up resources
    await syncManager.dispose();
    await Future.delayed(const Duration(milliseconds: 100)); // Wait for cleanup
    client.dispose();
    mockSocket.dispose();
  });

  tearDownAll(() async {
    // Reset shared test database
    await PendingOperationsStore.resetSharedTestDb();
  });

  group('SyncManager with SQLite', () {
    test('queues operations when offline', () async {
      // Try to push an event while offline
      final result = await syncManager.push(
        'test:topic',
        'test_event',
        {'test': 'data'},
      );

      // Should be queued
      expect(result['status'], 'queued');

      // Check pending operations
      final operations = await syncManager.pendingOperations;
      expect(operations.length, 1);
      expect(operations.first.topic, 'test:topic');
      expect(operations.first.event, 'test_event');
      expect(operations.first.payload, {'test': 'data'});
    });

    test('processes queued operations on reconnect', () async {
      // Queue some operations while offline
      await syncManager.push('test:topic', 'event1', {'id': 1});
      await syncManager.push('test:topic', 'event2', {'id': 2});

      // Verify they're queued
      var operations = await syncManager.pendingOperations;
      expect(operations.length, 2);

      // Connect and verify operations are processed
      mockSocket.open();
      client.clearMessages(); // Clear any previous messages
      await syncManager.connect();
      await Future.delayed(const Duration(milliseconds: 100));

      operations = await syncManager.pendingOperations;
      expect(operations.length, 0);

      // Verify messages were sent (excluding join messages)
      final messages = mockSocket.sentMessages
          .where((m) => m['event'] != 'phx_join')
          .toList();
      expect(messages.length, 2);
      expect(messages[0]['event'], 'event1');
      expect(messages[1]['event'], 'event2');
    });

    test('maintains operation order', () async {
      // Queue operations with timestamps
      final now = DateTime.now();
      await syncManager.push('test:topic', 'event1', {
        'timestamp': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      });
      await syncManager.push('test:topic', 'event2', {
        'timestamp': now.subtract(const Duration(minutes: 1)).toIso8601String(),
      });
      await syncManager.push('test:topic', 'event3', {
        'timestamp': now.toIso8601String(),
      });

      // Verify order
      final operations = await syncManager.pendingOperations;
      expect(operations.length, 3);
      expect(operations[0].event, 'event1');
      expect(operations[1].event, 'event2');
      expect(operations[2].event, 'event3');
    });

    test('handles channel joins with pending operations', () async {
      // Queue an operation while offline
      await syncManager.push('test:topic', 'test_event', {'test': 'data'});

      // Verify it's queued
      var operations = await syncManager.pendingOperations;
      expect(operations.length, 1);

      // Join channel (should be offline)
      final result = await syncManager.joinChannel('test:topic');
      expect(result['status'], 'offline');

      // Connect and verify operation is processed after join
      mockSocket.open();
      client.clearMessages(); // Clear any previous messages
      await syncManager.connect();
      await Future.delayed(const Duration(milliseconds: 100));

      // Should join channel first, then process operation
      final messages = mockSocket.sentMessages;
      expect(messages.length, 2);
      expect(messages[0]['event'], 'phx_join');
      expect(messages[1]['event'], 'test_event');
    });

    test('persists operations across restarts', () async {
      // Use a file-based database for persistence test
      final dbPath = path.join(
        '.dart_tool',
        'sqflite_common_ffi',
        'test',
        'phx_persistent_operations.db',
      );

      // Delete any existing database
      await deleteDatabase(dbPath);

      // Create first instance with file-based database
      final firstManager = SyncManager(
        endpoint: 'ws://localhost:4000/socket/websocket',
        client: client,
        testDbPath: dbPath,
        autoConnect: false,
      );
      await firstManager.init();

      // Queue an operation
      await firstManager.push('test:topic', 'test_event', {'test': 'data'});

      // Verify it's queued
      var operations = await firstManager.pendingOperations;
      expect(operations.length, 1);

      // Dispose first instance
      await firstManager.dispose();
      await Future.delayed(
          const Duration(milliseconds: 100)); // Wait for cleanup

      // Create second instance with same file-based database
      final secondManager = SyncManager(
        endpoint: 'ws://localhost:4000/socket/websocket',
        client: client,
        testDbPath: dbPath,
        autoConnect: false,
      );
      await secondManager.init();

      // Verify operation persisted
      operations = await secondManager.pendingOperations;
      expect(operations.length, 1);
      expect(operations.first.topic, 'test:topic');
      expect(operations.first.event, 'test_event');
      expect(operations.first.payload, {'test': 'data'});

      // Clean up
      await secondManager.dispose();
      await deleteDatabase(dbPath);
    });

    test('handles connection state changes', () async {
      expect(syncManager.currentState, equals(SyncState.disconnected));

      // Connect
      mockSocket.open();
      await syncManager.connect();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(syncManager.currentState, equals(SyncState.connected));

      // Disconnect
      mockSocket.close();
      client.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(syncManager.currentState, equals(SyncState.disconnected));

      // Reconnect
      mockSocket.open();
      await syncManager.connect();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(syncManager.currentState, equals(SyncState.connected));
    });
  });
}

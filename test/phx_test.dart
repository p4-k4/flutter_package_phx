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
  late String testDbPath;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Set global factory
    databaseFactory = databaseFactoryFfi;
    // Register fake path provider
    PathProviderPlatform.instance = FakePathProvider();
  });

  setUp(() async {
    // Create unique database path for each test
    testDbPath = path.join(
      '.dart_tool',
      'sqflite_common_ffi',
      'test',
      'phx_pending_operations_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    // Create fresh instances for each test
    mockSocket = MockWebSocket();
    client = MockPhxClient('ws://localhost:4000/socket/websocket', mockSocket);
    syncManager = SyncManager(
      endpoint: 'ws://localhost:4000/socket/websocket',
      client: client,
      testDbPath: testDbPath,
      autoConnect: false,
    );

    // Initialize sync manager (starts disconnected)
    await syncManager.init();
  });

  tearDown(() async {
    // Clean up resources
    await syncManager.dispose();
    client.dispose();
    mockSocket.dispose();

    // Clean up database
    try {
      await deleteDatabase(testDbPath);
    } catch (_) {
      // Ignore cleanup errors
    }
  });

  test('SyncManager initial state is disconnected', () {
    expect(syncManager.currentState, equals(SyncState.disconnected));
  });

  test('SyncManager connect changes state to connected', () async {
    mockSocket.open();
    await syncManager.connect();
    expect(syncManager.currentState, equals(SyncState.connected));
  });

  test('SyncManager sync state stream emits state changes', () async {
    final states = <SyncState>[];
    syncManager.syncStateStream.listen(states.add);

    // Connect
    mockSocket.open();
    await syncManager.connect();
    expect(states, contains(SyncState.connected));

    // Disconnect
    mockSocket.close();
    client.disconnect();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(states, contains(SyncState.disconnected));
  });

  test('SyncManager auto connects when enabled', () async {
    // Create manager with auto connect
    await syncManager.dispose();
    mockSocket = MockWebSocket();
    client = MockPhxClient('ws://localhost:4000/socket/websocket', mockSocket);
    syncManager = SyncManager(
      endpoint: 'ws://localhost:4000/socket/websocket',
      client: client,
      testDbPath: testDbPath,
      autoConnect: true,
    );

    // Should start disconnected
    expect(syncManager.currentState, equals(SyncState.disconnected));

    // Open socket and init
    mockSocket.open();
    await syncManager.init();

    // Should auto connect
    await Future.delayed(const Duration(milliseconds: 100));
    expect(syncManager.currentState, equals(SyncState.connected));
  });
}

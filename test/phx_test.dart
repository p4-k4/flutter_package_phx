import 'package:flutter_test/flutter_test.dart';
import 'package:phx/phx.dart';

void main() {
  group('SyncManager', () {
    late SyncManager syncManager;
    final endpoint = 'ws://localhost:4000/socket/websocket';

    setUp(() {
      syncManager = SyncManager(
        endpoint: endpoint,
        client: PhxClient(
          endpoint,
          heartbeatInterval: const Duration(seconds: 30),
        ),
      );
    });

    tearDown(() {
      syncManager.dispose();
    });

    test('initial state is disconnected', () {
      expect(syncManager.currentState, equals(SyncState.disconnected));
    });

    test('connect changes state to connected', () async {
      await syncManager.init();
      await syncManager.connect();
      expect(syncManager.currentState, equals(SyncState.connected));
    });

    test('sync state stream emits state changes', () async {
      final states = <SyncState>[];
      syncManager.syncStateStream.listen(states.add);

      await syncManager.init();
      await syncManager.connect();

      expect(states, equals([SyncState.syncing, SyncState.connected]));
    });
  });
}

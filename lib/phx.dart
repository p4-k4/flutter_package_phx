library phx;

export 'src/phx_client.dart' show PhxClient;
export 'src/local_store.dart' show LocalStore, PendingOperation;
export 'src/sync_manager.dart' show SyncManager, SyncState;

/// A Flutter package for Phoenix channels with offline support using Hive CE.
/// 
/// This package provides a robust solution for handling Phoenix channel communication
/// with built-in offline support. It uses Hive CE for local storage and implements
/// a custom Phoenix WebSocket client.
/// 
/// Basic usage:
/// ```dart
/// // Create a Phoenix client
/// final client = PhxClient(
///   'ws://your-server/socket/websocket',
///   heartbeatInterval: const Duration(seconds: 30),
/// );
/// 
/// // Initialize the sync manager with the client
/// final syncManager = SyncManager(
///   endpoint: 'ws://your-server/socket/websocket',
///   client: client,
/// );
/// await syncManager.init();
/// 
/// // Connect to the server
/// await syncManager.connect();
/// 
/// // Join a channel with handlers
/// await syncManager.joinChannel(
///   'room:123',
///   handlers: {
///     'new_msg': (payload) {
///       print('New message: ${payload['body']}');
///     },
///   },
/// );
/// 
/// // Push events (works offline)
/// await syncManager.push(
///   'room:123',
///   'new_msg',
///   {'body': 'Hello!'},
/// );
/// 
/// // Get stored data
/// final messages = syncManager.getData<List>('room:123', 'messages');
/// 
/// // Watch for changes
/// syncManager.watchData<List>('room:123', 'messages').listen((messages) {
///   print('Messages updated: $messages');
/// });
/// 
/// // Watch sync state
/// syncManager.syncStateStream.listen((state) {
///   print('Sync state: $state');
/// });
/// ```
/// 
/// The package handles:
/// - Automatic reconnection
/// - Message queueing when offline
/// - Local data persistence
/// - Real-time updates
/// - Sync state management
/// 
/// For more advanced usage, you can also use the [PhxClient] and [LocalStore]
/// classes directly for more fine-grained control.

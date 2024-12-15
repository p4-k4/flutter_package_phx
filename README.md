# PHX

A proof of concept Flutter package demonstrating Phoenix/Ecto integration with Flutter apps, providing offline capabilities and sync functionality. This package serves as a foundation for studying and implementing more elegant solutions for Phoenix database integration, authentication, and other Phoenix framework benefits in Flutter applications.

## Features

- 🔄 Phoenix WebSocket client implementation
- 💾 SQLite database integration for offline data persistence
- 📡 Offline operation support with automatic message queueing
- 🔁 Automatic reconnection handling
- 🚦 Connection state management
- 📊 Sync state tracking
- 🔌 Graceful connection loss handling
- 🗃️ Ecto-powered database operations

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  phx: ^0.0.1
```

## Usage

### Basic Setup

```dart
import 'package:phx/phx.dart';

// Create a Phoenix client
final client = PhxClient(
  'ws://your-server/socket/websocket',
  heartbeatInterval: const Duration(seconds: 30),
);

// Initialize the sync manager with the client
final syncManager = SyncManager(
  endpoint: 'ws://your-server/socket/websocket',
  client: client,
);
await syncManager.init();
```

### Joining Channels

```dart
// Join a channel with event handlers
await syncManager.joinChannel(
  'room:123',
  handlers: {
    'new_msg': (payload) {
      print('New message: ${payload['body']}');
    },
    'user_joined': (payload) {
      print('User joined: ${payload['user']}');
    },
  },
);
```

### Pushing Events

Events are automatically queued when offline and synced when connection is restored:

```dart
// Push an event (works offline)
await syncManager.push(
  'room:123',
  'new_msg',
  {'body': 'Hello, world!'},
);
```

### Sync State Management

```dart
// Watch sync state changes
syncManager.syncStateStream.listen((state) {
  switch (state) {
    case SyncState.disconnected:
      print('Offline mode');
      break;
    case SyncState.connected:
      print('Online mode');
      break;
    case SyncState.syncing:
      print('Syncing pending changes...');
      break;
  }
});
```

### Cleanup

```dart
// Dispose when done
syncManager.dispose();
```

## Examples

The package includes two examples demonstrating offline capabilities:

### Todo Example
A full-stack todo application showcasing:
- Phoenix/Ecto backend with proper database schema and migrations
- Flutter frontend with SQLite offline storage
- Real-time sync between multiple clients
- Offline CRUD operations with automatic sync
- Channel-based communication

To run the todo example:

1. Start the Phoenix server:
```bash
cd example/phoenix_todo
mix deps.get
mix ecto.setup
mix phx.server
```

2. Run the Flutter app:
```bash
cd example/flutter_todo
flutter run
```

Try:
- Creating, updating, and deleting todos while connected
- Going offline and making changes
- Reconnecting to see changes sync automatically
- Running multiple clients to see real-time updates

### Counter Example
A simpler example focusing on basic offline capabilities:

1. Start the Phoenix server:
```bash
cd example/phx_counter
mix deps.get
mix phx.server
```

2. Run the Flutter app:
```bash
cd example/flutter_counter
flutter run
```

Try:
- Incrementing while connected
- Stopping the Phoenix server
- Incrementing while offline
- Starting the server - changes sync automatically

## Development Notes

This package is a proof of concept demonstrating the possibilities of integrating Phoenix's powerful features with Flutter applications. Key areas demonstrated include:

- SQLite database integration for offline persistence
- Phoenix channel-based real-time communication
- Ecto schema and migration integration
- Offline operation handling
- Sync conflict resolution
- Real-time multi-client updates

Future development could focus on:
- More elegant database integration patterns
- Authentication and authorization
- Better error handling and conflict resolution
- Improved state management
- Simplified setup and configuration

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/p4-k4/flutter_package_phx/issues).

## Author

Paurini Taketakehikuroa Wiringi

## License

```
MIT License

Copyright (c) 2024 Paurini Taketakehikuroa Wiringi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

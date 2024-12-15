# PHX

A Flutter package for Phoenix channels with offline support. This package provides a robust solution for handling Phoenix channel communication with built-in offline capabilities.

## Features

- 🔄 Phoenix WebSocket client implementation
- 📡 Offline operation support with automatic message queueing
- 🔁 Automatic reconnection handling
- 🚦 Connection state management
- 📊 Sync state tracking
- 🔌 Graceful connection loss handling

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

## Example

The package includes a counter example demonstrating offline capabilities:

1. A Phoenix server implementing a simple counter channel
2. A Flutter app that can increment the counter while offline
3. Automatic syncing when connection is restored

To run the example:

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

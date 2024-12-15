## 0.0.1

Initial release of proof of concept package demonstrating Phoenix/Ecto integration with Flutter apps.

### Core Features
* Phoenix WebSocket client implementation
* SQLite database integration for offline persistence
* Offline operation support with automatic message queueing
* Automatic reconnection handling
* Channel state management
* Real-time sync state tracking

### Examples
* Todo application demonstrating:
  * Phoenix/Ecto backend integration
  * SQLite offline storage
  * Real-time multi-client sync
  * Offline CRUD operations
* Counter application showing basic offline capabilities

### Technical Implementation
* Database record abstraction layer
* Pending operations queue
* Sync strategy framework
* WebSocket connection management
* Channel-based communication

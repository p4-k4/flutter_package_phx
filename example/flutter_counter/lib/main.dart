import 'package:flutter/material.dart';
import 'package:phx/phx.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CounterPage(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}

class CounterPage extends StatefulWidget {
  CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final PhxClient _client;
  late final SyncManager _syncManager;
  int _count = 0;
  SyncState _syncState = SyncState.disconnected;
  String? _error;
  List<String> _logs = [];
  int _pendingIncrements = 0;

  void _log(String message) {
    print('FLUTTER APP: $message'); // For console output
    setState(() {
      _logs = [..._logs, message]; // For UI display
      if (_logs.length > 5) {
        _logs = _logs.sublist(_logs.length - 5); // Keep last 5 logs
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _setupPhoenix();
  }

  Future<void> _setupPhoenix() async {
    _log('Setting up Phoenix connection...');

    try {
      // Create Phoenix client
      _client = PhxClient(
        'ws://localhost:4000/socket/websocket',
        heartbeatInterval: const Duration(seconds: 30),
      );
      _log('Created PhxClient');

      // Create sync manager
      _syncManager = SyncManager(
        endpoint: 'ws://localhost:4000/socket/websocket',
        client: _client,
      );
      _log('Created SyncManager');

      // Initialize and connect
      await _syncManager.init();
      _log('Initialized sync manager');

      // Listen for sync state changes
      _syncManager.syncStateStream.listen((state) {
        _log('Sync state changed to: $state');
        setState(() {
          _syncState = state;
          if (state == SyncState.connected) {
            _error = null;
          }
        });
      });

      // Listen for counter updates
      _client.messageStream?.listen(
        (message) {
          _log(
              'Received message: topic=${message.topic}, type=${message.type}');
          if (message.topic == 'counter:lobby' &&
              message.payload.containsKey('count')) {
            _log('Received count update: ${message.payload['count']}');
            setState(() {
              _count = message.payload['count'];
              // Clear pending increments when we get a server update
              _pendingIncrements = 0;
            });
          }
        },
        onError: (error) {
          _log('Error in message stream: $error');
        },
      );

      // Join counter channel
      final joinResult = await _syncManager.joinChannel('counter:lobby');
      if (joinResult['status'] != 'offline') {
        _log('Joined counter channel');
      } else {
        _log('Starting in offline mode');
      }
    } catch (e) {
      _log('Error during setup: $e');
      setState(() {
        _error = 'Starting in offline mode';
      });
    }
  }

  Future<void> _incrementCounter() async {
    try {
      _log('Attempting to increment counter...');

      // Optimistically update local state
      setState(() {
        _count++;
        _error = null;
      });
      _log('Local count updated to: $_count');

      // Push to server (will be queued if offline)
      final result = await _syncManager.push(
        'counter:lobby',
        'increment',
        {},
      );

      if (result['status'] == 'queued') {
        _log('Operation queued for later sync');
        setState(() {
          _pendingIncrements++;
        });
      } else {
        _log('Successfully pushed increment to server');
      }
    } catch (e) {
      _log('Error incrementing counter: $e');
      // Don't revert optimistic update, just show error
      setState(() {
        _error = 'Failed to increment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phoenix Counter'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _buildConnectionBar(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            const Text(
              'Counter Value:',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_count',
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold),
                ),
                if (_pendingIncrements > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Chip(
                      label: Text('+$_pendingIncrements'),
                      backgroundColor: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _incrementCounter,
              icon: const Icon(Icons.add),
              label: const Text('Increment'),
            ),
            const SizedBox(height: 24),
            // Log display
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Recent Events:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_syncState == SyncState.syncing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: _logs
                            .map((log) =>
                                Text(log, style: const TextStyle(fontSize: 12)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBar() {
    final colors = Theme.of(context).colorScheme;

    Color color;
    String text;

    switch (_syncState) {
      case SyncState.connected:
        color = Colors.green;
        text = 'Connected';
      case SyncState.disconnected:
        color = Colors.red;
        text = _pendingIncrements > 0
            ? 'Offline ($_pendingIncrements pending)'
            : 'Offline';
      case SyncState.syncing:
        color = Colors.orange;
        text = 'Syncing...';
    }

    return Container(
      color: color,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            text,
            style: TextStyle(color: colors.onPrimary),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _syncManager.dispose();
    super.dispose();
  }
}

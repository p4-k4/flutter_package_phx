/// Represents a pending operation that needs to be synced with the server
class PendingOperation {
  /// Unique identifier for the operation
  final int? id;

  /// Channel topic
  final String topic;

  /// Event name
  final String event;

  /// Event payload
  final Map<String, dynamic> payload;

  /// Timestamp of when the operation was created
  final DateTime timestamp;

  PendingOperation({
    this.id,
    required this.topic,
    required this.event,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert operation to a database map
  Map<String, dynamic> toJson() => {
        'topic': topic,
        'event': event,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Create an operation from a database map
  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: json['id'] as int?,
      topic: json['topic'] as String,
      event: json['event'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Create a copy of this operation with updated fields
  PendingOperation copyWith({
    int? id,
    String? topic,
    String? event,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      event: event ?? this.event,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

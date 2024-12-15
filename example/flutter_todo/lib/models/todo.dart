class Todo {
  final String id;
  final String title;
  final bool completed;
  final DateTime? insertedAt;
  final DateTime? updatedAt;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    this.insertedAt,
    this.updatedAt,
  });

  Todo copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? insertedAt,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      insertedAt: insertedAt ?? this.insertedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    // Convert id to string if it's not already
    final id = json['id'].toString();

    return Todo(
      id: id,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      insertedAt: json['inserted_at'] != null
          ? DateTime.parse(json['inserted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'inserted_at': insertedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.title == title &&
        other.completed == completed;
  }

  @override
  int get hashCode => Object.hash(id, title, completed);

  @override
  String toString() {
    return 'Todo(id: $id, title: $title, completed: $completed)';
  }
}

class Todo {
  final String id;
  final String text;
  final bool completed;

  Todo({
    required this.id,
    required this.text,
    required this.completed,
  });

  Todo copyWith({
    String? id,
    String? text,
    bool? completed,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      completed: completed ?? this.completed,
    );
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      text: json['text'] as String,
      completed: json['completed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'completed': completed,
    };
  }

  @override
  String toString() {
    return 'Todo{id: $id, text: $text, completed: $completed}';
  }
}

class ChatMessage {
  final String role; // 'user' или 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class Conversation {
  final String id;
  String title;
  List<ChatMessage> messages;
  DateTime createdAt;

  Conversation({
    required this.id,
    this.title = 'Новый диалог',
    List<ChatMessage>? messages,
    DateTime? createdAt,
  }) : messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        title: json['title'] ?? 'Диалог',
        messages: (json['messages'] as List)
            .map((e) => ChatMessage.fromJson(e))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
      );
}

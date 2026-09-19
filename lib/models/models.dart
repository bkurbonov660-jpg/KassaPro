class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final String model;
  final String category;
  bool isFavorite;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.model,
    required this.category,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'model': model,
        'category': category,
        'isFavorite': isFavorite,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        model: j['model'] ?? 'unknown',
        category: j['category'] ?? 'Общее',
        isFavorite: j['isFavorite'] ?? false,
      );
}

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String model;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.model = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'model': model,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] ?? '',
        role: j['role'] ?? 'user',
        content: j['content'] ?? '',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        model: j['model'] ?? '',
      );
}

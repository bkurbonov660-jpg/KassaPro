import 'package:path/path.dart' as p;

class PhotoItem {
  final String id;
  String name;
  String description;
  String imagePath;
  DateTime createdAt;

  PhotoItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get basename => p.basename(imagePath);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) => PhotoItem(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        imagePath: json['imagePath'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

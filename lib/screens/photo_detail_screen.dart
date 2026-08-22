import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/photo_item.dart';
import '../providers/photo_provider.dart';

class PhotoDetailScreen extends StatefulWidget {
  final PhotoItem photo;

  const PhotoDetailScreen({super.key, required this.photo});

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.photo.name);
    _descController = TextEditingController(text: widget.photo.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final updated = PhotoItem(
      id: widget.photo.id,
      name: _nameController.text.trim().isEmpty ? 'Без названия' : _nameController.text.trim(),
      description: _descController.text.trim(),
      imagePath: widget.photo.imagePath,
      createdAt: widget.photo.createdAt,
    );
    app.updatePhoto(updated);
    setState(() => _isEditing = false);
  }

  void _sharePhoto() {
    final file = File(widget.photo.imagePath);
    if (file.existsSync()) {
      Share.shareXFiles([XFile(file.path)],
          text: '${widget.photo.name}\n${widget.photo.description}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translate(context, 'file_not_found'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<PhotoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: _isEditing ? Text(translate(context, 'editing')) : Text(widget.photo.name),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePhoto,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(translate(context, 'delete_photo_title')),
                    content: Text(translate(context, 'delete_photo_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(translate(context, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () {
                          app.deletePhoto(widget.photo.id);
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text(translate(context, 'delete'), style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.photo.imagePath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(widget.photo.imagePath),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey.shade800,
                child: const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
              ),
            const SizedBox(height: 20),
            if (_isEditing) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: translate(context, 'name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: translate(context, 'description'),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ] else ...[
              Text(
                widget.photo.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.photo.description.isEmpty ? translate(context, 'no_description') : widget.photo.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                '${translate(context, 'created_at')}: ${widget.photo.createdAt.toLocal().toString().substring(0, 16)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            if (_isEditing)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                      child: Text(translate(context, 'save')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _nameController.text = widget.photo.name;
                          _descController.text = widget.photo.description;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27272A),
                      ),
                      child: Text(translate(context, 'cancel')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String translate(BuildContext context, String key) {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final dict = {
      'ru': {
        'editing': 'Редактирование',
        'delete_photo_title': 'Удалить фото?',
        'delete_photo_confirm': 'Это действие нельзя отменить.',
        'delete': 'Удалить',
        'cancel': 'Отмена',
        'name': 'Название',
        'description': 'Описание',
        'no_description': 'Описание отсутствует',
        'created_at': 'Создано',
        'save': 'Сохранить',
        'file_not_found': 'Файл не найден',
      },
      'tg': {
        'editing': 'Таҳрир',
        'delete_photo_title': 'Аксро нест кардан?',
        'delete_photo_confirm': 'Ин амалро бекор кардан мумкин нест.',
        'delete': 'Нест кардан',
        'cancel': 'Бекор',
        'name': 'Ном',
        'description': 'Тавсиф',
        'no_description': 'Тавсиф нест',
        'created_at': 'Эҷод шуд',
        'save': 'Сабт',
        'file_not_found': 'Файл ёфт нашуд',
      },
    };
    return dict[app.language]?[key] ?? key;
  }
}

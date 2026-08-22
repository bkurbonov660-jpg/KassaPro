import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/photo_provider.dart';
import 'photo_detail_screen.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  Future<void> _showNameDialog(BuildContext context, ImageSource source) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final app = Provider.of<PhotoProvider>(context, listen: false);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(translate(context, 'enter_details')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: translate(context, 'name')),
            ),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: translate(context, 'description')),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(translate(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim().isEmpty ? 'Без названия' : nameController.text.trim();
              final desc = descController.text.trim();
              Navigator.pop(context);
              app.addPhotoFromPicker(source, name: name, description: desc);
            },
            child: Text(translate(context, 'save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<PhotoProvider>(context);
    final photos = app.photos;

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showNameDialog(context, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(translate(context, 'take_photo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showNameDialog(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: Text(translate(context, 'choose_from_gallery')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_back, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(translate(context, 'no_photos'), style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailScreen(photo: photo),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF18181B),
                            borderRadius: BorderRadius.circular(12),
                            image: photo.imagePath.isNotEmpty
                                ? DecorationImage(
                                    image: FileImage(File(photo.imagePath)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: photo.imagePath.isEmpty
                              ? const Icon(Icons.broken_image, color: Colors.grey)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String translate(BuildContext context, String key) {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    final dict = {
      'ru': {
        'take_photo': 'Сделать фото',
        'choose_from_gallery': 'Выбрать из галереи',
        'no_photos': 'Нет фотографий',
        'enter_details': 'Введите данные',
        'name': 'Название',
        'description': 'Описание',
        'cancel': 'Отмена',
        'save': 'Сохранить',
      },
      'tg': {
        'take_photo': 'Акс гиред',
        'choose_from_gallery': 'Аз галерея интихоб кунед',
        'no_photos': 'Аксҳо нестанд',
        'enter_details': 'Маълумот ворид кунед',
        'name': 'Ном',
        'description': 'Тавсиф',
        'cancel': 'Бекор',
        'save': 'Сабт',
      },
    };
    return dict[app.language]?[key] ?? key;
  }
}

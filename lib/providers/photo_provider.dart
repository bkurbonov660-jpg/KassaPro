import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../models/photo_item.dart';

enum SortOrder { dateDesc, dateAsc, nameAsc, nameDesc }

class PhotoProvider extends ChangeNotifier {
  List<PhotoItem> _photos = [];
  static const String _storageKey = 'sisms_photos';
  String _language = 'ru';
  SortOrder _sortOrder = SortOrder.dateDesc;

  List<PhotoItem> get photos {
    final list = List<PhotoItem>.from(_photos);
    switch (_sortOrder) {
      case SortOrder.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOrder.dateAsc:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOrder.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOrder.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
    }
    return list;
  }

  String get language => _language;
  SortOrder get sortOrder => _sortOrder;

  Future<void> init() async {
    _photos = await _loadPhotos();
    _language = await _loadLanguage();
    notifyListeners();
  }

  Future<List<PhotoItem>> _loadPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_storageKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => PhotoItem.fromJson(e)).toList();
  }

  Future<void> _savePhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_photos.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  Future<String> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lang') ?? 'ru';
  }

  Future<void> _saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
  }

  void setLanguage(String lang) {
    _language = lang;
    _saveLanguage(lang);
    notifyListeners();
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    notifyListeners();
  }

  Future<void> addPhotoFromPicker(ImageSource source, {String? name, String? description}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}';
    final savedPath = p.join(appDir.path, fileName);
    final file = File(pickedFile.path);
    await file.copy(savedPath);

    final newItem = PhotoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Новое фото ${DateTime.now().toLocal().toString().substring(0, 16)}',
      description: description ?? '',
      imagePath: savedPath,
    );
    _photos.add(newItem);
    await _savePhotos();
    notifyListeners();
  }

  Future<void> updatePhoto(PhotoItem item) async {
    final index = _photos.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _photos[index] = item;
      await _savePhotos();
      notifyListeners();
    }
  }

  Future<void> deletePhoto(String id) async {
    final item = _photos.firstWhere((e) => e.id == id);
    _photos.remove(item);
    try {
      final file = File(item.imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await _savePhotos();
    notifyListeners();
  }

  List<PhotoItem> searchPhotos(String query) {
    if (query.isEmpty) return photos;
    final q = query.toLowerCase();
    return photos.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.description.toLowerCase().contains(q)
    ).toList();
  }

  String exportTextData() {
    final list = _photos.map((p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'createdAt': p.createdAt.toIso8601String(),
    }).toList();
    return jsonEncode(list);
  }

  void importTextData(String jsonData) {
    try {
      final list = jsonDecode(jsonData) as List;
      for (var item in list) {
        final photo = PhotoItem(
          id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: item['name'] ?? 'Без названия',
          description: item['description'] ?? '',
          imagePath: '',
          createdAt: item['createdAt'] != null
              ? DateTime.parse(item['createdAt'])
              : DateTime.now(),
        );
        if (!_photos.any((p) => p.id == photo.id)) {
          _photos.add(photo);
        }
      }
      _savePhotos();
      notifyListeners();
    } catch (e) {
      throw Exception('Ошибка импорта: $e');
    }
  }

  Future<String> exportFullDatabase() async {
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}');
    await exportDir.create(recursive: true);
    final imagesDir = Directory('${exportDir.path}/images');
    await imagesDir.create();
    for (var photo in _photos) {
      if (photo.imagePath.isNotEmpty) {
        final src = File(photo.imagePath);
        if (await src.exists()) {
          final dest = File('${imagesDir.path}/${p.basename(photo.imagePath)}');
          await src.copy(dest.path);
        }
      }
    }
    final metaList = _photos.map((p) => {
      'id': p.id,
      'name': p.name,
      'description': p.description,
      'imageFile': p.basename,
      'createdAt': p.createdAt.toIso8601String(),
    }).toList();
    final metaFile = File('${exportDir.path}/metadata.json');
    await metaFile.writeAsString(jsonEncode(metaList));
    return exportDir.path;
  }

  Future<void> importFullDatabase(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) throw Exception('Папка не существует');
    final metaFile = File('$folderPath/metadata.json');
    if (!await metaFile.exists()) throw Exception('metadata.json не найден');
    final content = await metaFile.readAsString();
    final list = jsonDecode(content) as List;
    final imagesDir = Directory('$folderPath/images');
    if (!await imagesDir.exists()) throw Exception('Папка images не найдена');

    final appDir = await getApplicationDocumentsDirectory();
    for (var item in list) {
      final imageFileName = item['imageFile'] ?? '';
      if (imageFileName.isEmpty) continue;
      final srcFile = File('${imagesDir.path}/$imageFileName');
      if (!await srcFile.exists()) continue;
      final destPath = p.join(appDir.path, imageFileName);
      await srcFile.copy(destPath);
      final photo = PhotoItem(
        id: item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: item['name'] ?? 'Без названия',
        description: item['description'] ?? '',
        imagePath: destPath,
        createdAt: item['createdAt'] != null
            ? DateTime.parse(item['createdAt'])
            : DateTime.now(),
      );
      if (!_photos.any((p) => p.id == photo.id)) {
        _photos.add(photo);
      }
    }
    _savePhotos();
    notifyListeners();
  }

  void clearAll() {
    for (var p in _photos) {
      try { File(p.imagePath).deleteSync(); } catch (_) {}
    }
    _photos.clear();
    _savePhotos();
    notifyListeners();
  }
}

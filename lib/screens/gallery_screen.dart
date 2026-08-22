import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/photo_provider.dart';
import 'photo_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<PhotoProvider>(context);
    final filtered = app.searchPhotos(_query);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: translate(context, 'search_hint'),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFF18181B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(translate(context, 'nothing_found'), style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final photo = filtered[index];
                      return ListTile(
                        leading: photo.imagePath.isNotEmpty
                            ? Image.file(File(photo.imagePath), width: 50, height: 50, fit: BoxFit.cover)
                            : const Icon(Icons.broken_image),
                        title: Text(photo.name),
                        subtitle: Text(
                          photo.description.isNotEmpty ? photo.description : translate(context, 'no_description'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailScreen(photo: photo),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    final app = Provider.of<PhotoProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(translate(context, 'sort_by')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(translate(context, 'date_desc')),
              onTap: () { app.setSortOrder(SortOrder.dateDesc); Navigator.pop(context); },
            ),
            ListTile(
              title: Text(translate(context, 'date_asc')),
              onTap: () { app.setSortOrder(SortOrder.dateAsc); Navigator.pop(context); },
            ),
            ListTile(
              title: Text(translate(context, 'name_asc')),
              onTap: () { app.setSortOrder(SortOrder.nameAsc); Navigator.pop(context); },
            ),
            ListTile(
              title: Text(translate(context, 'name_desc')),
              onTap: () { app.setSortOrder(SortOrder.nameDesc); Navigator.pop(context); },
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
        'search_hint': 'Поиск по названию или описанию...',
        'nothing_found': 'Ничего не найдено',
        'no_description': 'Без описания',
        'sort_by': 'Сортировка',
        'date_desc': 'Сначала новые',
        'date_asc': 'Сначала старые',
        'name_asc': 'По названию (А-Я)',
        'name_desc': 'По названию (Я-А)',
      },
      'tg': {
        'search_hint': 'Ҷустуҷӯ бо ном ё тавсиф...',
        'nothing_found': 'Чизе ёфт нашуд',
        'no_description': 'Бе тавсиф',
        'sort_by': 'Тартиб додан',
        'date_desc': 'Аввал навҳо',
        'date_asc': 'Аввал кӯҳнаҳо',
        'name_asc': 'Бо ном (А-Я)',
        'name_desc': 'Бо ном (Я-А)',
      },
    };
    return dict[app.language]?[key] ?? key;
  }
}

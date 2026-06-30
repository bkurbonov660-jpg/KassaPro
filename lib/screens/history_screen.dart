import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers/download_provider.dart';
import 'media_player_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List _filter(List items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((item) => item.title.toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCompleted = provider.history.where((e) => e.status != 'downloading').toList();
    final videoItems = _filter(allCompleted.where((e) => e.type == 'mp4').toList());
    final audioItems = _filter(allCompleted.where((e) => e.type == 'mp3').toList());
    final favItems = _filter(provider.favorites);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Медиатека', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (allCompleted.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => provider.clearHistory()),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          tabs: [
            Tab(text: 'Видео (${videoItems.length})', icon: const Icon(Icons.video_library)),
            Tab(text: 'Аудио (${audioItems.length})', icon: const Icon(Icons.audiotrack)),
            Tab(text: 'Избранное (${favItems.length})', icon: const Icon(Icons.favorite)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по медиатеке...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(videoItems, isDark, provider),
                _buildList(audioItems, isDark, provider),
                _buildList(favItems, isDark, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List items, bool isDark, DownloadProvider provider) {
    if (items.isEmpty) {
      return Center(child: Text('Нет файлов', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final isMp3 = item.type == 'mp3';
        final accent = isMp3 ? const Color(0xFF00E5FF) : const Color(0xFFFF0055);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          child: ListTile(
            leading: _buildThumbnail(item, isMp3, accent),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            subtitle: Text('${item.source} • ${item.quality} • ${DateFormat('dd.MM HH:mm').format(item.timestamp)}',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(item.favorite ? Icons.favorite : Icons.favorite_border, color: item.favorite ? Colors.red : Colors.grey),
                  onPressed: () => provider.toggleFavorite(item.id),
                ),
                if (item.localPath != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Color(0xFF00E5FF)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MediaPlayerScreen(filePath: item.localPath!, mediaType: item.type))),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => provider.deleteItem(item.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail(item, bool isMp3, Color accent) {
    if (isMp3) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.audiotrack, color: accent),
      );
    } else {
      if (item.localPath != null && File(item.localPath!).existsSync()) {
        return FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(video: item.localPath!, imageFormat: ImageFormat.JPEG, maxWidth: 80, quality: 50),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(snapshot.data!, width: 60, height: 60, fit: BoxFit.cover));
            }
            return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.video_library, color: accent));
          },
        );
      }
      return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.video_library, color: accent));
    }
  }
}

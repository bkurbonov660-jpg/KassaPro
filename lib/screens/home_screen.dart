import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _selectedSource = 'youtube';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onAnalyze() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final provider = context.read<DownloadProvider>();
    provider.fetchMediaInfo(url).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(isDark, accent),
              const SizedBox(height: 24),
              Row(
                children: [
                  _sourceChip('youtube', 'YouTube', Icons.play_circle_filled),
                  const SizedBox(width: 8),
                  _sourceChip('tiktok', 'TikTok', Icons.music_note),
                  const SizedBox(width: 8),
                  _sourceChip('instagram', 'Instagram', Icons.camera_alt),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: _urlHint,
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                  prefixIcon: Icon(Icons.link, color: accent),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_urlController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          onPressed: () {
                            _urlController.clear();
                            provider.clearMediaInfo();
                            setState(() {});
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.search, color: accent),
                        onPressed: _onAnalyze,
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accent, width: 2)),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _onAnalyze(),
              ),
              const SizedBox(height: 20),
              if (provider.currentMediaInfo != null)
                _buildMediaInfoCard(provider, isDark, accent),
              if (provider.playlistInfos != null)
                _buildPlaylistView(provider, isDark, accent),
              const SizedBox(height: 20),
              Text('АКТИВНЫЕ ЗАДАЧИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              const SizedBox(height: 8),
              _buildActiveList(provider, isDark, accent),
            ],
          ),
        ),
      ),
    );
  }

  String get _urlHint {
    switch (_selectedSource) {
      case 'youtube': return 'Ссылка YouTube или плейлист';
      case 'tiktok': return 'Ссылка TikTok';
      case 'instagram': return 'Ссылка Instagram';
      default: return 'Вставьте ссылку';
    }
  }

  Widget _sourceChip(String value, String label, IconData icon) {
    final selected = _selectedSource == value;
    return ChoiceChip(
      selected: selected,
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(label)]),
      selectedColor: const Color(0xFF00E5FF).withOpacity(0.2),
      backgroundColor: Colors.transparent,
      side: BorderSide(color: selected ? const Color(0xFF00E5FF) : Colors.grey),
      onSelected: (_) => setState(() => _selectedSource = value),
    );
  }

  Widget _buildHeader(bool isDark, Color accent) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: accent.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.cloud_download_rounded, color: Colors.blueAccent, size: 28),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cyber Loader', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            Text('YouTube • TikTok • Instagram', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaInfoCard(DownloadProvider provider, bool isDark, Color accent) {
    final info = provider.currentMediaInfo!;
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: info.thumbnailUrl, width: 80, height: 60, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(info.duration, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: info.streams.map((s) => ActionChip(
                label: Text('${s.quality} ${s.format} (${(s.sizeBytes/1048576).toStringAsFixed(1)} MB)'),
                onPressed: () {
                  provider.startDownload(_urlController.text.trim(), _selectedSource, s, context);
                },
                backgroundColor: accent.withOpacity(0.1),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistView(DownloadProvider provider, bool isDark, Color accent) {
    final playlist = provider.playlistInfos!;
    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Плейлист (${playlist.length} видео)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...playlist.take(10).map((info) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: info.thumbnailUrl, width: 50, height: 40, fit: BoxFit.cover)),
              title: Text(info.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton<MediaStreamOption>(
                itemBuilder: (_) => info.streams.map((s) => PopupMenuItem(value: s, child: Text('${s.quality} ${s.format}'))).toList(),
                onSelected: (s) => provider.startDownload('', _selectedSource, s, context),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveList(DownloadProvider provider, bool isDark, Color accent) {
    final list = provider.history.where((e) => e.status == 'downloading').toList();
    if (list.isEmpty) return const SizedBox();
    return Column(
      children: list.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text('${(item.progress * 100).toStringAsFixed(0)}%', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                if (item.speed > 0) ...[
                  const SizedBox(width: 8),
                  Text('${(item.speed/1024).toStringAsFixed(0)} KB/s', style: TextStyle(color: accent.withOpacity(0.7), fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: item.progress, color: accent, backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ],
        ),
      )).toList(),
    );
  }
}

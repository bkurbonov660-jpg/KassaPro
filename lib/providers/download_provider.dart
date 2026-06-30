import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';

class DownloadProvider extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  List<DownloadItem> history = [];
  List<DownloadItem> favorites = [];
  int _currentTabIndex = 0;
  bool _isDownloading = false;
  MediaInfo? currentMediaInfo;
  List<MediaInfo>? playlistInfos;

  int get currentTabIndex => _currentTabIndex;
  bool get isDownloading => _isDownloading;

  Future<void> init() async {
    final isDark = await StorageService.loadTheme();
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    history = await StorageService.loadHistory();
    favorites = history.where((e) => e.favorite).toList();
    notifyListeners();
  }

  void setTab(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    await StorageService.saveTheme(isDark);
    notifyListeners();
  }

  Future<void> fetchMediaInfo(String url) async {
    try {
      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        if (url.contains('playlist')) {
          playlistInfos = await DownloadService.getYouTubePlaylist(url);
          currentMediaInfo = null;
        } else {
          currentMediaInfo = await DownloadService.getYouTubeInfo(url);
          playlistInfos = null;
        }
      } else if (url.contains('tiktok.com')) {
        currentMediaInfo = await DownloadService.getTikTokInfo(url);
        playlistInfos = null;
      } else if (url.contains('instagram.com')) {
        currentMediaInfo = await DownloadService.getInstagramInfo(url);
        playlistInfos = null;
      } else {
        throw Exception('Неподдерживаемая ссылка');
      }
      notifyListeners();
    } catch (e) {
      throw Exception('Ошибка получения информации: $e');
    }
  }

  void clearMediaInfo() {
    currentMediaInfo = null;
    playlistInfos = null;
    notifyListeners();
  }

  Future<void> startDownload(String url, String source, MediaStreamOption option,
      BuildContext context) async {
    if (_isDownloading) return;
    _isDownloading = true;
    notifyListeners();

    final limitMB = await StorageService.getTrafficLimitMB();
    if (limitMB > 0) {
      final usedBytes = await StorageService.getMonthlyTrafficBytes();
      final usedMB = usedBytes / (1024 * 1024);
      if (usedMB >= limitMB) {
        _showSnackBar(context, '⚠️ Достигнут лимит трафика ($limitMB МБ)', Colors.redAccent);
        _isDownloading = false;
        notifyListeners();
        return;
      }
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newItem = DownloadItem(
      id: id,
      title: currentMediaInfo?.title ?? '$source Media',
      url: url,
      source: source,
      type: option.format,
      quality: option.quality,
      totalSizeInBytes: option.sizeBytes,
      status: 'downloading',
      timestamp: DateTime.now(),
    );
    history.insert(0, newItem);
    await StorageService.saveHistory(history);
    notifyListeners();

    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    try {
      String? localPath;
      void progressCallback(int sent, int total) {
        final now = DateTime.now();
        final delta = now.difference(lastUpdate);
        if (delta.inMilliseconds > 500) {
          final bytesDelta = sent - lastBytes;
          final speed = bytesDelta / (delta.inMilliseconds / 1000.0);
          final index = history.indexWhere((e) => e.id == id);
          if (index != -1) {
            history[index] = history[index].copyWith(
              downloadedBytes: sent,
              totalSizeInBytes: total > 0 ? total : 1,
              speed: speed,
            );
            notifyListeners();
          }
          lastUpdate = now;
          lastBytes = sent;
        }
      }

      switch (source) {
        case 'youtube':
          localPath = await DownloadService.downloadYouTube(url, option, progressCallback);
          break;
        case 'tiktok':
          localPath = await DownloadService.downloadTikTok(url, option, progressCallback);
          break;
        case 'instagram':
          localPath = await DownloadService.downloadInstagram(url, option, progressCallback);
          break;
      }

      final index = history.indexWhere((e) => e.id == id);
      if (index != -1) {
        await StorageService.addMonthlyTrafficBytes(history[index].totalSizeInBytes);
        history[index] = history[index].copyWith(status: 'completed', localPath: localPath);
        if (history[index].favorite) _updateFavorites();
        await StorageService.saveHistory(history);
        notifyListeners();
      }
      _showSnackBar(context, '✅ Файл загружен', Colors.green);
    } catch (e) {
      final index = history.indexWhere((e) => e.id == id);
      if (index != -1) {
        history[index] = history[index].copyWith(status: 'failed');
        await StorageService.saveHistory(history);
        notifyListeners();
      }
      _showSnackBar(context, '❌ ${e.toString()}', Colors.redAccent);
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  void toggleFavorite(String id) {
    final index = history.indexWhere((e) => e.id == id);
    if (index != -1) {
      history[index] = history[index].copyWith(favorite: !history[index].favorite);
      StorageService.saveHistory(history);
      _updateFavorites();
      notifyListeners();
    }
  }

  void _updateFavorites() {
    favorites = history.where((e) => e.favorite).toList();
  }

  Future<void> deleteItem(String id) async {
    history.removeWhere((e) => e.id == id);
    _updateFavorites();
    await StorageService.saveHistory(history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    favorites.clear();
    await StorageService.saveHistory(history);
    notifyListeners();
  }

  void _showSnackBar(BuildContext context, String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }
}

import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import 'stream_service.dart';

class QueueManager extends ChangeNotifier {
  static final QueueManager instance = QueueManager._();
  QueueManager._();

  final List<DownloadItem> items = [];
  bool _isProcessing = false;

  void add(DownloadItem item) {
    items.insert(0, item);
    notifyListeners();
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;

    final nextIndex = items.indexWhere((i) => i.status == DownloadStatus.waiting);
    if (nextIndex == -1) return;

    _isProcessing = true;
    final task = items[nextIndex];
    task.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final info = await StreamService.resolveStream(
        url: task.url,
        isAudio: task.isAudio,
        quality: task.quality,
      );

      if (info != null && info['streamUrl'] != null) {
        task.title = info['title'] ?? task.title;
        final cleanName = task.title.replaceAll(RegExp(r'[^\w\s\u0400-\u04FF]+'), '_');
        final ext = task.isAudio ? 'mp3' : 'mp4';
        final fileName = "${cleanName}_${DateTime.now().millisecondsSinceEpoch}.$ext";

        final file = await StreamService.downloadMediaFile(
          downloadUrl: info['streamUrl']!,
          fileName: fileName,
          isAudio: task.isAudio,
          onProgress: (p) {
            task.progress = p;
            notifyListeners();
          },
        );

        if (file != null) {
          task.status = DownloadStatus.done;
          task.filePath = file.path;
          task.progress = 1.0;
        } else {
          task.status = DownloadStatus.error;
          task.error = "Ошибка записи потока";
        }
      } else {
        task.status = DownloadStatus.error;
        task.error = "Не удалось извлечь ссылку на поток";
      }
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = "$e";
    } finally {
      _isProcessing = false;
      notifyListeners();
      _processNext();
    }
  }

  void removeItem(String id) {
    items.removeWhere((i) => i.id == id);
    notifyListeners();
  }
}

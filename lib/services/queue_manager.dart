import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/download_item.dart';
import 'stream_service.dart';

class QueueManager extends ChangeNotifier {
  static final QueueManager instance = QueueManager._();
  QueueManager._();

  static const _platform = MethodChannel("com.obanstudio.downloader/shared");
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

    final int notifId = task.id.hashCode.abs() % 10000;

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

        final file = await StreamService.downloadMediaFileWithResume(
          downloadUrl: info['streamUrl']!,
          fileName: fileName,
          isAudio: task.isAudio,
          onProgress: (p, speed, eta) {
            task.progress = p;
            task.speed = speed;
            task.eta = eta;
            notifyListeners();

            // Обновление прогресс-бара в шторке
            _platform.invokeMethod('showProgressNotification', {
              'id': notifId,
              'title': task.title,
              'progress': (p * 100).toInt(),
              'speed': speed,
              'eta': eta,
            });
          },
        );

        if (file != null) {
          task.status = DownloadStatus.done;
          task.filePath = file.path;
          task.progress = 1.0;

          // Уведомление о готовности с кликом на открытие
          _platform.invokeMethod('showCompletedNotification', {
            'id': notifId,
            'title': task.title,
            'filePath': file.path,
            'mimeType': task.isAudio ? 'audio/mpeg' : 'video/mp4',
          });
        } else {
          task.status = DownloadStatus.error;
          task.error = "Ошибка записи потока";
          _platform.invokeMethod('cancelNotification', {'id': notifId});
        }
      } else {
        task.status = DownloadStatus.error;
        task.error = "Не удалось извлечь медиапоток";
        _platform.invokeMethod('cancelNotification', {'id': notifId});
      }
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = "$e";
      _platform.invokeMethod('cancelNotification', {'id': notifId});
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

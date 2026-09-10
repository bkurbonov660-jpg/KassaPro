import 'package:flutter/foundation.dart';
import '../models/download_item.dart';
import 'stream_service.dart';
import 'notification_service.dart';

class QueueManager extends ChangeNotifier {
  static final QueueManager instance = QueueManager._();
  QueueManager._();

  final List<DownloadItem> items = [];
  bool _isProcessing = false;
  DateTime _lastNotifTime = DateTime.now();

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
        final cleanName = task.title.replaceAll(RegExp(r'[^\w\s\u0400-\u04FF]+'), '_').trim();
        final ext = info['ext'] ?? (task.isAudio ? 'mp3' : 'mp4');
        final fileName = "${cleanName}_${task.id}.$ext";

        final file = await StreamService.downloadMediaFile(
          downloadUrl: info['streamUrl']!,
          fileName: fileName,
          isAudio: task.isAudio,
          onProgress: (p, speed, eta) {
            task.progress = p;
            task.speed = speed;
            task.eta = eta;
            notifyListeners();

            final now = DateTime.now();
            if (now.difference(_lastNotifTime).inMilliseconds >= 800) {
              _lastNotifTime = now;
              NotificationService.instance.updateProgressNotification(
                id: notifId,
                title: task.title,
                progress: p,
                speed: task.speedFormatted,
                eta: task.etaFormatted,
              );
            }
          },
        );

        if (file != null) {
          task.status = DownloadStatus.done;
          task.filePath = file.path;
          task.progress = 1.0;
          await NotificationService.instance.showCompleteNotification(
            id: notifId,
            title: task.title,
            filePath: file.path,
          );
        } else {
          task.status = DownloadStatus.error;
          task.error = "Ошибка записи (проверьте память)";
          await NotificationService.instance.cancel(notifId);
        }
      } else {
        task.status = DownloadStatus.error;
        task.error = "Не удалось извлечь поток. Попробуйте еще раз.";
        await NotificationService.instance.cancel(notifId);
      }
    } catch (e) {
      task.status = DownloadStatus.error;
      task.error = "$e";
      await NotificationService.instance.cancel(notifId);
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

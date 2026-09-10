enum DownloadStatus { waiting, downloading, done, error }

class DownloadItem {
  final String id;
  final String url;
  String title;
  final bool isAudio;
  final String quality;
  double progress;
  double speed;
  Duration eta;
  DownloadStatus status;
  String? filePath;
  String? error;

  DownloadItem({
    required this.id,
    required this.url,
    required this.title,
    required this.isAudio,
    required this.quality,
    this.progress = 0.0,
    this.speed = 0.0,
    this.eta = Duration.zero,
    this.status = DownloadStatus.waiting,
    this.filePath,
    this.error,
  });

  String get speedFormatted {
    if (speed <= 0) return "0 КБ/с";
    if (speed < 1024 * 1024) {
      return "${(speed / 1024).toStringAsFixed(1)} КБ/с";
    }
    return "${(speed / (1024 * 1024)).toStringAsFixed(2)} МБ/с";
  }

  String get etaFormatted {
    if (eta.inSeconds <= 0) return "--:--";
    final m = eta.inMinutes;
    final s = eta.inSeconds % 60;
    if (m > 59) {
      return "${eta.inHours}ч ${m % 60}м";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
}

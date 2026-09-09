enum DownloadStatus { waiting, downloading, done, error }

class DownloadItem {
  final String id;
  final String url;
  String title;
  final bool isAudio;
  final String quality;
  double progress;
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
    this.status = DownloadStatus.waiting,
    this.filePath,
    this.error,
  });
}

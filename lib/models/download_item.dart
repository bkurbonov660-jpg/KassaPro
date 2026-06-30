class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String source;
  final String type;
  final String quality;
  final int totalSizeInBytes;
  int downloadedBytes;
  String status;
  final DateTime timestamp;
  String? localPath;
  bool favorite;
  double speed; // bytes per second

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.source,
    required this.type,
    required this.quality,
    required this.totalSizeInBytes,
    this.downloadedBytes = 0,
    this.status = 'pending',
    required this.timestamp,
    this.localPath,
    this.favorite = false,
    this.speed = 0,
  });

  double get progress => totalSizeInBytes == 0 ? 0 : downloadedBytes / totalSizeInBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'source': source,
    'type': type,
    'quality': quality,
    'totalSizeInBytes': totalSizeInBytes,
    'downloadedBytes': downloadedBytes,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'localPath': localPath,
    'favorite': favorite,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    id: json['id'],
    title: json['title'],
    url: json['url'],
    source: json['source'],
    type: json['type'],
    quality: json['quality'],
    totalSizeInBytes: json['totalSizeInBytes'],
    downloadedBytes: json['downloadedBytes'] ?? 0,
    status: json['status'] ?? 'completed',
    timestamp: DateTime.parse(json['timestamp']),
    localPath: json['localPath'],
    favorite: json['favorite'] ?? false,
  );

  DownloadItem copyWith({
    int? downloadedBytes,
    int? totalSizeInBytes,
    String? status,
    String? localPath,
    bool? favorite,
    double? speed,
  }) =>
      DownloadItem(
        id: id,
        title: title,
        url: url,
        source: source,
        type: type,
        quality: quality,
        totalSizeInBytes: totalSizeInBytes ?? this.totalSizeInBytes,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        status: status ?? this.status,
        timestamp: timestamp,
        localPath: localPath ?? this.localPath,
        favorite: favorite ?? this.favorite,
        speed: speed ?? this.speed,
      );
}

class MediaInfo {
  final String title;
  final String thumbnailUrl;
  final String duration;
  final List<MediaStreamOption> streams;

  MediaInfo({required this.title, required this.thumbnailUrl, required this.duration, required this.streams});
}

class MediaStreamOption {
  final String quality;
  final int sizeBytes;
  final String format;
  final String url;

  MediaStreamOption({required this.quality, required this.sizeBytes, required this.format, required this.url});
}

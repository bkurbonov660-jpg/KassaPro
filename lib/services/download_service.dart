import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/download_item.dart';
import 'storage_service.dart';

class DownloadService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 30),
  ));

  static Future<bool> hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  static String _cleanUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
        query: uri.query,
      ).toString();
    } catch (_) {
      return url;
    }
  }

  // ---------- YouTube ----------
  static Future<MediaInfo> getYouTubeInfo(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(url);
      final streams = <MediaStreamOption>[];

      for (final muxed in manifest.muxed) {
        streams.add(MediaStreamOption(
          quality: '${muxed.videoQuality.label} (${muxed.videoCodec})',
          sizeBytes: muxed.size.totalBytes,
          format: 'mp4',
          url: muxed.url.toString(),
        ));
      }
      for (final audio in manifest.audioOnly) {
        streams.add(MediaStreamOption(
          quality: '${audio.audioCodec} ${audio.bitrate.kbps} kbps',
          sizeBytes: audio.size.totalBytes,
          format: 'mp3',
          url: audio.url.toString(),
        ));
      }
      return MediaInfo(
        title: video.title,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration?.toString() ?? '??',
        streams: streams,
      );
    } finally {
      yt.close();
    }
  }

  static Future<List<MediaInfo>> getYouTubePlaylist(String playlistUrl) async {
    final yt = YoutubeExplode();
    try {
      final playlist = await yt.playlists.get(playlistUrl);
      final videos = await yt.playlists.getVideos(playlist.id).toList();
      final List<MediaInfo> infos = [];
      for (final video in videos) {
        final manifest = await yt.videos.streamsClient.getManifest(video.id.value);
        final streams = <MediaStreamOption>[];
        for (final muxed in manifest.muxed) {
          streams.add(MediaStreamOption(
            quality: '${muxed.videoQuality.label}',
            sizeBytes: muxed.size.totalBytes,
            format: 'mp4',
            url: muxed.url.toString(),
          ));
        }
        infos.add(MediaInfo(
          title: video.title,
          thumbnailUrl: video.thumbnails.highResUrl,
          duration: video.duration?.toString() ?? '??',
          streams: streams,
        ));
      }
      return infos;
    } finally {
      yt.close();
    }
  }

  static Future<String?> downloadYouTube(String url, MediaStreamOption option,
      Function(int sent, int total) onProgress) async {
    if (!await hasInternet()) throw Exception('Нет интернет-соединения.');
    final safeTitle = Uri.parse(url).pathSegments.last.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    final savePath = await _getSavePath('$safeTitle.${option.format}');
    await _dio.download(option.url, savePath, onReceiveProgress: onProgress);
    return savePath;
  }

  // ---------- TikTok ----------
  static Future<MediaInfo> getTikTokInfo(String url) async {
    const apiUrl = 'https://tikwm.com/api/';
    final response = await _dio.post(apiUrl, data: {'url': url});
    if (response.statusCode != 200 || response.data['code'] != 0) {
      throw Exception('TikTok API error');
    }
    final data = response.data['data'];
    return MediaInfo(
      title: data['title'] ?? 'TikTok',
      thumbnailUrl: data['cover'] ?? '',
      duration: '${data['duration']} сек',
      streams: [
        MediaStreamOption(quality: 'HD', sizeBytes: 0, format: 'mp4', url: data['play']),
        MediaStreamOption(quality: 'Audio', sizeBytes: 0, format: 'mp3', url: data['music']),
      ],
    );
  }

  static Future<String?> downloadTikTok(String url, MediaStreamOption option,
      Function(int sent, int total) onProgress) async {
    if (!await hasInternet()) throw Exception('Нет интернет-соединения.');
    final savePath = await _getSavePath('tiktok_${DateTime.now().millisecondsSinceEpoch}.${option.format}');
    await _dio.download(option.url, savePath, onReceiveProgress: onProgress);
    return savePath;
  }

  // ---------- Instagram ----------
  static Future<MediaInfo> getInstagramInfo(String url) async {
    const apiUrl = 'https://api.instadownloader.net/api/';
    final response = await _dio.get(apiUrl, queryParameters: {'url': url});
    if (response.statusCode != 200 || response.data['status'] != 'ok') {
      throw Exception('Instagram API error');
    }
    final data = response.data['data'];
    return MediaInfo(
      title: data['title'] ?? 'Instagram',
      thumbnailUrl: data['thumbnail'] ?? '',
      duration: '??',
      streams: [
        MediaStreamOption(
          quality: 'HD',
          sizeBytes: 0,
          format: 'mp4',
          url: data['video_url'] ?? data['url'],
        ),
      ],
    );
  }

  static Future<String?> downloadInstagram(String url, MediaStreamOption option,
      Function(int sent, int total) onProgress) async {
    if (!await hasInternet()) throw Exception('Нет интернет-соединения.');
    final savePath = await _getSavePath('insta_${DateTime.now().millisecondsSinceEpoch}.${option.format}');
    await _dio.download(option.url, savePath, onReceiveProgress: onProgress);
    return savePath;
  }

  static Future<String> _getSavePath(String fileName) async {
    String? folder = await StorageService.getSaveFolder();
    if (folder != null) {
      final dir = Directory(folder);
      if (!await dir.exists()) await dir.create(recursive: true);
      return p.join(folder, fileName);
    }
    Directory? dir;
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) {
        dir = downloads;
      } else {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getDownloadsDirectory();
    }
    return p.join(dir!.path, fileName);
  }
}

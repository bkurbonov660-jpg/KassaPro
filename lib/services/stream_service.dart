import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamService {
  static const _platform = MethodChannel("com.obanstudio.downloader/shared");

  static String? extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=|(?:shorts\/))|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  static Future<Map<String, String>?> resolveStream({
    required String url,
    required bool isAudio,
    required String quality,
  }) async {
    // 1. YouTube — прямое извлечение потоков (со звуком)
    final ytId = extractYouTubeId(url);
    if (ytId != null) {
      try {
        final yt = YoutubeExplode();
        final video = await yt.videos.get(ytId);
        final manifest = await yt.videos.streams.getManifest(ytId);

        if (isAudio) {
          final audioStream = manifest.audioOnly.withHighestBitrate();
          yt.close();
          return {
            'title': video.title,
            'streamUrl': audioStream.url.toString(),
            'ext': 'mp3',
          };
        } else {
          final muxedStreams = manifest.muxed.sortByVideoQuality();
          if (muxedStreams.isNotEmpty) {
            final target = muxedStreams.firstWhere(
              (s) => s.qualityLabel.contains(quality),
              orElse: () => muxedStreams.last,
            );
            yt.close();
            return {
              'title': video.title,
              'streamUrl': target.url.toString(),
              'ext': 'mp4',
            };
          }
        }
        yt.close();
      } catch (_) {}
    }

    // 2. TikTok — без водяных знаков
    if (url.contains("tiktok.com")) {
      try {
        final api = Uri.parse("https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}");
        final res = await http.get(api).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['code'] == 0) {
            final d = data['data'];
            return {
              'title': d['title'] ?? 'TikTok_Video',
              'streamUrl': isAudio ? (d['music'] ?? d['play']) : (d['play'] ?? d['wmplay']),
              'ext': isAudio ? 'mp3' : 'mp4',
            };
          }
        }
      } catch (_) {}
    }

    // 3. Резервный шлюз Piped API
    if (ytId != null) {
      final pipedMirrors = [
        "https://pipedapi.kavin.rocks",
        "https://api.piped.privacydev.net",
        "https://pipedapi.leptons.xyz",
      ];
      for (final mirror in pipedMirrors) {
        try {
          final res = await http.get(Uri.parse("$mirror/streams/$ytId")).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final json = jsonDecode(res.body);
            final title = json['title'] ?? 'YouTube_Media';
            if (isAudio) {
              final audioList = (json['audioStreams'] as List?) ?? [];
              if (audioList.isNotEmpty) {
                return {'title': title, 'streamUrl': audioList.first['url'], 'ext': 'mp3'};
              }
            } else {
              final videoList = (json['videoStreams'] as List?) ?? [];
              final target = videoList.firstWhere(
                (v) => (v['quality'] as String? ?? '').contains(quality),
                orElse: () => videoList.isNotEmpty ? videoList.first : null,
              );
              if (target != null) {
                return {'title': title, 'streamUrl': target['url'], 'ext': 'mp4'};
              }
            }
          }
        } catch (_) {}
      }
    }

    return null;
  }

  // Скачивание с поддержкой ДОКАЧКИ (Range) и замером РЕАЛЬНОЙ СКОРОСТИ
  static Future<File?> downloadMediaFile({
    required String downloadUrl,
    required String fileName,
    required bool isAudio,
    required void Function(double progress, double speed, Duration eta) onProgress,
  }) async {
    try {
      Directory saveDir;
      if (Platform.isAndroid) {
        final targetPath = isAudio ? '/storage/emulated/0/Music/OBAN' : '/storage/emulated/0/Movies/OBAN';
        saveDir = Directory(targetPath);
        if (!await saveDir.exists()) {
          try {
            await saveDir.create(recursive: true);
          } catch (_) {
            final ext = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
            saveDir = Directory("${ext.path}/OBAN_Downloads");
          }
        }
      } else {
        final ext = await getApplicationDocumentsDirectory();
        saveDir = Directory("${ext.path}/OBAN_Downloads");
      }

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final partFile = File("${saveDir.path}/$fileName.part");
      int existingBytes = 0;
      if (await partFile.exists()) {
        existingBytes = await partFile.length();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36';

      // Докачка через Range
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await client.send(request);
      final bool isPartial = response.statusCode == 206;
      final int totalBytes = isPartial
          ? ((response.contentLength ?? 0) + existingBytes)
          : (response.contentLength ?? 0);

      final sink = partFile.openWrite(mode: (isPartial && existingBytes > 0) ? FileMode.append : FileMode.write);
      int receivedBytes = (isPartial && existingBytes > 0) ? existingBytes : 0;

      int lastBytes = receivedBytes;
      DateTime lastSampleTime = DateTime.now();
      double currentSpeed = 0.0;
      Duration eta = Duration.zero;

      await response.stream.listen((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        final elapsedMs = now.difference(lastSampleTime).inMilliseconds;

        // Расчет скорости каждые 600 мс
        if (elapsedMs >= 600) {
          final delta = receivedBytes - lastBytes;
          currentSpeed = delta / (elapsedMs / 1000.0);
          lastBytes = receivedBytes;
          lastSampleTime = now;

          if (totalBytes > 0 && currentSpeed > 0) {
            final remBytes = totalBytes - receivedBytes;
            final remSec = (remBytes / currentSpeed).round();
            eta = Duration(seconds: remSec > 0 ? remSec : 0);
          }
        }

        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes, currentSpeed, eta);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      final targetFile = File("${saveDir.path}/$fileName");
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final finalFile = await partFile.rename(targetFile.path);

      try {
        await _platform.invokeMethod('scanMediaFile', {
          'filePath': finalFile.path,
          'mimeType': isAudio ? 'audio/mpeg' : 'video/mp4',
        });
      } catch (_) {}

      return finalFile;
    } catch (_) {
      return null;
    }
  }
}

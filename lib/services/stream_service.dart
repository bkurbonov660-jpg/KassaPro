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

  // Извлечение потока: YouTube через youtube_explode_dart, TikTok через TikWM
  static Future<Map<String, String>?> resolveStream({
    required String url,
    required bool isAudio,
    required String quality,
  }) async {
    // 1. YouTube через нативный Dart парсер
    final ytId = extractYouTubeId(url);
    if (ytId != null) {
      final yt = YoutubeExplode();
      try {
        final video = await yt.videos.get(ytId);
        final manifest = await yt.videos.streamsClient.getManifest(ytId);

        if (isAudio) {
          final audioStream = manifest.audioOnly.withHighestBitrate();
          return {
            'title': video.title,
            'streamUrl': audioStream.url.toString(),
          };
        } else {
          final muxed = manifest.muxed.toList();
          StreamInfo target;
          if (quality.contains('720')) {
            target = muxed.firstWhere(
              (s) => s.videoQualityLabel.contains('720'),
              orElse: () => manifest.muxed.bestQuality,
            );
          } else if (quality.contains('480')) {
            target = muxed.firstWhere(
              (s) => s.videoQualityLabel.contains('480'),
              orElse: () => muxed.isNotEmpty ? muxed.first : manifest.muxed.bestQuality,
            );
          } else {
            target = manifest.muxed.bestQuality;
          }

          return {
            'title': video.title,
            'streamUrl': target.url.toString(),
          };
        }
      } catch (_) {
        // Резерв через Cobalt шлюз
        try {
          final res = await http.post(
            Uri.parse("https://api.cobalt.tools/api/json"),
            headers: {"Accept": "application/json", "Content-Type": "application/json"},
            body: jsonEncode({
              "url": url,
              "vQuality": quality.replaceAll('p', ''),
              "isAudioOnly": isAudio,
            }),
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final j = jsonDecode(res.body);
            if (j['url'] != null) {
              return {'title': 'YouTube_Media', 'streamUrl': j['url']};
            }
          }
        } catch (__) {}
      } finally {
        yt.close();
      }
    }

    // 2. TikTok без водяного знака
    if (url.contains("tiktok.com")) {
      try {
        final api = Uri.parse("https://www.tikwm.com/api/?url=${Uri.encodeComponent(url)}");
        final res = await http.get(api).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['code'] == 0) {
            final d = data['data'];
            return {
              'title': d['title'] ?? 'TikTok_Media',
              'streamUrl': isAudio ? (d['music'] ?? d['play']) : (d['play'] ?? d['wmplay']),
            };
          }
        }
      } catch (_) {}
    }

    return null;
  }

  // Скачивание с поддержкой докачки (HTTP Range), подсчётом скорости и ETA
  static Future<File?> downloadMediaFileWithResume({
    required String downloadUrl,
    required String fileName,
    required bool isAudio,
    required void Function(double progress, String speed, String eta) onProgress,
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

      final targetFile = File("${saveDir.path}/$fileName");
      final partFile = File("${saveDir.path}/.$fileName.part");

      int downloadedBytes = 0;
      if (await partFile.exists()) {
        downloadedBytes = await partFile.length();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));

      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);

      int totalBytes = 0;
      IOSink sink;

      if (response.statusCode == 206) {
        // Сервер подтвердил докачку
        totalBytes = (response.contentLength ?? 0) + downloadedBytes;
        sink = partFile.openWrite(mode: FileMode.append);
      } else {
        // Полная загрузка с нуля
        downloadedBytes = 0;
        totalBytes = response.contentLength ?? 0;
        sink = partFile.openWrite(mode: FileMode.write);
      }

      int receivedSinceStart = 0;
      final stopwatch = Stopwatch()..start();
      DateTime lastUpdate = DateTime.now();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        receivedSinceStart += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 300) {
          lastUpdate = now;
          final elapsed = stopwatch.elapsedMilliseconds / 1000.0;
          final speedBytesSec = elapsed > 0 ? (receivedSinceStart / elapsed) : 0.0;

          String speedStr;
          if (speedBytesSec >= 1024 * 1024) {
            speedStr = "${(speedBytesSec / (1024 * 1024)).toStringAsFixed(1)} МБ/с";
          } else {
            speedStr = "${(speedBytesSec / 1024).toStringAsFixed(0)} КБ/с";
          }

          String etaStr = "--:--";
          if (speedBytesSec > 0 && totalBytes > downloadedBytes) {
            final remSec = ((totalBytes - downloadedBytes) / speedBytesSec).round();
            final m = (remSec ~/ 60).toString().padLeft(2, '0');
            final s = (remSec % 60).toString().padLeft(2, '0');
            etaStr = "$m:$s";
          }

          final prog = totalBytes > 0 ? (downloadedBytes / totalBytes) : 0.0;
          onProgress(prog, speedStr, etaStr);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final finalFile = await partFile.rename(targetFile.path);

      // Сканирование в системную Галерею
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

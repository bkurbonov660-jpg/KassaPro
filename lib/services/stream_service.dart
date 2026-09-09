import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  // Получение прямой рабочей ссылки без повреждения файла
  static Future<Map<String, String>?> resolveStream({
    required String url,
    required bool isAudio,
    required String quality,
  }) async {
    // 1. Обработка TikTok
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
            };
          }
        }
      } catch (_) {}
    }

    // 2. Обработка YouTube (через публичные Invidious / Cobalt шлюзы)
    final ytId = extractYouTubeId(url);
    if (ytId != null) {
      final instances = [
        "https://invidious.nerdvpn.de",
        "https://inv.nadeko.net",
        "https://invidious.projectsegfau.lt",
        "https://yt.drgnz.club"
      ];

      for (final host in instances) {
        try {
          final uri = Uri.parse("$host/api/v1/videos/$ytId");
          final res = await http.get(uri).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final json = jsonDecode(res.body);
            final title = json['title'] ?? 'YouTube_Media';

            if (isAudio) {
              final formats = (json['adaptiveFormats'] as List?) ?? [];
              final audio = formats.firstWhere(
                (f) => (f['type'] as String? ?? '').contains('audio'),
                orElse: () => formats.isNotEmpty ? formats.first : null,
              );
              if (audio != null && audio['url'] != null) {
                return {'title': title, 'streamUrl': audio['url'] as String};
              }
            } else {
              final streams = (json['formatStreams'] as List?) ?? [];
              if (streams.isNotEmpty) {
                // Поиск подходящего разрешения
                var target = streams.firstWhere(
                  (s) => (s['qualityLabel'] as String? ?? '').contains(quality),
                  orElse: () => streams.first,
                );
                return {'title': title, 'streamUrl': target['url'] as String};
              }
            }
          }
        } catch (_) {
          continue;
        }
      }
    }

    // Резервный универсальный шлюз (Cobalt)
    try {
      final res = await http.post(
        Uri.parse("https://api.cobalt.tools/api/json"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "url": url,
          "vQuality": quality.replaceAll('p', ''),
          "isAudioOnly": isAudio,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['url'] != null) {
          return {'title': 'Media_Download', 'streamUrl': j['url']};
        }
      }
    } catch (_) {}

    return null;
  }

  // Сохранение напрямую в системную папку Movies/Music и уведомление Галереи
  static Future<File?> downloadMediaFile({
    required String downloadUrl,
    required String fileName,
    required bool isAudio,
    required void Function(double) onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      int received = 0;

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

      final file = File("${saveDir.path}/$fileName");
      final sink = file.openWrite();

      await response.stream.listen((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }).asFuture();

      await sink.close();

      // Вызываем MediaScanner, чтобы файл мгновенно отобразился в Галерее телефона
      try {
        await _platform.invokeMethod('scanMediaFile', {
          'filePath': file.path,
          'mimeType': isAudio ? 'audio/mpeg' : 'video/mp4',
        });
      } catch (_) {}

      return file;
    } catch (_) {
      return null;
    }
  }
}

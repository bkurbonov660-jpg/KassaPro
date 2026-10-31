import 'dart:convert';
import 'package:flutter/services.dart';
import 'config.dart';
import 'dict.dart';
import 'models.dart';
import 'native.dart';
import 'net.dart';

class StreamsLoader {
  static const String remoteUrl = '${Cfg.dataBase}/streams.json';
  static Map<String, List<Map<String, dynamic>>>? _memCache;

  static Map<String, List<Map<String, dynamic>>> _parseMap(String raw) {
    final Map<String, List<Map<String, dynamic>>> result = {};
    if (raw.trim().isEmpty) return result;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map) {
      decoded.forEach((key, value) {
        if (value is List) {
          final items = <Map<String, dynamic>>[];
          for (final e in value) {
            if (e is Map) {
              final m = Map<String, dynamic>.from(e);
              final url = (m['url'] ?? '').toString().trim();
              if (url.isNotEmpty) {
                m['url'] = url;
                m['dub'] = (m['dub'] ?? 'Оригинал').toString().trim();
                items.add(m);
              }
            }
          }
          if (items.isNotEmpty) {
            result[key.toString()] = items;
          }
        }
      });
    }
    return result;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> load() async {
    if (_memCache != null && _memCache!.isNotEmpty) return _memCache!;
    final Map<String, List<Map<String, dynamic>>> merged = {};

    // 1. Загружаем встроенный assets/streams.json
    try {
      final String jsonString = await rootBundle.loadString('assets/streams.json');
      merged.addAll(_parseMap(jsonString));
    } catch (_) {}

    // 2. Дополняем локальным кэшем с диска (если уже обновлялся с сервера)
    try {
      final String? cached = await Native.fileRead('streams_cache.json');
      if (cached != null && cached.isNotEmpty) {
        final localMap = _parseMap(cached);
        localMap.forEach((k, v) => merged[k] = v);
      }
    } catch (_) {}

    _memCache = merged;
    return merged;
  }

  // Фоновая синхронизация свежего streams.json с сервера (OTA)
  static Future<Map<String, List<Map<String, dynamic>>>> syncRemote() async {
    try {
      final dynamic data = await Net.json(
        Uri.parse(remoteUrl),
        retries: 1,
        timeout: const Duration(seconds: 20),
      );
      if (data is Map && data.isNotEmpty) {
        final raw = jsonEncode(data);
        final remoteMap = _parseMap(raw);
        if (remoteMap.isNotEmpty) {
          await Native.fileWrite('streams_cache.json', raw);
          final base = await load();
          remoteMap.forEach((k, v) => base[k] = v);
          _memCache = base;
          return base;
        }
      }
    } catch (_) {}
    return _memCache ?? <String, List<Map<String, dynamic>>>{};
  }

  static List<Map<String, dynamic>> _lookupRawStreams(
    int dramaId,
    Map<String, List<Map<String, dynamic>>> allStreams, {
    String enTitle = '',
    String ruTitle = '',
  }) {
    final List<Map<String, dynamic>> found = [];
    final Set<String> seenUrls = {};

    void addList(List<Map<String, dynamic>>? list) {
      if (list == null) return;
      for (final s in list) {
        final u = (s['url'] ?? '').toString().trim();
        if (u.isNotEmpty && seenUrls.add(u)) {
          found.add(s);
        }
      }
    }

    addList(allStreams[dramaId.toString()]);
    if (enTitle.isNotEmpty) {
      final k = nk(enTitle);
      final ck = canonicalDramaKey(enTitle);
      if (k.isNotEmpty) addList(allStreams[k]);
      if (ck.isNotEmpty && ck != k) addList(allStreams[ck]);
    }
    if (ruTitle.isNotEmpty) {
      final rl = ruTitle.trim().toLowerCase().replaceAll('ё', 'е');
      allStreams.forEach((_, list) {
        for (final s in list) {
          final st = (s['title'] ?? '').toString().trim().toLowerCase().replaceAll('ё', 'е');
          if (st.isNotEmpty && st == rl) {
            final u = (s['url'] ?? '').toString().trim();
            if (u.isNotEmpty && seenUrls.add(u)) found.add(s);
          }
        }
      });
    }
    return found;
  }

  static bool _dubMatches(String streamDub, String selectedDub) {
    final a = streamDub.trim().toLowerCase().replaceAll('ё', 'е');
    final b = selectedDub.trim().toLowerCase().replaceAll('ё', 'е');
    if (a.isEmpty || b.isEmpty) return true;
    if (a == 'auto' || a == 'неизвестная' || a == 'оригинал') return true;
    if (a.contains(b) || b.contains(a)) return true;
    // Сопоставление популярных студий ("DubLik TV" <-> "DubLik", "FSG Мания" <-> "FSG")
    final aFirst = a.split(RegExp(r'[\s_\-]+')).first;
    final bFirst = b.split(RegExp(r'[\s_\-]+')).first;
    if (aFirst.length >= 3 && aFirst == bFirst) return true;
    return false;
  }

  // Получить ссылки для конкретной дорамы и выбранной озвучки
  static List<String> getUrlsForDramaAndDub(
    int dramaId,
    String? selectedDub,
    Map<String, List<Map<String, dynamic>>> allStreams, {
    String enTitle = '',
    String ruTitle = '',
  }) {
    final streams = _lookupRawStreams(
      dramaId,
      allStreams,
      enTitle: enTitle,
      ruTitle: ruTitle,
    );
    if (streams.isEmpty) return [];

    if (selectedDub == null || selectedDub.trim().isEmpty || selectedDub == 'Не выбрана') {
      return streams.map((s) => (s['url'] ?? '').toString()).where((u) => u.isNotEmpty).toSet().toList();
    }

    final filtered = streams.where((s) {
      final dub = (s['dub'] ?? '').toString();
      return _dubMatches(dub, selectedDub);
    }).toList();

    return filtered.map((s) => (s['url'] ?? '').toString()).where((u) => u.isNotEmpty).toSet().toList();
  }

  // Получить полные объекты потоков для дорамы
  static List<Map<String, dynamic>> getEntriesForDrama(
    Drama d,
    String? selectedDub,
    Map<String, List<Map<String, dynamic>>> allStreams, {
    String ruTitle = '',
  }) {
    final raw = _lookupRawStreams(d.id, allStreams, enTitle: d.en, ruTitle: ruTitle);
    if (raw.isEmpty) return [];
    if (selectedDub == null || selectedDub.trim().isEmpty || selectedDub == 'Не выбрана') {
      return raw;
    }
    return raw.where((s) => _dubMatches((s['dub'] ?? '').toString(), selectedDub)).toList();
  }

  // Список всех доступных озвучек для конкретной дорамы в базе потоков
  static List<String> getAvailableDubsForDrama(
    Drama d,
    Map<String, List<Map<String, dynamic>>> allStreams, {
    String ruTitle = '',
  }) {
    final raw = _lookupRawStreams(d.id, allStreams, enTitle: d.en, ruTitle: ruTitle);
    final out = <String>[];
    for (final s in raw) {
      final dub = (s['dub'] ?? '').toString().trim();
      if (dub.isNotEmpty && dub != 'Auto' && !out.contains(dub)) {
        out.add(dub);
      }
    }
    return out;
  }
}

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'data2026.dart';
import 'dict.dart';
import 'models.dart';
import 'native.dart';
import 'net.dart';

class StreamsLoader {
  static const String remoteUrl = '${Cfg.dataBase}/streams.json';
  static Map<String, List<Map<String, dynamic>>>? _memCache;
  static final Map<int, List<Map<String, dynamic>>> _dramaCache = {};

  // Публичные токены Kodik (работают без регистрации)
  static const List<String> _kodikTokens = [
    '447d179e875efe44217f20d1ee2146be',
    'b7cc4293ed475c4ad1fd599d114f4435',
    'a0457f4b21f872cb5df96d1a6f70b8e4',
    '71d163b40d50397a86ca54c366f33b72',
    '98f4818f4062f9a5b6e29e2095f9793a',
  ];

  static Map<String, List<Map<String, dynamic>>> _parseMap(String raw) {
    final result = <String, List<Map<String, dynamic>>>{};
    if (raw.trim().isEmpty) return result;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is List) {
            final items = <Map<String, dynamic>>[];
            for (final e in value) {
              if (e is Map) {
                final m = Map<String, dynamic>.from(e);
                final url = (m['url'] ?? '').toString().trim();
                // Никаких VK, никаких тестовых ссылок
                if (url.isNotEmpty &&
                    !url.contains('vkvideo.ru') &&
                    !url.contains('vk.com/video') &&
                    !url.contains('test-streams.mux.dev')) {
                  m['url'] = url;
                  m['dub'] = _normalizeStudio((m['dub'] ?? 'SoftBox').toString());
                  items.add(m);
                }
              }
            }
            if (items.isNotEmpty) result[key.toString()] = items;
          }
        });
      }
    } catch (_) {}
    return result;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> load() async {
    if (_memCache != null) return _memCache!;
    final merged = <String, List<Map<String, dynamic>>>{};
    try {
      final s = await rootBundle.loadString('assets/streams.json');
      merged.addAll(_parseMap(s));
    } catch (_) {}
    try {
      final cached = await Native.fileRead('streams_cache.json');
      if (cached != null && cached.isNotEmpty) {
        _parseMap(cached).forEach((k, v) => merged[k] = v);
      }
    } catch (_) {}
    _memCache = merged;
    return merged;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> syncRemote() async {
    try {
      final dynamic data = await Net.json(
        Uri.parse(remoteUrl),
        retries: 1,
        timeout: const Duration(seconds: 15),
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

  static String _normalizeStudio(String raw) {
    final low = raw.toLowerCase().replaceAll('ё', 'е');
    if (low.contains('softbox') || low.contains('софтбокс')) return 'SoftBox';
    if (low.contains('dublik') || low.contains('даблик') || low.contains('дублик')) return 'DubLik TV';
    if (low.contains('fsg') || low.contains('мания') || low.contains('mania')) return 'FSG Мания';
    if (low.contains('лимон') || low.contains('аконя')) return 'Принц Лимон и Аконя';
    if (low.contains('steponee') || low.contains('степони')) return 'STEPonee';
    if (low.contains('храм дорам')) return 'Храм Дорам';
    if (low.contains('animount') || low.contains('анимаунт')) return 'АниМаунт';
    if (low.contains('highhopes')) return 'HighHopes';
    if (low.contains('кардинал') || low.contains('cardinal')) return 'FSG Кардинал';
    if (low.contains('субтитр') || low.contains('sub')) return 'Субтитры';
    return raw.trim().isEmpty ? 'SoftBox' : raw.trim();
  }

  static void _parseKodikResults(dynamic j, Set<String> seen, List<Map<String, dynamic>> results) {
    if (j is! Map || j['results'] is! List) return;
    for (final item in j['results'] as List) {
      if (item is! Map) continue;
      var link = (item['link'] ?? '').toString().trim();
      if (link.startsWith('//')) link = 'https:$link';
      if (link.isEmpty || !seen.add(link)) continue;

      final tr = item['translation'];
      final rawDub = tr is Map ? (tr['title'] ?? 'SoftBox').toString() : 'SoftBox';

      final epMap = <String, String>{};
      final seasons = item['seasons'];
      if (seasons is Map) {
        seasons.forEach((_, sv) {
          if (sv is Map && sv['episodes'] is Map) {
            (sv['episodes'] as Map).forEach((ek, ev) {
              var el = '';
              if (ev is String) {
                el = ev.trim();
              } else if (ev is Map) {
                el = (ev['link'] ?? '').toString().trim();
              }
              if (el.startsWith('//')) el = 'https:$el';
              if (el.isNotEmpty) epMap[ek.toString()] = el;
            });
          }
        });
      }

      results.add({
        'url': link,
        'embed': link,
        'dub': _normalizeStudio(rawDub),
        'episodes': epMap,
        'source': 'kodik',
      });
    }
  }

  // Быстрый поиск в Kodik API (поддерживает оба домена kodikapi.com и kodik-api.com + POST/GET + резервный парсинг Kodik iframe)
  static Future<List<Map<String, dynamic>>> searchKodik({
    required String ruTitle,
    required String enTitle,
    String imdb = '',
    int? dramaId,
  }) async {
    if (dramaId != null && _dramaCache.containsKey(dramaId) && _dramaCache[dramaId]!.isNotEmpty) {
      return _dramaCache[dramaId]!;
    }

    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    // 0. Проверяем локальный кэш streams.json
    final localAll = await load();
    if (dramaId != null) {
      final cachedList = localAll[dramaId.toString()] ?? localAll[nk(enTitle)] ?? localAll[canonicalDramaKey(enTitle)];
      if (cachedList != null && cachedList.isNotEmpty) {
        for (final s in cachedList) {
          final u = (s['url'] ?? '').toString().trim();
          if (u.isNotEmpty && !u.contains('vkvideo.ru') && !u.contains('test-streams.mux.dev') && seen.add(u)) {
            results.add(s);
          }
        }
        if (results.isNotEmpty) {
          _dramaCache[dramaId] = results;
          return results;
        }
      }
    }

    final shortRu = ruTitle.contains(':') ? ruTitle.split(':').first.trim() : '';
    final shortEn = enTitle.contains(':') ? enTitle.split(':').first.trim() : '';

    for (final token in _kodikTokens.take(3)) {
      final queries = <Map<String, String>>[
        if (imdb.isNotEmpty)
          {'token': token, 'imdb_id': imdb, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '20'},
        if (ruTitle.isNotEmpty)
          {'token': token, 'title': ruTitle, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '20'},
        if (shortRu.length >= 3 && shortRu != ruTitle)
          {'token': token, 'title': shortRu, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '20'},
        if (enTitle.isNotEmpty)
          {'token': token, 'title_orig': enTitle, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '20'},
        if (shortEn.length >= 3 && shortEn != enTitle)
          {'token': token, 'title_orig': shortEn, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '20'},
      ];

      for (final q in queries) {
        for (final host in const ['kodik-api.com', 'kodikapi.com']) {
          try {
            final uri = Uri.https(host, '/search', q);
            final r = await http
                .post(uri, headers: {'User-Agent': Net.ua, 'Accept': 'application/json'})
                .timeout(const Duration(seconds: 4));
            if (r.statusCode == 200) {
              _parseKodikResults(jsonDecode(utf8.decode(r.bodyBytes)), seen, results);
            } else {
              final rGet = await http
                  .get(uri, headers: {'User-Agent': Net.ua, 'Accept': 'application/json'})
                  .timeout(const Duration(seconds: 4));
              if (rGet.statusCode == 200) {
                _parseKodikResults(jsonDecode(utf8.decode(rGet.bodyBytes)), seen, results);
              }
            }
            if (results.isNotEmpty) {
              if (dramaId != null) _dramaCache[dramaId] = results;
              return results;
            }
          } catch (_) {}
        }
      }
    }

    // Резервный поиск iframe-плеера на doramy.club (если домен kodikapi заблокирован у оператора)
    if (results.isEmpty && ruTitle.isNotEmpty) {
      try {
        final searchUri = Uri.parse('https://doramy.club/?s=${Uri.encodeComponent(ruTitle)}');
        final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final pageMatch = RegExp(r'href=["\x27](https?://doramy\.club/\d+-[^"\x27]+\.html)["\x27]').firstMatch(r.body);
          if (pageMatch != null) {
            final pageUrl = pageMatch.group(1)!;
            final pr = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 5));
            if (pr.statusCode == 200) {
              for (final m in RegExp(r'<iframe[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(pr.body)) {
                var u = (m.group(1) ?? '').trim();
                if (u.startsWith('//')) u = 'https:$u';
                if (u.startsWith('http') && !u.contains('vkvideo.ru') && !u.contains('vk.com/video') && seen.add(u)) {
                  results.add({
                    'url': u,
                    'embed': u,
                    'dub': _normalizeStudio(pr.body),
                    'episodes': <String, String>{},
                    'source': 'doramy.club',
                  });
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (dramaId != null && results.isNotEmpty) {
      _dramaCache[dramaId] = results;
    }
    return results;
  }

  // Получить ВСЕ доступные озвучки для дорамы (для UI)
  static List<String> getAvailableDubs(List<Map<String, dynamic>> entries) {
    final out = <String>[];
    for (final s in entries) {
      final dub = (s['dub'] ?? '').toString().trim();
      if (dub.isNotEmpty && !out.contains(dub)) out.add(dub);
    }
    if (out.isEmpty) {
      for (final st in kDubStudios.take(6)) {
        if (!out.contains(st)) out.add(st);
      }
    }
    return out;
  }

  // Получить URL для КОНКРЕТНОЙ серии и КОНКРЕТНОЙ озвучки
  // Возвращает null если этой озвучки НЕТ (не переключает автоматически!)
  static String? getExactStreamUrl({
    required List<Map<String, dynamic>> entries,
    required int episode,
    required String dub,
  }) {
    if (entries.isEmpty) return null;
    final target = dub.trim().toLowerCase().replaceAll('ё', 'е');

    // Ищем ТОЧНО совпадающую озвучку
    final exact = entries.where((s) {
      final sDub = (s['dub'] ?? '').toString().trim().toLowerCase().replaceAll('ё', 'е');
      if (sDub == target) return true;
      if (sDub.contains(target) || target.contains(sDub)) return true;
      return false;
    }).toList();

    // Если выбранной озвучки нет в списке найденных потоков — возвращаем null (НЕ переключаем молча!)
    if (exact.isEmpty) return null;

    for (final item in exact) {
      // Сначала ищем прямую ссылку на конкретную серию
      final eps = item['episodes'];
      if (eps is Map) {
        final epUrl = (eps[episode.toString()] ?? '').toString().trim();
        if (epUrl.isNotEmpty) return epUrl;
      }
      // Потом используем embed-ссылку с параметрами серии
      final base = (item['embed'] ?? item['url'] ?? '').toString().trim();
      if (base.isNotEmpty && base.contains('kodik')) {
        final sep = base.contains('?') ? '&' : '?';
        return '$base${sep}season=1&episode=$episode';
      }
      if (base.isNotEmpty) return base;
    }

    return null;
  }
}

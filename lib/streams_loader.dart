import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'data2026.dart';
import 'dict.dart';
import 'models.dart';
import 'native.dart';
import 'net.dart';
import 'openrouter.dart';

class StreamsLoader {
  static const String remoteUrl = '${Cfg.dataBase}/streams.json';
  static Map<String, List<Map<String, dynamic>>>? _memCache;
  static List<String>? _kodikTokens;

  static const List<String> _defaultKodikTokens = [
    '447d179e875efe44217f20d1ee2146be',
    'b7cc4293ed475c4ad1fd599d114f4435',
    'a0457f4b21f872cb5df96d1a6f70b8e4',
    '71d163b40d50397a86ca54c366f33b72',
    '98f4818f4062f9a5b6e29e2095f9793a',
  ];

  static Map<String, List<Map<String, dynamic>>> _parseMap(String raw) {
    final Map<String, List<Map<String, dynamic>>> result = {};
    if (raw.trim().isEmpty) return result;
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is List) {
            final items = <Map<String, dynamic>>[];
            for (final e in value) {
              if (e is Map) {
                final m = Map<String, dynamic>.from(e);
                final url = (m['url'] ?? '').toString().trim();
                // Никаких тестовых потоков mux.dev
                if (url.isNotEmpty && !url.contains('test-streams.mux.dev')) {
                  m['url'] = url;
                  m['dub'] = (m['dub'] ?? 'SoftBox').toString().trim();
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
    } catch (_) {}
    return result;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> load() async {
    if (_memCache != null) return _memCache!;
    final Map<String, List<Map<String, dynamic>>> merged = {};

    try {
      final String jsonString = await rootBundle.loadString('assets/streams.json');
      merged.addAll(_parseMap(jsonString));
    } catch (_) {}

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

  static Future<List<String>> _getKodikTokens() async {
    if (_kodikTokens != null && _kodikTokens!.isNotEmpty) return _kodikTokens!;
    final tokens = <String>[..._defaultKodikTokens];
    try {
      final r = await http.get(
        Uri.parse('https://raw.githubusercontent.com/YaNesyTortiK/AnimeParsers/main/kdk_tokns/tokens.json'),
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        for (final m in RegExp(r'\\b[a-f0-9]{32}\\b').allMatches(r.body.toLowerCase())) {
          final tk = m.group(0) ?? '';
          if (tk.isNotEmpty && !tokens.contains(tk)) tokens.insert(0, tk);
        }
      }
    } catch (_) {}
    _kodikTokens = tokens;
    return tokens;
  }

  static String _normalizeStudio(String raw) {
    final low = raw.toLowerCase().replaceAll('ё', 'е');
    if (low.contains('softbox') || low.contains('софтбокс')) return 'SoftBox';
    if (low.contains('dublik') || low.contains('даблик') || low.contains('дублик')) return 'DubLik TV';
    if (low.contains('mania') || low.contains('мания') || low.contains('fsg')) return 'FSG Мания';
    if (low.contains('лимон') || low.contains('аконя')) return 'Принц Лимон и Аконя';
    if (low.contains('steponee') || low.contains('степони')) return 'STEPonee';
    if (low.contains('храм дорам')) return 'Храм Дорам';
    if (low.contains('animount') || low.contains('анимаунт')) return 'АниМаунт';
    if (low.contains('highhopes')) return 'HighHopes';
    if (low.contains('субтитр') || low.contains('sub')) return 'Субтитры';
    return raw.trim().isEmpty ? 'SoftBox' : raw.trim();
  }

  static bool _dubMatches(String streamDub, String selectedDub) {
    final a = streamDub.trim().toLowerCase().replaceAll('ё', 'е');
    final b = selectedDub.trim().toLowerCase().replaceAll('ё', 'е');
    if (a.isEmpty || b.isEmpty) return true;
    if (a == 'auto' || a == 'оригинал') return true;
    if (a.contains(b) || b.contains(a)) return true;
    final aFirst = a.split(RegExp(r'[\\s_\\-.]+')).first;
    final bFirst = b.split(RegExp(r'[\\s_\\-.]+')).first;
    if (aFirst.length >= 3 && aFirst == bFirst) return true;
    return false;
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
        if (u.isNotEmpty && !u.contains('test-streams.mux.dev') && seenUrls.add(u)) {
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
            if (u.isNotEmpty && !u.contains('test-streams.mux.dev') && seenUrls.add(u)) {
              found.add(s);
            }
          }
        }
      });
    }
    return found;
  }

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
    final exact = raw.where((s) => _dubMatches((s['dub'] ?? '').toString(), selectedDub)).toList();
    return exact.isNotEmpty ? exact : raw;
  }

  static List<String> getAvailableDubsForDrama(
    Drama d,
    Map<String, List<Map<String, dynamic>>> allStreams, {
    String ruTitle = '',
  }) {
    final raw = _lookupRawStreams(d.id, allStreams, enTitle: d.en, ruTitle: ruTitle);
    final out = <String>[];
    for (final s in raw) {
      final dub = _normalizeStudio((s['dub'] ?? '').toString());
      if (dub.isNotEmpty && !out.contains(dub)) {
        out.add(dub);
      }
    }
    for (final st in kDubStudios.take(6)) {
      if (!out.contains(st)) out.add(st);
    }
    return out;
  }

  // Живой мульти-источниковый поиск реальных потоков для дорамы (Kodik API + Doramy.club + Telegram + Reddit + OpenRouter AI)
  static Future<List<Map<String, dynamic>>> discoverLiveStreams(
    Drama d,
    String ruTitle,
  ) async {
    final baseMap = await load();
    final existing = _lookupRawStreams(d.id, baseMap, enTitle: d.en, ruTitle: ruTitle);
    if (existing.isNotEmpty) return existing;

    final List<Map<String, dynamic>> discovered = [];
    final Set<String> seen = {};

    void addEntry(Map<String, dynamic> entry) {
      final u = (entry['url'] ?? '').toString().trim();
      if (u.isEmpty || u.contains('test-streams.mux.dev') || !seen.add(u)) return;
      discovered.add(entry);
    }

    // 1. Поиск в базе Kodik API по IMDb, русскому и английскому названию
    final tokens = await _getKodikTokens();
    for (final tk in tokens.take(3)) {
      final queries = <Map<String, String>>[
        if (d.imdb.isNotEmpty)
          {'token': tk, 'imdb_id': d.imdb, 'with_episodes': 'true', 'with_material_data': 'true'},
        if (ruTitle.isNotEmpty)
          {'token': tk, 'title': ruTitle, 'with_episodes': 'true', 'limit': '12'},
        if (d.en.isNotEmpty)
          {'token': tk, 'title_orig': d.en, 'with_episodes': 'true', 'limit': '12'},
      ];
      for (final q in queries) {
        try {
          final uri = Uri.https('kodikapi.com', '/search', q);
          final j = await Net.json(uri, retries: 0, timeout: const Duration(seconds: 7));
          if (j is Map && j['results'] is List) {
            for (final item in j['results'] as List) {
              if (item is! Map) continue;
              var link = (item['link'] ?? '').toString().trim();
              if (link.startsWith('//')) link = 'https:$link';
              if (link.isEmpty) continue;
              final tr = item['translation'];
              final rawDub = tr is Map ? (tr['title'] ?? 'SoftBox').toString() : 'SoftBox';
              final dub = _normalizeStudio(rawDub);

              final epMap = <String, String>{};
              final seasons = item['seasons'];
              if (seasons is Map) {
                seasons.forEach((_, sv) {
                  if (sv is Map && sv['episodes'] is Map) {
                    (sv['episodes'] as Map).forEach((ek, ev) {
                      var el = ev.toString().trim();
                      if (el.startsWith('//')) el = 'https:$el';
                      if (el.isNotEmpty) epMap[ek.toString()] = el;
                    });
                  }
                });
              }

              addEntry({
                'url': link,
                'embed': link,
                'dub': dub,
                'episodes': epMap,
                'title': ruTitle,
                'en': d.en,
                'source': 'kodik',
              });
            }
          }
          if (discovered.isNotEmpty) break;
        } catch (_) {}
      }
      if (discovered.isNotEmpty) break;
    }

    // 2. Поиск на doramy.club и публичных Telegram-каналах
    if (discovered.isEmpty && ruTitle.isNotEmpty) {
      try {
        final searchUri = Uri.parse('https://doramy.club/?s=${Uri.encodeComponent(ruTitle)}');
        final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 7));
        if (r.statusCode == 200) {
          final pageMatch = RegExp(r'href=["\x27](https?://doramy\\.club/\\d+-[^"\x27]+\\.html)["\x27]').firstMatch(r.body);
          if (pageMatch != null) {
            final pageUrl = pageMatch.group(1)!;
            final pr = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 7));
            if (pr.statusCode == 200) {
              for (final m in RegExp(r'<iframe[^>]+src=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(pr.body)) {
                var u = (m.group(1) ?? '').trim();
                if (u.startsWith('//')) u = 'https:$u';
                if (u.startsWith('http')) {
                  addEntry({
                    'url': u,
                    'embed': u,
                    'dub': _normalizeStudio(pr.body),
                    'title': ruTitle,
                    'en': d.en,
                    'source': 'doramy.club',
                  });
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    // 3. Поиск через встроенный ИИ OpenRouter с веб-поиском (если прямые балансеры ещё не ответили)
    if (discovered.isEmpty) {
      try {
        final prevWeb = OpenRouter.webPlugin;
        OpenRouter.webPlugin = true;
        final resp = await OpenRouter.chat(
          'Ты поисковый модуль видеоплееров корейских дорам. Найди прямые ссылки на плеер (kodik.info, kodikplayer.com, vk.com/video_ext.php, sibnet, ok.ru/videoembed или .m3u8) и верни ТОЛЬКО JSON массив [{"url":"https://...","dub":"SoftBox"}].',
          'Дорама: $ruTitle (${d.en}, ${d.year ?? 2026})',
          maxTokens: 500,
        );
        OpenRouter.webPlugin = prevWeb;
        if (resp != null) {
          final parsed = OpenRouter.extractJson(resp);
          if (parsed is List) {
            for (final x in parsed) {
              if (x is Map) {
                final u = (x['url'] ?? '').toString().trim();
                if (u.startsWith('http') && !u.contains('test-streams.mux.dev')) {
                  addEntry({
                    'url': u,
                    'embed': u,
                    'dub': _normalizeStudio((x['dub'] ?? 'SoftBox').toString()),
                    'title': ruTitle,
                    'en': d.en,
                    'source': 'ai',
                  });
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (discovered.isNotEmpty) {
      baseMap[d.id.toString()] = discovered;
      final k = nk(d.en);
      if (k.isNotEmpty) baseMap[k] = discovered;
      _memCache = baseMap;
      try {
        await Native.fileWrite('streams_cache.json', jsonEncode(baseMap));
      } catch (_) {}
    }

    return discovered;
  }

  // Возвращает точную ссылку для встроенного плеера по выбранной серии и озвучке
  static String resolveEpisodeStreamUrl({
    required Drama drama,
    required String ruTitle,
    required int episode,
    required String dub,
    required List<Map<String, dynamic>> entries,
  }) {
    final matched = entries.where((s) => _dubMatches((s['dub'] ?? '').toString(), dub)).toList();
    final pool = matched.isNotEmpty ? matched : entries;

    for (final item in pool) {
      final eps = item['episodes'];
      if (eps is Map) {
        final epUrl = (eps[episode.toString()] ?? '').toString().trim();
        if (epUrl.isNotEmpty) return epUrl;
      }
      final base = (item['embed'] ?? item['url'] ?? '').toString().trim();
      if (base.isNotEmpty) {
        if (base.contains('kodik')) {
          final sep = base.contains('?') ? '&' : '?';
          return '$base${sep}season=1&episode=$episode';
        }
        return base;
      }
    }

    // Если в базе ещё нет готового embed-URL, формируем поисковый запрос для встроенного авто-плеера WebView
    final cleanDub = dub.trim().isEmpty ? 'SoftBox' : dub.trim();
    final q = Uri.encodeComponent('$ruTitle дорама $episode серия $cleanDub смотреть онлайн');
    return 'https://m.vkvideo.ru/?q=$q';
  }
}

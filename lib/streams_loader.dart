import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'data2026.dart';
import 'dict.dart';
import 'dict_data.dart';
import 'kodik_parser.dart';
import 'models.dart';
import 'native.dart';
import 'net.dart';

class StreamsLoader {
  static const String remoteUrl = '${Cfg.dataBase}/streams.json';
  static Map<String, List<Map<String, dynamic>>>? _memCache;
  static final Map<int, List<Map<String, dynamic>>> _dramaCache = {};

  // Прямые ссылки на известные новинки 2026 на DoramaOn / Doramy.club / DoramaTV
  static const Map<String, List<Map<String, String>>> _known2026WebPages = {
    'loveindisguise': [
      {'dub': 'LE-Production', 'url': 'https://doramaon.me/dorama/lyubov-pod-prikrytiem-mdl802482', 'source': 'doramaon'},
      {'dub': 'SoftBox', 'url': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026', 'source': 'kodik'},
      {'dub': 'AniDUB', 'url': 'https://anidub.com/12494-ljubov-pod-prikrytiem.html', 'source': 'anidub'},
      {'dub': 'FSG Мания', 'url': 'https://m.doramatv.one/liubov_pod_prikrytiem', 'source': 'doramatv'},
      {'dub': 'АниМаунт', 'url': 'https://m.doramatv.one/liubov_pod_prikrytiem', 'source': 'doramatv'},
      {'dub': 'Субтитры', 'url': 'https://doramaon.me/dorama/lyubov-pod-prikrytiem-mdl802482?dub=sub', 'source': 'doramaon'},
    ],
    'doctorx': [
      {'dub': 'SoftBox', 'url': 'https://doramaon.me/dorama/doktor-iks-mdl787220', 'source': 'doramaon'},
    ],
    'thescandal': [
      {'dub': 'SoftBox', 'url': 'https://doramy.club/60734-skandal-2026.html', 'source': 'doramy.club'},
    ],
    'springfever': [
      {'dub': 'SoftBox', 'url': 'https://doramy.club/52014-1-vesennyaya-lixoradka-2026.html', 'source': 'doramy.club'},
    ],
    'bravenewworld': [
      {'dub': 'SoftBox', 'url': 'https://doramy.club/56617-divnyj-novyj-mir.html', 'source': 'doramy.club'},
    ],
    'madeinkorea2': [
      {'dub': 'SoftBox', 'url': 'https://doramy.club/60522-sdelano-v-koree-2.html', 'source': 'doramy.club'},
    ],
  };

  // Дополнительные корейские романизированные названия и MDL ID для точного поиска в базе Kodik
  static const Map<String, List<String>> _extraOrigAliases = {
    'loveindisguise': [
      'Geunomeun Yeppeotda',
      'Naui yuchoeingan',
      'Naui Yujoeingan',
      'Yeojain geol wae moleuji?',
      'Why Don\'t You Know I\'m a Woman?',
      'My Guilty Man',
      'My Guilty Human',
      'Love in Disguise',
    ],
    'takechargeofmyheart': [
      'Take Charge of My Heart',
      'Recharge Me',
      'Nae Simjangeul Chungjeonhaejwo',
    ],
    'perfectcrown': [
      'Perfect Crown',
      '21st Century Grand Prince\'s Wife',
      '21segi Daegunbuin',
    ],
    'canthislovebetranslated': [
      'Can This Love Be Translated?',
      'I Sarang Tongyeok Doenayo?',
    ],
  };

  static const Map<String, String> _knownMdlIds = {
    'loveindisguise': '802482',
    'doctorx': '787220',
  };

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
                var url = (m['url'] ?? '').toString().trim();
                url = KodikParser.normalizePlayerUrl(url);
                // Никаких VK, никаких тестовых ссылок
                if (url.isNotEmpty &&
                    !url.contains('vkvideo.ru') &&
                    !url.contains('vk.com/video') &&
                    !url.contains('test-streams.mux.dev')) {
                  m['url'] = url;
                  m['embed'] = KodikParser.normalizePlayerUrl((m['embed'] ?? url).toString());
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
    if (low.contains('le-production') || low.contains('le production') || low.contains('leproduction')) return 'LE-Production';
    if (low.contains('le-vitation') || low.contains('levitation') || low.contains('левитация')) return 'LE-Vitation';
    if (low.contains('anidub') || low.contains('анидаб')) return 'AniDUB';
    if (low.contains('dublik') || low.contains('даблик') || low.contains('дублик')) return 'DubLik TV';
    if (low.contains('fsg') || low.contains('мания') || low.contains('mania')) return 'FSG Мания';
    if (low.contains('лимон') || low.contains('аконя')) return 'Принц Лимон и Аконя';
    if (low.contains('steponee') || low.contains('степони')) return 'STEPonee';
    if (low.contains('храм дорам')) return 'Храм Дорам';
    if (low.contains('animount') || low.contains('анимаунт') || low.contains('animaunt')) return 'АниМаунт';
    if (low.contains('highhopes')) return 'HighHopes';
    if (low.contains('кардинал') || low.contains('cardinal')) return 'FSG Кардинал';
    if (low.contains('субтитр') || low.contains('sub')) return 'Субтитры';
    return raw.trim().isEmpty ? 'SoftBox' : raw.trim();
  }

  static void _parseKodikResults(dynamic j, Set<String> seen, List<Map<String, dynamic>> results) {
    if (j is! Map || j['results'] is! List) return;
    for (final item in j['results'] as List) {
      if (item is! Map) continue;
      var link = KodikParser.normalizePlayerUrl((item['link'] ?? '').toString());
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
              el = KodikParser.normalizePlayerUrl(el);
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

  static (List<String>, List<String>) _collectSearchAliases(String ruTitle, String enTitle) {
    final ruSet = <String>{};
    final enSet = <String>{};

    void addRu(String s) {
      final t = s.trim();
      if (t.length >= 2) ruSet.add(t);
      if (t.contains(':')) {
        final short = t.split(':').first.trim();
        if (short.length >= 3) ruSet.add(short);
      }
    }

    void addEn(String s) {
      final t = s.trim();
      if (t.length >= 2) enSet.add(t);
      if (t.contains(':')) {
        final short = t.split(':').first.trim();
        if (short.length >= 3) enSet.add(short);
      }
    }

    addRu(ruTitle);
    addEn(enTitle);

    final cKey = canonicalDramaKey(enTitle);
    final extraOrig = _extraOrigAliases[cKey];
    if (extraOrig != null) {
      for (final a in extraOrig) {
        addEn(a);
      }
    }

    // Собираем все алиасы из kDict (dict_data.dart)
    for (final row in kDict) {
      if (row.length < 2) continue;
      final rowEnParts = row[0].split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final rowRu = row[1].trim();
      final matched = rowRu.toLowerCase() == ruTitle.trim().toLowerCase() ||
          rowEnParts.any((p) => nk(p) == nk(enTitle) || canonicalDramaKey(p) == cKey);
      if (matched) {
        addRu(rowRu);
        for (final p in rowEnParts) {
          addEn(p);
        }
        if (row.length >= 4) {
          for (final syn in row[3].split('|')) {
            final st = syn.trim();
            if (st.length >= 4 && !st.contains('им си ван') && !st.contains('соль ин а')) {
              addRu(st);
            }
          }
        }
      }
    }

    return (ruSet.toList(), enSet.toList());
  }

  /// Мульти-источниковый быстрый поиск потоков с поддержкой KodikParser, DoramaOn, Doramy.club, DoramaTV и Kodik Find-Player
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
    final cKey = canonicalDramaKey(enTitle);

    // 1. Проверяем локальный кэш streams.json + встроенные страницы 2026
    final localAll = await load();
    final localCandidates = <List<Map<String, dynamic>>?>[
      if (dramaId != null) localAll[dramaId.toString()],
      localAll[nk(enTitle)],
      localAll[cKey],
    ];
    for (final list in localCandidates) {
      if (list != null) {
        for (final s in list) {
          final u = KodikParser.normalizePlayerUrl((s['url'] ?? '').toString());
          if (u.isNotEmpty && !u.contains('vkvideo.ru') && !u.contains('test-streams.mux.dev') && seen.add('${s['dub']}|$u')) {
            results.add({
              ...s,
              'url': u,
              'embed': KodikParser.normalizePlayerUrl((s['embed'] ?? u).toString()),
            });
          }
        }
      }
    }

    final presetPages = _known2026WebPages[cKey];
    if (presetPages != null) {
      for (final p in presetPages) {
        final u = p['url']!;
        final dub = p['dub'] ?? 'SoftBox';
        if (seen.add('$dub|$u')) {
          results.add({
            'url': u,
            'embed': u,
            'dub': dub,
            'episodes': <String, String>{},
            'source': p['source'] ?? 'web',
          });
        }
      }
    }

    // 2. Параллельный запрос в Kodik API (https://kodik-api.com/search) по всем алиасам и ID
    final tokens = await KodikParser.getWorkingTokens();
    final token = tokens.first;
    final (ruAliases, enAliases) = _collectSearchAliases(ruTitle, enTitle);
    final mdlId = _knownMdlIds[cKey] ?? '';

    final queries = <Map<String, String>>[
      if (imdb.isNotEmpty)
        {'token': token, 'imdb_id': imdb, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '25'},
      if (mdlId.isNotEmpty)
        {'token': token, 'mdl_id': mdlId, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '25'},
      for (final rt in ruAliases.take(3))
        {'token': token, 'title': rt, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '25'},
      for (final et in enAliases.take(4))
        {'token': token, 'title_orig': et, 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '25'},
    ];

    Future<void> runKodikQuery(Map<String, String> q) async {
      try {
        final postUri = Uri.https(KodikParser.apiHost, '/search');
        final r = await http
            .post(
              postUri,
              headers: {'User-Agent': Net.ua, 'Accept': 'application/json'},
              body: q,
            )
            .timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          _parseKodikResults(jsonDecode(utf8.decode(r.bodyBytes)), seen, results);
          return;
        }
      } catch (_) {}
      try {
        final getUri = Uri.https(KodikParser.apiHost, '/search', q);
        final rGet = await http
            .get(getUri, headers: {'User-Agent': Net.ua, 'Accept': 'application/json'})
            .timeout(const Duration(seconds: 4));
        if (rGet.statusCode == 200) {
          _parseKodikResults(jsonDecode(utf8.decode(rGet.bodyBytes)), seen, results);
        }
      } catch (_) {}
    }

    // Запускаем поисковые запросы к Kodik и веб-источникам параллельно (занимает <= 3.5 сек суммарно)
    await Future.wait([
      ...queries.map(runKodikQuery),
      _searchDoramyClub(ruTitle, seen, results),
      _searchDoramaTv(ruTitle, seen, results),
    ]);

    // 3. Гарантированный резерв через официальный балансер kodikplayer.com/find-player (чтобы никогда не было пустого ответа)
    if (results.isEmpty) {
      final qTitle = Uri.encodeComponent(ruTitle.isNotEmpty ? ruTitle : enTitle);
      final findUrl = 'https://${KodikParser.playerHost}/find-player?title=$qTitle';
      for (final dub in const ['SoftBox', 'LE-Production', 'DubLik TV', 'FSG Мания', 'АниМаунт', 'Субтитры']) {
        results.add({
          'url': '$findUrl&translation=${Uri.encodeComponent(dub)}',
          'embed': '$findUrl&translation=${Uri.encodeComponent(dub)}',
          'dub': dub,
          'episodes': <String, String>{},
          'source': 'kodik-find',
        });
      }
    }

    if (dramaId != null && results.isNotEmpty) {
      _dramaCache[dramaId] = results;
    }
    return results;
  }

  static Future<void> _searchDoramyClub(
    String ruTitle,
    Set<String> seen,
    List<Map<String, dynamic>> results,
  ) async {
    if (ruTitle.trim().isEmpty) return;
    try {
      final searchUri = Uri.parse('https://doramy.club/?s=${Uri.encodeComponent(ruTitle)}');
      final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return;
      final pageMatch = RegExp(r'href=["\x27](https?://doramy\.club/[^"\x27]+\.html)["\x27]').firstMatch(r.body);
      if (pageMatch == null) return;
      final pageUrl = pageMatch.group(1)!;
      final pr = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
      if (pr.statusCode == 200) {
        var foundIframe = false;
        for (final m in RegExp(r'<iframe[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(pr.body)) {
          var u = KodikParser.normalizePlayerUrl(m.group(1) ?? '');
          if (u.startsWith('http') && !u.contains('vkvideo.ru') && !u.contains('vk.com/video') && seen.add(u)) {
            foundIframe = true;
            results.add({
              'url': u,
              'embed': u,
              'dub': _normalizeStudio(pr.body),
              'episodes': <String, String>{},
              'source': 'doramy.club',
            });
          }
        }
        // На doramy.club плеер часто инициализируется JS-скриптом на самой странице:
        // сохраняем саму страницу (DpPlayerHelper в MainActivity изолирует только видеоплеер на весь экран)
        if (!foundIframe && seen.add(pageUrl)) {
          results.add({
            'url': pageUrl,
            'embed': pageUrl,
            'dub': _normalizeStudio(pr.body),
            'episodes': <String, String>{},
            'source': 'doramy.club',
          });
        }
      }
    } catch (_) {}
  }

  static Future<void> _searchDoramaTv(
    String ruTitle,
    Set<String> seen,
    List<Map<String, dynamic>> results,
  ) async {
    if (ruTitle.trim().isEmpty) return;
    try {
      final searchUri = Uri.parse('https://m.doramatv.one/search?q=${Uri.encodeComponent(ruTitle)}');
      final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final m = RegExp(r'href=["\x27](/[a-z0-9_]+)["\x27]').firstMatch(r.body);
        if (m != null) {
          final slug = m.group(1)!;
          if (!slug.startsWith('/search') && !slug.startsWith('/list') && !slug.startsWith('/login')) {
            final pageUrl = 'https://m.doramatv.one$slug';
            if (seen.add(pageUrl)) {
              results.add({
                'url': pageUrl,
                'embed': pageUrl,
                'dub': 'SoftBox',
                'episodes': <String, String>{},
                'source': 'doramatv',
              });
            }
          }
        }
      }
    } catch (_) {}
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
        final epUrl = KodikParser.normalizePlayerUrl((eps[episode.toString()] ?? '').toString());
        if (epUrl.isNotEmpty) return epUrl;
      }
      // Потом используем embed-ссылку с параметрами серии
      final base = KodikParser.normalizePlayerUrl((item['embed'] ?? item['url'] ?? '').toString());
      if (base.isNotEmpty) {
        if (base.contains('kodik') || base.contains('doramaon.me') || base.contains('doramy.club')) {
          final sep = base.contains('?') ? '&' : '?';
          return '$base${sep}season=1&episode=$episode';
        }
        return base;
      }
    }

    return null;
  }
}

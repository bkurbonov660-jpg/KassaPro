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

  // Доверенные домены встроенных iframe-плееров (по схеме DoramaOn: Kodik, Alloha, VeoVeo, Sibnet)
  static const List<String> trustedIframeHosts = [
    'kodikplayer.com',
    'kodik.info',
    'kodik.biz',
    'kodik.cc',
    'kodik.ac',
    'aniqit.com',
    'alloha.tv',
    'allarknow.online',
    'allohastream.com',
    'newplayjj.com',
    'veoveo.cc',
    'veoveo.tv',
    'veoplayer.com',
    'vibix.org',
    'video.sibnet.ru',
    'ok.ru/videoembed',
    'vk.com/video_ext.php',
  ];

  // Сторонние сайты, страницы которых НЕЛЬЗЯ открывать напрямую вместо встроенного плеера
  static const List<String> _thirdPartyPageHosts = [
    'doramaon.me',
    'doramy.club',
    'doramatv.one',
    'doramatv.live',
    'anidub.com',
    'dorama.land',
  ];

  /// Проверяет, является ли ссылка чистым встраиваемым iframe-плеером (а не страницей чужого сайта)
  static bool isTrustedIframeUrl(String rawUrl) {
    final u = rawUrl.trim().toLowerCase();
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    for (final bad in _thirdPartyPageHosts) {
      if (u.contains(bad)) return false;
    }
    for (final host in trustedIframeHosts) {
      if (u.contains(host)) return true;
    }
    return false;
  }

  /// Преобразует любую ссылку (включая старые ссылки из кэша на doramaon/doramy.club) в чистый iframe-плеер Kodik
  static String ensureCleanIframeUrl(String rawUrl, {required String title, String? dub, int? year}) {
    var u = KodikParser.normalizePlayerUrl(rawUrl);
    if (isTrustedIframeUrl(u)) return u;
    final cleanTitle = Uri.encodeComponent(title.trim().isNotEmpty ? title.trim() : 'Дорама');
    final dubParam = (dub != null && dub.trim().isNotEmpty)
        ? '&translation=${Uri.encodeComponent(dub.trim())}'
        : '';
    final yearParam = (year != null && year > 1990) ? '&year=$year' : '';
    return 'https://${KodikParser.playerHost}/find-player?title=$cleanTitle$yearParam$dubParam';
  }

  // Встроенные чистые iframe-ссылки для ключевых новинок 2026 года (никаких внешних веб-страниц)
  static const Map<String, List<Map<String, String>>> _known2026Embeds = {
    'loveindisguise': [
      {'dub': 'LE-Production', 'embed': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026&translation=LE-Production', 'source': 'kodik-iframe'},
      {'dub': 'SoftBox', 'embed': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026&translation=SoftBox', 'source': 'kodik-iframe'},
      {'dub': 'FSG Мания', 'embed': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026&translation=FSG%20%D0%9C%D0%B0%D0%BD%D0%B8%D1%8F', 'source': 'kodik-iframe'},
      {'dub': 'АниМаунт', 'embed': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026&translation=%D0%90%D0%BD%D0%B8%D0%9C%D0%B0%D1%83%D0%BD%D1%82', 'source': 'kodik-iframe'},
      {'dub': 'Субтитры', 'embed': 'https://kodikplayer.com/find-player?title=%D0%9B%D1%8E%D0%B1%D0%BE%D0%B2%D1%8C%20%D0%BF%D0%BE%D0%B4%20%D0%BF%D1%80%D0%B8%D0%BA%D1%80%D1%8B%D1%82%D0%B8%D0%B5%D0%BC&year=2026&translation=%D0%A1%D1%83%D0%B1%D1%82%D0%B8%D1%82%D1%80%D1%8B', 'source': 'kodik-iframe'},
    ],
    'doctorx': [
      {'dub': 'SoftBox', 'embed': 'https://kodikplayer.com/find-player?title=%D0%94%D0%BE%D0%BA%D1%82%D0%BE%D1%80%20%D0%98%D0%BA%D1%81&year=2026&translation=SoftBox', 'source': 'kodik-iframe'},
      {'dub': 'DubLik TV', 'embed': 'https://kodikplayer.com/find-player?title=%D0%94%D0%BE%D0%BA%D1%82%D0%BE%D1%80%20%D0%98%D0%BA%D1%81&year=2026&translation=DubLik%20TV', 'source': 'kodik-iframe'},
    ],
    'thescandal': [
      {'dub': 'SoftBox', 'embed': 'https://kodikplayer.com/find-player?title=%D0%A1%D0%BA%D0%B0%D0%BD%D0%B4%D0%B0%D0%BB&year=2026&translation=SoftBox', 'source': 'kodik-iframe'},
    ],
    'springfever': [
      {'dub': 'SoftBox', 'embed': 'https://kodikplayer.com/find-player?title=%D0%92%D0%B5%D1%81%D0%B5%D0%BD%D0%BD%D1%8F%D1%8F%20%D0%BB%D0%B8%D1%85%D0%BE%D1%80%D0%B0%D0%B4%D0%BA%D0%B0&year=2026&translation=SoftBox', 'source': 'kodik-iframe'},
    ],
    'madeinkorea2': [
      {'dub': 'SoftBox', 'embed': 'https://kodikplayer.com/find-player?title=%D0%A1%D0%B4%D0%B5%D0%BB%D0%B0%D0%BD%D0%BE%20%D0%B2%20%D0%9A%D0%BE%D1%80%D0%B5%D0%B5%202&year=2026&translation=SoftBox', 'source': 'kodik-iframe'},
    ],
  };

  static const Map<String, List<String>> _extraOrigAliases = {
    'loveindisguise': [
      'Geunomeun Yeppeotda',
      'Naui yuchoeingan',
      'Naui Yujoeingan',
      'Yeojain geol wae moleuji?',
      "Why Don't You Know I'm a Woman?",
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
      "21st Century Grand Prince's Wife",
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
                final dub = _normalizeStudio((m['dub'] ?? 'SoftBox').toString());
                var rawEmbed = (m['embed'] ?? m['url'] ?? '').toString().trim();
                rawEmbed = KodikParser.normalizePlayerUrl(rawEmbed);
                // Отфильтровываем ссылки на чужие сайты (оставляем только чистые iframe-плееры и потоки)
                if (rawEmbed.isNotEmpty && isTrustedIframeUrl(rawEmbed)) {
                  m['embed'] = rawEmbed;
                  m['url'] = KodikParser.normalizePlayerUrl((m['url'] ?? rawEmbed).toString());
                  m['dub'] = dub;
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
        'embed': link,
        'url': link,
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

  /// Поиск встроенных iframe-плееров по схеме DoramaOn (Kodik API + извлечение чистых iframe провайдеров Kodik/Alloha/VeoVeo)
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

    // 1. Сначала запускаем параллельный поиск в Kodik API по IMDb, MDL ID, русским и английским алиасам
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

    await Future.wait([
      ...queries.map(runKodikQuery),
      _extractIframeFromDoramyClub(ruTitle, seen, results),
    ]);

    // 2. Добавляем проверенные iframe-плееры из локального кэша (только если это чистый iframe, а не чужой сайт)
    final localAll = await load();
    final localCandidates = <List<Map<String, dynamic>>?>[
      if (dramaId != null) localAll[dramaId.toString()],
      localAll[nk(enTitle)],
      localAll[cKey],
    ];
    for (final list in localCandidates) {
      if (list != null) {
        for (final s in list) {
          final emb = KodikParser.normalizePlayerUrl((s['embed'] ?? s['url'] ?? '').toString());
          if (emb.isNotEmpty && isTrustedIframeUrl(emb) && seen.add('${s['dub']}|$emb')) {
            results.add({
              ...s,
              'embed': emb,
              'url': KodikParser.normalizePlayerUrl((s['url'] ?? emb).toString()),
            });
          }
        }
      }
    }

    // 3. Встроенные чистые iframe-ссылки для новинок 2026
    final presetEmbeds = _known2026Embeds[cKey];
    if (presetEmbeds != null) {
      for (final p in presetEmbeds) {
        final emb = p['embed']!;
        final dub = p['dub'] ?? 'SoftBox';
        if (isTrustedIframeUrl(emb) && seen.add('$dub|$emb')) {
          results.add({
            'embed': emb,
            'url': emb,
            'dub': dub,
            'episodes': <String, String>{},
            'source': p['source'] ?? 'kodik-iframe',
          });
        }
      }
    }

    // 4. Гарантированный резерв через встроенный iframe-балансер kodikplayer.com/find-player
    if (results.isEmpty) {
      final qTitle = Uri.encodeComponent(ruTitle.isNotEmpty ? ruTitle : enTitle);
      final findUrl = 'https://${KodikParser.playerHost}/find-player?title=$qTitle';
      for (final dub in const ['SoftBox', 'LE-Production', 'DubLik TV', 'FSG Мания', 'АниМаунт', 'Субтитры']) {
        final iframeUrl = '$findUrl&translation=${Uri.encodeComponent(dub)}';
        results.add({
          'embed': iframeUrl,
          'url': iframeUrl,
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

  /// Извлекает ТОЛЬКО прямую iframe-ссылку провайдера (Kodik / Alloha / VeoVeo), никогда не сохраняя URL самой веб-страницы
  static Future<void> _extractIframeFromDoramyClub(
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
        for (final m in RegExp(r'<iframe[^>]+(?:src|data-src)=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).allMatches(pr.body)) {
          var u = KodikParser.normalizePlayerUrl(m.group(1) ?? '');
          if (isTrustedIframeUrl(u) && seen.add(u)) {
            results.add({
              'embed': u,
              'url': u,
              'dub': _normalizeStudio(pr.body),
              'episodes': <String, String>{},
              'source': 'iframe-provider',
            });
          }
        }
      }
    } catch (_) {}
  }

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

  /// Получает точный URL для выбранной серии и озвучки по схеме DoramaOn:
  /// ПРИОРИТЕТ 1: Готовая iframe-ссылка провайдера (поле embed или ссылка на серию внутри iframe).
  /// ПРИОРИТЕТ 2: Прямой поток url (только если embed отсутствует).
  static String? getExactStreamUrl({
    required List<Map<String, dynamic>> entries,
    required int episode,
    required String dub,
  }) {
    if (entries.isEmpty) return null;
    final target = dub.trim().toLowerCase().replaceAll('ё', 'е');

    final exact = entries.where((s) {
      final sDub = (s['dub'] ?? '').toString().trim().toLowerCase().replaceAll('ё', 'е');
      if (sDub == target) return true;
      if (sDub.contains(target) || target.contains(sDub)) return true;
      return false;
    }).toList();

    if (exact.isEmpty) return null;

    // 1. Приоритет: готовая iframe-ссылка (посерийная ссылка из сезонов Kodik или поле embed с параметром episode)
    for (final item in exact) {
      final eps = item['episodes'];
      if (eps is Map) {
        final epIframe = KodikParser.normalizePlayerUrl((eps[episode.toString()] ?? '').toString());
        if (epIframe.isNotEmpty && isTrustedIframeUrl(epIframe)) {
          return epIframe;
        }
      }

      final rawEmbed = KodikParser.normalizePlayerUrl((item['embed'] ?? '').toString());
      if (rawEmbed.isNotEmpty && isTrustedIframeUrl(rawEmbed)) {
        if (rawEmbed.contains('episode=')) {
          return rawEmbed.replaceAll(RegExp(r'episode=\d+'), 'episode=$episode');
        }
        final sep = rawEmbed.contains('?') ? '&' : '?';
        return '$rawEmbed${sep}season=1&episode=$episode';
      }
    }

    // 2. Fallback: поле url (если оно ведёт на прямой .m3u8/.mp4 или доверенный плеер)
    for (final item in exact) {
      final rawUrl = KodikParser.normalizePlayerUrl((item['url'] ?? '').toString());
      if (rawUrl.isNotEmpty && (isTrustedIframeUrl(rawUrl) || rawUrl.contains('.m3u8') || rawUrl.contains('.mp4'))) {
        if (isTrustedIframeUrl(rawUrl) && !rawUrl.contains('episode=')) {
          final sep = rawUrl.contains('?') ? '&' : '?';
          return '$rawUrl${sep}season=1&episode=$episode';
        }
        return rawUrl;
      }
    }

    return null;
  }
}

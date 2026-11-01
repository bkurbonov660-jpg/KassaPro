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

  // Приоритет резервных провайдеров при отказе Kodik: 1. Alloha -> 2. VeoVeo -> 3. Sibnet -> 4. VK Video
  static const List<String> fallbackProviderOrder = [
    'alloha',
    'veoveo',
    'sibnet',
    'vk',
  ];

  // Публичные токены балансеров Alloha и VeoVeo
  static const List<String> _allohaTokens = [
    '04941a9a3ca3ac16e2b4327347bbc1',
    '8392a8d8f7e6c5b4a3d2e1f0987654',
    'f1e2d3c4b5a69788796a5b4c3d2e1f',
  ];

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
    'stloadi.live',
    'veoveo.cc',
    'veoveo.tv',
    'veoplayer.com',
    'vibix.org',
    'video.sibnet.ru',
    'sibnet.ru',
    'ok.ru/videoembed',
    'vk.com/video_ext.php',
    'vkvideo.ru/video_ext.php',
  ];

  static const List<String> _thirdPartyPageHosts = [
    'doramaon.me',
    'doramy.club',
    'doramatv.one',
    'doramatv.live',
    'anidub.com',
    'dorama.land',
  ];

  /// Определяет провайдера по URL потока или плеер-ссылки
  static String detectProvider(String rawUrl, [String fallback = 'kodik']) {
    final u = rawUrl.toLowerCase();
    if (u.contains('alloha') || u.contains('allarknow') || u.contains('newplayjj') || u.contains('stloadi')) {
      return 'alloha';
    }
    if (u.contains('veoveo') || u.contains('veoplayer') || u.contains('vibix')) {
      return 'veoveo';
    }
    if (u.contains('sibnet.ru')) {
      return 'sibnet';
    }
    if (u.contains('vk.com/video_ext') || u.contains('vkvideo.ru/video_ext')) {
      return 'vk';
    }
    if (u.contains('kodik') || u.contains('aniqit')) {
      return 'kodik';
    }
    return fallback;
  }

  static String providerLabel(String provider) {
    switch (provider.toLowerCase()) {
      case 'alloha':
        return 'Alloha';
      case 'veoveo':
        return 'VeoVeo';
      case 'sibnet':
        return 'Sibnet';
      case 'vk':
        return 'VK Video';
      default:
        return 'Kodik';
    }
  }

  /// Проверяет, является ли ссылка чистым плеером или прямым видеопотоком
  static bool isTrustedIframeUrl(String rawUrl) {
    final u = rawUrl.trim().toLowerCase();
    if (!u.startsWith('http://') && !u.startsWith('https://')) return false;
    // Прямые поисковые редиректы /find-player часто возвращают «Плеер не найден», поэтому не считаем их готовым потоком
    if (u.contains('/find-player')) return false;
    for (final bad in _thirdPartyPageHosts) {
      if (u.contains(bad)) return false;
    }
    if (u.contains('.m3u8') || u.contains('.mp4')) return true;
    for (final host in trustedIframeHosts) {
      if (u.contains(host)) return true;
    }
    return false;
  }

  static const Map<String, List<String>> _extraOrigAliases = {
    'aloveotherthanyours': [
      'A Love Other Than Yours',
      'Geudae Oeui Sarang',
      'Love Other Than Yours',
      'Любовь, отличная от твоей',
    ],
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
                if (rawEmbed.isNotEmpty && isTrustedIframeUrl(rawEmbed)) {
                  final prov = (m['provider'] ?? detectProvider(rawEmbed)).toString();
                  m['embed'] = rawEmbed;
                  m['url'] = KodikParser.normalizePlayerUrl((m['url'] ?? rawEmbed).toString());
                  m['dub'] = dub;
                  m['provider'] = prov;
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

  static String _normalizeStudio(String raw, {String translationType = ''}) {
    final low = raw.toLowerCase().replaceAll('ё', 'е');
    final tType = translationType.toLowerCase();
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
    if (tType == 'subtitles' || low.contains('субтитр') || low.contains('sub') || low.contains('русские субтитры')) {
      return 'Субтитры';
    }
    return raw.trim().isEmpty ? 'SoftBox' : raw.trim();
  }

  static bool _isSubtitleDub(String dub) {
    final low = dub.trim().toLowerCase().replaceAll('ё', 'е');
    return low.contains('субтитр') || low.contains('sub') || low.contains('fsg');
  }

  static bool _dubMatches(String entryDub, String targetDub) {
    final a = entryDub.trim().toLowerCase().replaceAll('ё', 'е');
    final b = targetDub.trim().toLowerCase().replaceAll('ё', 'е');
    if (a == b || a.contains(b) || b.contains(a)) return true;
    // Страницы с субтитрами часто помечены как FSG Мания / FSG Кардинал / Русские субтитры / Subtitles
    if (_isSubtitleDub(a) && _isSubtitleDub(b)) return true;
    return false;
  }

  static void _parseKodikResults(dynamic j, Set<String> seen, List<Map<String, dynamic>> results) {
    if (j is! Map || j['results'] is! List) return;
    for (final item in j['results'] as List) {
      if (item is! Map) continue;
      var link = KodikParser.normalizePlayerUrl((item['link'] ?? '').toString());
      if (link.isEmpty || !seen.add(link)) continue;

      final tr = item['translation'];
      final rawDub = tr is Map ? (tr['title'] ?? 'SoftBox').toString() : 'SoftBox';
      final rawType = tr is Map ? (tr['type'] ?? '').toString() : '';
      final normDub = _normalizeStudio(rawDub, translationType: rawType);

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
        'dub': normDub,
        'episodes': epMap,
        'provider': 'kodik',
        'source': 'kodik',
      });

      // Если перевод относится к FSG (субтитры), дублируем запись под универсальным ключом «Субтитры»
      if (rawType.toLowerCase() == 'subtitles' && normDub != 'Субтитры' && seen.add('sub|$link')) {
        results.add({
          'embed': link,
          'url': link,
          'dub': 'Субтитры',
          'episodes': epMap,
          'provider': 'kodik',
          'source': 'kodik',
        });
      }
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
        if (hasCyr(a)) {
          addRu(a);
        } else {
          addEn(a);
        }
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

  /// Мульти-провайдерный поиск потоков:
  /// Ищет потоки в Kodik API, Alloha API, VeoVeo API, Sibnet и VK Video (через парсинг страниц озвучек и субтитров),
  /// помечая каждый источник в поле `provider`: 'kodik', 'alloha', 'veoveo', 'sibnet', 'vk'.
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
      // Отдельный запрос специально для релиза с субтитрами (translation_type = subtitles)
      if (ruAliases.isNotEmpty)
        {'token': token, 'title': ruAliases.first, 'translation_type': 'subtitles', 'with_episodes': 'true', 'with_seasons': 'true', 'limit': '15'},
    ];

    Future<void> runKodikQuery(Map<String, String> q) async {
      try {
        final postUri = Uri.https(KodikParser.apiHost, '/search');
        final r = await http
            .post(
              postUri,
              headers: {
                'User-Agent': Net.ua,
                'Accept': 'application/json',
                'Referer': KodikParser.trustedReferer,
              },
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
            .get(
              getUri,
              headers: {
                'User-Agent': Net.ua,
                'Accept': 'application/json',
                'Referer': KodikParser.trustedReferer,
              },
            )
            .timeout(const Duration(seconds: 4));
        if (rGet.statusCode == 200) {
          _parseKodikResults(jsonDecode(utf8.decode(rGet.bodyBytes)), seen, results);
        }
      } catch (_) {}
    }

    // Запускаем параллельный поиск по всем провайдерам: Kodik, Alloha, VeoVeo, Sibnet, VK Video
    await Future.wait([
      ...queries.map(runKodikQuery),
      _searchAllohaProvider(ruTitle: ruTitle, enTitle: enTitle, imdb: imdb, seen: seen, results: results),
      _searchVeoVeoProvider(ruTitle: ruTitle, enTitle: enTitle, imdb: imdb, seen: seen, results: results),
      _extractMultiProvidersFromDoramaSites(ruTitle: ruTitle, enTitle: enTitle, seen: seen, results: results),
    ]);

    // Подгружаем проверенные потоки из локального кэша
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
            final prov = (s['provider'] ?? detectProvider(emb)).toString();
            results.add({
              ...s,
              'embed': emb,
              'url': KodikParser.normalizePlayerUrl((s['url'] ?? emb).toString()),
              'provider': prov,
            });
          }
        }
      }
    }

    if (dramaId != null && results.isNotEmpty) {
      _dramaCache[dramaId] = results;
    }
    return results;
  }

  /// 1. Поиск в балансере Alloha (api.alloha.tv / allohastream.com / allarknow.online)
  static Future<void> _searchAllohaProvider({
    required String ruTitle,
    required String enTitle,
    required String imdb,
    required Set<String> seen,
    required List<Map<String, dynamic>> results,
  }) async {
    for (final tok in _allohaTokens.take(2)) {
      try {
        final params = <String, String>{
          'token': tok,
          if (imdb.isNotEmpty) 'imdb': imdb else 'name': (ruTitle.isNotEmpty ? ruTitle : enTitle),
        };
        final uri = Uri.https('api.alloha.tv', '/', params);
        final r = await http.get(
          uri,
          headers: {'User-Agent': Net.ua, 'Referer': KodikParser.trustedReferer},
        ).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes));
          if (j is Map && j['status'] == 'success' && j['data'] is Map) {
            final data = j['data'] as Map;
            final iframe = (data['iframe'] ?? '').toString().trim();
            if (iframe.isNotEmpty && seen.add('alloha|$iframe')) {
              final trMap = data['translation_iframe'];
              if (trMap is Map && trMap.isNotEmpty) {
                trMap.forEach((_, trVal) {
                  if (trVal is Map) {
                    final trName = _normalizeStudio((trVal['name'] ?? 'SoftBox').toString());
                    final trIframe = (trVal['iframe'] ?? iframe).toString().trim();
                    if (trIframe.isNotEmpty && seen.add('alloha|$trName|$trIframe')) {
                      results.add({
                        'embed': trIframe,
                        'url': trIframe,
                        'dub': trName,
                        'episodes': <String, String>{},
                        'provider': 'alloha',
                        'source': 'alloha',
                      });
                    }
                  }
                });
              } else {
                for (final dub in const ['SoftBox', 'Субтитры', 'LE-Production', 'DubLik TV']) {
                  results.add({
                    'embed': iframe,
                    'url': iframe,
                    'dub': dub,
                    'episodes': <String, String>{},
                    'provider': 'alloha',
                    'source': 'alloha',
                  });
                }
              }
              return;
            }
          }
        }
      } catch (_) {}
    }
  }

  /// 2. Поиск в балансере VeoVeo (veoveo.cc / veoplayer.com / vibix.org)
  static Future<void> _searchVeoVeoProvider({
    required String ruTitle,
    required String enTitle,
    required String imdb,
    required Set<String> seen,
    required List<Map<String, dynamic>> results,
  }) async {
    final q = ruTitle.trim().isNotEmpty ? ruTitle.trim() : enTitle.trim();
    if (q.isEmpty) return;
    try {
      final uri = Uri.parse('https://veoveo.cc/api/videos?title=${Uri.encodeComponent(q)}'
          '${imdb.isNotEmpty ? "&imdb_id=$imdb" : ""}');
      final r = await http.get(
        uri,
        headers: {'User-Agent': Net.ua, 'Referer': KodikParser.trustedReferer, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final list = j is List ? j : (j is Map && j['data'] is List ? j['data'] as List : const []);
        for (final item in list) {
          if (item is! Map) continue;
          final iframe = (item['iframe_url'] ?? item['iframe'] ?? item['embed_url'] ?? '').toString().trim();
          if (iframe.isNotEmpty && seen.add('veoveo|$iframe')) {
            final dub = _normalizeStudio((item['translation'] ?? item['voice'] ?? 'SoftBox').toString());
            results.add({
              'embed': iframe,
              'url': (item['hls'] ?? item['m3u8'] ?? iframe).toString(),
              'dub': dub,
              'episodes': <String, String>{},
              'provider': 'veoveo',
              'source': 'veoveo',
            });
            if (dub != 'Субтитры') {
              results.add({
                'embed': iframe,
                'url': (item['hls'] ?? item['m3u8'] ?? iframe).toString(),
                'dub': 'Субтитры',
                'episodes': <String, String>{},
                'provider': 'veoveo',
                'source': 'veoveo',
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  /// 3 & 4. Извлечение плееров Alloha, VeoVeo, Sibnet (video.sibnet.ru) и VK Video (vk.com/video_ext.php)
  /// со страниц doramy.club и m.doramatv.one (включая отдельные вкладки «Субтитры» и «Озвучка»)
  static Future<void> _extractMultiProvidersFromDoramaSites({
    required String ruTitle,
    required String enTitle,
    required Set<String> seen,
    required List<Map<String, dynamic>> results,
  }) async {
    final queries = <String>{
      if (ruTitle.trim().isNotEmpty) ruTitle.trim(),
      if (enTitle.trim().isNotEmpty) enTitle.trim(),
    }.toList();

    for (final q in queries.take(2)) {
      try {
        final searchUri = Uri.parse('https://doramy.club/?s=${Uri.encodeComponent(q)}');
        final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          final pageMatch = RegExp(r'href=["\x27](https?://doramy\.club/[^"\x27]+\.html)["\x27]').firstMatch(r.body);
          if (pageMatch != null) {
            final pageUrl = pageMatch.group(1)!;
            final pr = await http.get(Uri.parse(pageUrl), headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
            if (pr.statusCode == 200) {
              _extractAllEmbedsFromHtml(pr.body, seen, results);
            }
          }
        }
      } catch (_) {}

      // Дополнительно проверяем m.doramatv.one (часто содержит Sibnet и VK Video с субтитрами)
      try {
        final searchUri = Uri.parse('https://m.doramatv.one/search?q=${Uri.encodeComponent(q)}');
        final r = await http.get(searchUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          final m = RegExp(r'href=["\x27](/[a-z0-9_]+)["\x27]').firstMatch(r.body);
          if (m != null) {
            final slug = m.group(1)!;
            if (!slug.startsWith('/search') && !slug.startsWith('/list') && !slug.startsWith('/login')) {
              final epPageUri = Uri.parse('https://m.doramatv.one$slug/series1');
              final pr = await http.get(epPageUri, headers: {'User-Agent': Net.ua}).timeout(const Duration(seconds: 4));
              if (pr.statusCode == 200) {
                _extractAllEmbedsFromHtml(pr.body, seen, results);
              }
            }
          }
        }
      } catch (_) {}
    }
  }

  static void _extractAllEmbedsFromHtml(
    String html,
    Set<String> seen,
    List<Map<String, dynamic>> results,
  ) {
    final hasSubHint = RegExp(r'субтитр|fsg|subtitles', caseSensitive: false).hasMatch(html);
    final defaultDub = _normalizeStudio(html);

    // 1. Все <iframe src="..."> и data-src="..."
    for (final m in RegExp(r'(?:src|data-src|data-file|data-url)=["\x27]((?:https?:)?//[^"\x27]+)["\x27]', caseSensitive: false).allMatches(html)) {
      var u = KodikParser.normalizePlayerUrl(m.group(1) ?? '');
      if (!isTrustedIframeUrl(u)) continue;
      final prov = detectProvider(u);
      if (seen.add('$prov|$u')) {
        results.add({
          'embed': u,
          'url': u,
          'dub': defaultDub,
          'episodes': <String, String>{},
          'provider': prov,
          'source': prov,
        });
        if (hasSubHint && defaultDub != 'Субтитры' && seen.add('$prov|sub|$u')) {
          results.add({
            'embed': u,
            'url': u,
            'dub': 'Субтитры',
            'episodes': <String, String>{},
            'provider': prov,
            'source': prov,
          });
        }
      }
    }

    // 2. Прямое извлечение Sibnet ID (video.sibnet.ru/shell.php?videoid=...)
    for (final sm in RegExp(r'video\.sibnet\.ru/(?:shell\.php\?videoid=|video)(\d+)', caseSensitive: false).allMatches(html)) {
      final vid = sm.group(1)!;
      final sibUrl = 'https://video.sibnet.ru/shell.php?videoid=$vid';
      if (seen.add('sibnet|$sibUrl')) {
        for (final dub in <String>{defaultDub, 'SoftBox', 'Субтитры'}) {
          results.add({
            'embed': sibUrl,
            'url': sibUrl,
            'dub': dub,
            'episodes': <String, String>{},
            'provider': 'sibnet',
            'source': 'sibnet',
          });
        }
      }
    }

    // 3. Прямое извлечение VK Video (vk.com/video_ext.php?oid=...&id=...)
    for (final vm in RegExp(r'(?:vk\.com|vkvideo\.ru)/video_ext\.php\?oid=(-?\d+)&(?:amp;)?id=(\d+)(?:&(?:amp;)?hash=([a-z0-9_]+))?', caseSensitive: false).allMatches(html)) {
      final oid = vm.group(1)!;
      final id = vm.group(2)!;
      final hash = vm.group(3) ?? '';
      final vkUrl = 'https://vk.com/video_ext.php?oid=$oid&id=$id${hash.isNotEmpty ? "&hash=$hash" : ""}&hd=2';
      if (seen.add('vk|$vkUrl')) {
        for (final dub in <String>{defaultDub, 'SoftBox', 'Субтитры'}) {
          results.add({
            'embed': vkUrl,
            'url': vkUrl,
            'dub': dub,
            'episodes': <String, String>{},
            'provider': 'vk',
            'source': 'vk',
          });
        }
      }
    }
  }

  /// Вызывается, если основной провайдер (Kodik) вернул null или заблокировал поток.
  /// Пробует альтернативные плееры строго в порядке приоритета:
  /// 1. Alloha -> 2. VeoVeo -> 3. Sibnet (прямой .mp4 или shell) -> 4. VK Video (video_ext.php)
  static Future<Map<String, String>?> getFallbackStream({
    required List<Map<String, dynamic>> entries,
    required String ruTitle,
    required String enTitle,
    String imdb = '',
    required int episode,
    required String dub,
    Set<String>? failedProviders,
  }) async {
    final failed = failedProviders ?? const <String>{};

    // Если в текущем списке потоков ещё нет альтернативных провайдеров — догружаем их с сайтов и API
    final seen = <String>{
      for (final e in entries) '${e['provider']}|${e['embed'] ?? e['url']}',
    };
    final hasNonKodik = entries.any((e) {
      final p = (e['provider'] ?? 'kodik').toString();
      return p != 'kodik' && !failed.contains(p);
    });
    if (!hasNonKodik) {
      await Future.wait([
        _searchAllohaProvider(ruTitle: ruTitle, enTitle: enTitle, imdb: imdb, seen: seen, results: entries),
        _searchVeoVeoProvider(ruTitle: ruTitle, enTitle: enTitle, imdb: imdb, seen: seen, results: entries),
        _extractMultiProvidersFromDoramaSites(ruTitle: ruTitle, enTitle: enTitle, seen: seen, results: entries),
      ]);
    }

    // Перебираем провайдеров строго по приоритету: Alloha -> VeoVeo -> Sibnet -> VK Video
    for (final prov in fallbackProviderOrder) {
      if (failed.contains(prov)) continue;

      final provEntries = entries.where((e) {
        final epProv = (e['provider'] ?? detectProvider((e['embed'] ?? e['url'] ?? '').toString())).toString();
        return epProv == prov;
      }).toList();

      // Сначала ищем совпадение по выбранной озвучке/субтитрам, затем любую доступную дорожку у этого провайдера
      final matchedDub = provEntries.where((e) => _dubMatches((e['dub'] ?? '').toString(), dub)).toList();
      final candidates = matchedDub.isNotEmpty ? matchedDub : provEntries;

      for (final item in candidates) {
        var raw = (item['embed'] ?? item['url'] ?? '').toString().trim();
        if (raw.isEmpty) continue;

        final eps = item['episodes'];
        if (eps is Map && eps[episode.toString()] != null) {
          final epSpec = eps[episode.toString()].toString().trim();
          if (epSpec.isNotEmpty) raw = epSpec;
        }

        if (prov == 'sibnet') {
          // Для Sibnet сначала пытаемся достать прямой .mp4 поток
          final directMp4 = await KodikParser.extractSibnetDirectMp4(raw);
          if (directMp4 != null && directMp4.isNotEmpty) {
            return {'url': directMp4, 'provider': 'sibnet'};
          }
          if (isTrustedIframeUrl(raw)) {
            return {'url': raw, 'provider': 'sibnet'};
          }
        } else if (prov == 'alloha' || prov == 'veoveo') {
          final sep = raw.contains('?') ? '&' : '?';
          final withEp = raw.contains('episode=') ? raw.replaceAll(RegExp(r'episode=\d+'), 'episode=$episode') : '$raw${sep}season=1&episode=$episode';
          return {'url': withEp, 'provider': prov};
        } else if (prov == 'vk') {
          return {'url': raw, 'provider': 'vk'};
        }
      }
    }

    // Если в Kodik есть другая дорожка (например, субтитры лежат в отдельном релизе Kodik), пробуем извлечь прямой .m3u8 из неё
    if (!failed.contains('kodik_alt')) {
      for (final item in entries) {
        final raw = (item['embed'] ?? item['url'] ?? '').toString().trim();
        if (raw.contains('kodik')) {
          final direct = await KodikParser.extractDirectStream(raw, episode: episode);
          if (direct != null && direct.isNotEmpty) {
            return {'url': direct, 'provider': 'kodik'};
          }
        }
      }
    }

    return null;
  }

  static List<String> getAvailableDubs(List<Map<String, dynamic>> entries) {
    final out = <String>[];
    for (final s in entries) {
      final dub = (s['dub'] ?? '').toString().trim();
      if (dub.isNotEmpty && !out.contains(dub)) out.add(dub);
    }
    for (final baseDub in const ['SoftBox', 'Субтитры', 'LE-Production', 'DubLik TV', 'FSG Мания']) {
      if (!out.contains(baseDub)) out.add(baseDub);
    }
    return out;
  }

  /// Возвращает ссылку на выбранную серию и озвучку (с учётом субтитров и альтернативных провайдеров)
  static String? getExactStreamUrl({
    required List<Map<String, dynamic>> entries,
    required int episode,
    required String dub,
    String? preferredProvider,
  }) {
    if (entries.isEmpty) return null;

    var pool = entries.where((s) => _dubMatches((s['dub'] ?? '').toString(), dub)).toList();
    if (pool.isEmpty && _isSubtitleDub(dub)) {
      // Субтитры часто лежат в отдельном блоке с пометкой FSG / Sub
      pool = entries.where((s) => _isSubtitleDub((s['dub'] ?? '').toString())).toList();
    }
    if (pool.isEmpty) return null;

    if (preferredProvider != null && preferredProvider.isNotEmpty) {
      final byProv = pool.where((s) => (s['provider'] ?? 'kodik').toString() == preferredProvider).toList();
      if (byProv.isNotEmpty) pool = byProv;
    }

    // 1. Сначала ищем готовый прямой поток (.m3u8 / .mp4)
    for (final item in pool) {
      final rawUrl = KodikParser.normalizePlayerUrl((item['url'] ?? '').toString());
      if (rawUrl.contains('.m3u8') || rawUrl.contains('.mp4')) {
        return rawUrl;
      }
    }

    // 2. Затем ищем посерийную или сериальную ссылку провайдера (не /find-player)
    for (final item in pool) {
      final eps = item['episodes'];
      if (eps is Map) {
        final epLink = KodikParser.normalizePlayerUrl((eps[episode.toString()] ?? '').toString());
        if (epLink.isNotEmpty && isTrustedIframeUrl(epLink)) {
          return epLink;
        }
      }

      final rawEmbed = KodikParser.normalizePlayerUrl((item['embed'] ?? item['url'] ?? '').toString());
      if (rawEmbed.isNotEmpty && isTrustedIframeUrl(rawEmbed)) {
        if (rawEmbed.contains('episode=')) {
          return rawEmbed.replaceAll(RegExp(r'episode=\d+'), 'episode=$episode');
        }
        if (rawEmbed.contains('sibnet.ru') || rawEmbed.contains('vk.com/video_ext')) {
          return rawEmbed;
        }
        final sep = rawEmbed.contains('?') ? '&' : '?';
        return '$rawEmbed${sep}season=1&episode=$episode';
      }
    }

    return null;
  }
}

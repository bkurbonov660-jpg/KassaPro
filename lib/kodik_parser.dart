import 'dart:convert';
import 'package:http/http.dart' as http;
import 'native.dart';
import 'net.dart';

/// Полный парсер прямых потоков Kodik (.m3u8/.mp4) и Sibnet (.mp4) с обходом Referer-блокировки (2026):
/// 1. Подменяет Referer и Origin на доверенные домены (https://doramaon.me/ и https://doramy.club/).
/// 2. Если передана ссылка /find-player, сначала разрешает её через Kodik API в реальный /serial/ или /seria/ URL,
///    чтобы никогда не попадать на заглушку «Плеер не найден».
/// 3. Расшифровывает прямые HLS/MP4 потоки Kodik шифром Цезаря (0..25) + Base64.
/// 4. Извлекает прямые .mp4 потоки из плеер-страниц Sibnet (video.sibnet.ru/shell.php?videoid=...).
class KodikParser {
  static const String apiHost = 'kodik-api.com';
  static const String playerHost = 'kodikplayer.com';
  static const String trustedReferer = 'https://doramaon.me/';
  static const String trustedOrigin = 'https://doramaon.me';

  static const List<String> _seedTokens = [
    '447d179e875efe44217f20d1ee2146be',
    'b7cc4293ed475c4ad1fd599d114f4435',
    'a0457f4b21f872cb5df96d1a6f70b8e4',
    '2f84a5372d2f45c73a8c4d978666a9e0',
    'c237645a9e2b1d70fb123f7fe5772d01',
    '71d163b40d50397a86ca54c366f33b72',
    '98f4818f4062f9a5b6e29e2095f9793a',
  ];

  static String? _cachedToken;
  static String _cachedSerialEndpoint = '/ftor';
  static String _cachedPlayerEndpoint = '/ftor';
  static int _cachedCaesarShift = 18;
  static bool _metaLoaded = false;

  static Future<void> _loadCachedMeta() async {
    if (_metaLoaded) return;
    _metaLoaded = true;
    try {
      final raw = await Native.fileRead('kodik_parser_cache.json');
      if (raw != null && raw.trim().isNotEmpty) {
        final m = jsonDecode(raw);
        if (m is Map) {
          final tok = (m['token'] ?? '').toString().trim();
          final sep = (m['serialEndpoint'] ?? '').toString().trim();
          final pep = (m['playerEndpoint'] ?? '').toString().trim();
          final sh = m['caesarShift'];
          if (tok.length == 32) _cachedToken = tok;
          if (sep.startsWith('/')) _cachedSerialEndpoint = sep;
          if (pep.startsWith('/')) _cachedPlayerEndpoint = pep;
          if (sh is int && sh >= 0 && sh < 26) _cachedCaesarShift = sh;
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveCachedMeta() async {
    try {
      await Native.fileWrite(
        'kodik_parser_cache.json',
        jsonEncode({
          'token': _cachedToken ?? '',
          'serialEndpoint': _cachedSerialEndpoint,
          'playerEndpoint': _cachedPlayerEndpoint,
          'caesarShift': _cachedCaesarShift,
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  static String normalizePlayerUrl(String rawUrl) {
    var u = rawUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('//')) u = 'https:$u';
    u = u.replaceAllMapped(
      RegExp(r'https?://(?:www\.)?(?:kodik\.info|kodik\.biz|kodik\.cc|kodik\.ac|aniqit\.com|kodik\.online)', caseSensitive: false),
      (_) => 'https://$playerHost',
    );
    return u;
  }

  static Future<List<String>> getWorkingTokens() async {
    await _loadCachedMeta();
    final out = <String>[];
    if (_cachedToken != null && _cachedToken!.length == 32) {
      out.add(_cachedToken!);
    }
    for (final t in _seedTokens) {
      if (!out.contains(t)) out.add(t);
    }

    if (_cachedToken == null) {
      try {
        final r = await http
            .get(
              Uri.parse('https://raw.githubusercontent.com/YaNesyTortiK/AnimeParsers/main/kdk_tokns'),
              headers: {'User-Agent': Net.ua},
            )
            .timeout(const Duration(seconds: 3));
        if (r.statusCode == 200) {
          for (final m in RegExp(r'\b([a-f0-9]{32})\b').allMatches(r.body)) {
            final t = m.group(1)!;
            if (!out.contains(t)) out.insert(0, t);
          }
        }
      } catch (_) {}
      if (out.isNotEmpty) {
        _cachedToken = out.first;
        _saveCachedMeta();
      }
    }
    return out;
  }

  static Future<String> discoverVideoInfoEndpoint(String embedHtml, {required bool isSerial}) async {
    await _loadCachedMeta();
    final scriptMatches = RegExp(r'src=["\x27](/assets/js/app\.[a-z0-9_.]+\.js)["\x27]', caseSensitive: false)
        .allMatches(embedHtml)
        .map((m) => m.group(1)!)
        .toList();

    if (scriptMatches.isEmpty) {
      return isSerial ? _cachedSerialEndpoint : _cachedPlayerEndpoint;
    }

    scriptMatches.sort((a, b) {
      int score(String path) {
        if (path.contains('app.serial')) return isSerial ? 3 : 1;
        if (path.contains('app.player')) return isSerial ? 2 : 3;
        return 0;
      }
      return score(b).compareTo(score(a));
    });

    for (final scriptPath in scriptMatches.take(2)) {
      try {
        final jsUri = Uri.parse('https://$playerHost$scriptPath');
        final r = await http.get(
          jsUri,
          headers: {
            'User-Agent': Net.ua,
            'Referer': trustedReferer,
            'Origin': trustedOrigin,
          },
        ).timeout(const Duration(seconds: 4));

        if (r.statusCode == 200) {
          final m = RegExp(r'type\s*:\s*["\x27]POST["\x27]\s*,\s*url\s*:\s*atob\(\s*["\x27]([A-Za-z0-9+/=]+)["\x27]\s*\)')
                  .firstMatch(r.body) ??
              RegExp(r'url\s*:\s*atob\(\s*["\x27]([A-Za-z0-9+/=]+)["\x27]\s*\)').firstMatch(r.body);
          if (m != null) {
            final b64 = m.group(1)!;
            final decoded = utf8.decode(base64Decode(_padBase64(b64))).trim();
            if (decoded.startsWith('/')) {
              if (isSerial) {
                _cachedSerialEndpoint = decoded;
              } else {
                _cachedPlayerEndpoint = decoded;
              }
              _saveCachedMeta();
              return decoded;
            }
          }
        }
      } catch (_) {}
    }

    return isSerial ? _cachedSerialEndpoint : _cachedPlayerEndpoint;
  }

  static String _padBase64(String input) {
    final clean = input.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
    final rem = clean.length % 4;
    if (rem == 0) return clean;
    return clean.padRight(clean.length + (4 - rem), '=');
  }

  static String _caesarShift(String input, int shift) {
    final sb = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 65 && code <= 90) {
        sb.writeCharCode(((code - 65 + shift) % 26) + 65);
      } else if (code >= 97 && code <= 122) {
        sb.writeCharCode(((code - 97 + shift) % 26) + 97);
      } else {
        sb.writeCharCode(code);
      }
    }
    return sb.toString();
  }

  static String? decodeKodikStreamUrl(String rawEncoded) {
    final trimmed = rawEncoded.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';

    final shifts = <int>[
      _cachedCaesarShift,
      for (var s = 0; s < 26; s++)
        if (s != _cachedCaesarShift) s,
    ];

    for (final shift in shifts) {
      try {
        final shifted = _caesarShift(trimmed, shift);
        final padded = _padBase64(shifted);
        final decoded = utf8.decode(base64Decode(padded), allowMalformed: false).trim();
        if (decoded.startsWith('//') || decoded.startsWith('http://') || decoded.startsWith('https://')) {
          if (_cachedCaesarShift != shift) {
            _cachedCaesarShift = shift;
            _saveCachedMeta();
          }
          var out = decoded.startsWith('//') ? 'https:$decoded' : decoded;
          return out;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Если ссылка является поисковым редиректом /find-player, разрешает её через Kodik API в реальную ссылку на сериал/серию
  static Future<String?> _resolveFindPlayerUrl(String findUrl, {int? episode}) async {
    try {
      final uri = Uri.parse(findUrl);
      final title = uri.queryParameters['title'] ?? '';
      if (title.trim().isEmpty) return null;
      final translation = (uri.queryParameters['translation'] ?? '').toLowerCase();
      final tokens = await getWorkingTokens();
      final q = <String, String>{
        'token': tokens.first,
        'title': title,
        'with_episodes': 'true',
        'with_seasons': 'true',
        'limit': '25',
      };
      final r = await http
          .post(Uri.https(apiHost, '/search'), headers: {'User-Agent': Net.ua}, body: q)
          .timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map && j['results'] is List && (j['results'] as List).isNotEmpty) {
          final results = j['results'] as List;
          Map? chosen;
          for (final item in results) {
            if (item is! Map) continue;
            final tr = item['translation'];
            final trTitle = (tr is Map ? (tr['title'] ?? '') : '').toString().toLowerCase();
            final trType = (tr is Map ? (tr['type'] ?? '') : '').toString().toLowerCase();
            if (translation.contains('субтитр') || translation.contains('sub')) {
              if (trType == 'subtitles' || trTitle.contains('субтитр') || trTitle.contains('sub') || trTitle.contains('fsg')) {
                chosen = item;
                break;
              }
            } else if (translation.isNotEmpty && trTitle.contains(translation)) {
              chosen = item;
              break;
            }
          }
          chosen ??= results.first is Map ? results.first as Map : null;
          if (chosen != null) {
            if (episode != null && chosen['seasons'] is Map) {
              for (final sv in (chosen['seasons'] as Map).values) {
                if (sv is Map && sv['episodes'] is Map) {
                  final epRaw = (sv['episodes'] as Map)[episode.toString()];
                  final epLink = epRaw is String
                      ? epRaw
                      : (epRaw is Map ? (epRaw['link'] ?? '').toString() : '');
                  if (epLink.isNotEmpty) return normalizePlayerUrl(epLink);
                }
              }
            }
            final baseLink = normalizePlayerUrl((chosen['link'] ?? '').toString());
            if (baseLink.isNotEmpty) return baseLink;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Извлекает прямую ссылку на поток (.m3u8 или .mp4) из Kodik с подменой Referer на https://doramaon.me/
  /// Возвращает null, если Kodik вернул «Плеер не найден» или заблокировал отдачу.
  static Future<String?> extractDirectStream(String rawEmbedUrl, {int? episode}) async {
    await _loadCachedMeta();
    var embedUrl = normalizePlayerUrl(rawEmbedUrl);
    if (embedUrl.isEmpty) return null;
    if (embedUrl.contains('.m3u8') || embedUrl.contains('.mp4')) return embedUrl;

    // Если ссылка ведёт на Sibnet — парсим прямой .mp4 из Sibnet
    if (embedUrl.contains('sibnet.ru')) {
      return extractSibnetDirectMp4(embedUrl);
    }

    if (!embedUrl.contains(playerHost)) return null;

    // Никогда не открываем /find-player вслепую — сначала разрешаем через API в реальный плеер
    if (embedUrl.contains('/find-player')) {
      final resolved = await _resolveFindPlayerUrl(embedUrl, episode: episode);
      if (resolved == null || resolved.isEmpty) return null;
      embedUrl = resolved;
    }

    if (episode != null && episode > 0 && !embedUrl.contains('episode=')) {
      final sep = embedUrl.contains('?') ? '&' : '?';
      embedUrl = '$embedUrl${sep}season=1&episode=$episode';
    }

    try {
      final pageResp = await http.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent': Net.ua,
          'Referer': trustedReferer,
          'Origin': trustedOrigin,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5));

      if (pageResp.statusCode != 200) return null;
      final html = pageResp.body;

      // Проверяем, не вернул ли Kodik ошибку «Плеер не найден» / «Видео не найдено»
      final lowHtml = html.toLowerCase();
      if (lowHtml.contains('плеер не найден') ||
          lowHtml.contains('видео не найдено') ||
          lowHtml.contains('error-page') ||
          lowHtml.contains('материал заблокирован')) {
        return null;
      }

      final urlParamsMatch = RegExp(r'var\s+urlParams\s*=\s*[\x27"](\{.*?\})[\x27"]\s*;').firstMatch(html);
      Map<String, dynamic> urlParams = {};
      if (urlParamsMatch != null) {
        try {
          final parsed = jsonDecode(urlParamsMatch.group(1)!);
          if (parsed is Map) urlParams = Map<String, dynamic>.from(parsed);
        } catch (_) {}
      }

      var vType = RegExp(r'vInfo\.type\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          RegExp(r'videoInfo\.type\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          '';
      var vHash = RegExp(r'vInfo\.hash\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          RegExp(r'videoInfo\.hash\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          '';
      var vId = RegExp(r'vInfo\.id\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          RegExp(r'videoInfo\.id\s*=\s*[\x27"]([^"\x27]+)[\x27"]').firstMatch(html)?.group(1) ??
          '';

      if (episode != null) {
        final epOpt = RegExp(
          r'<option[^>]*value=["\x27]' + episode.toString() + r'["\x27][^>]*data-id=["\x27]([^"\x27]+)["\x27][^>]*data-hash=["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false,
        ).firstMatch(html) ??
            RegExp(
              r'<option[^>]*data-id=["\x27]([^"\x27]+)["\x27][^>]*data-hash=["\x27]([^"\x27]+)["\x27][^>]*value=["\x27]' +
                  episode.toString() +
                  r'["\x27]',
              caseSensitive: false,
            ).firstMatch(html);
        if (epOpt != null) {
          vId = epOpt.group(1)!;
          vHash = epOpt.group(2)!;
          vType = 'seria';
        }
      }

      if (vType.isEmpty || vHash.isEmpty || vId.isEmpty) {
        final pathMatch = RegExp(r'/(seria|serial|video|movie)/(\d+)/([a-f0-9]{16,64})').firstMatch(embedUrl);
        if (pathMatch != null) {
          vType = pathMatch.group(1)!;
          vId = pathMatch.group(2)!;
          vHash = pathMatch.group(3)!;
        }
      }

      if (vType.isEmpty || vHash.isEmpty || vId.isEmpty) return null;

      final isSerial = embedUrl.contains('/serial/') || embedUrl.contains('/season/');
      final endpoint = await discoverVideoInfoEndpoint(html, isSerial: isSerial);

      final rawRef = (urlParams['ref'] ?? trustedReferer).toString();
      String decodedRef = rawRef;
      try {
        decodedRef = Uri.decodeComponent(rawRef);
      } catch (_) {}

      final postParams = <String, String>{
        'd': (urlParams['d'] ?? 'doramaon.me').toString(),
        'd_sign': (urlParams['d_sign'] ?? '').toString(),
        'pd': (urlParams['pd'] ?? playerHost).toString(),
        'pd_sign': (urlParams['pd_sign'] ?? '').toString(),
        'ref': decodedRef.isEmpty ? trustedReferer : decodedRef,
        'ref_sign': (urlParams['ref_sign'] ?? '').toString(),
        'bad_user': 'true',
        'cdn_is_working': 'true',
        'type': vType,
        'hash': vHash,
        'id': vId,
        'info': '{}',
      };

      final postUri = Uri.parse('https://$playerHost$endpoint');
      final infoResp = await http.post(
        postUri,
        headers: {
          'User-Agent': Net.ua,
          'Origin': 'https://$playerHost',
          'Referer': embedUrl,
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
        },
        body: postParams,
      ).timeout(const Duration(seconds: 5));

      if (infoResp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(infoResp.bodyBytes));
        if (data is Map && data['links'] is Map) {
          final links = data['links'] as Map;
          for (final q in const ['720', '1080', '480', '360']) {
            final qList = links[q];
            if (qList is List && qList.isNotEmpty) {
              final first = qList.first;
              final rawSrc = first is Map ? (first['src'] ?? '').toString() : first.toString();
              final dec = decodeKodikStreamUrl(rawSrc);
              if (dec != null && dec.isNotEmpty) {
                return dec;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Парсит страницу video.sibnet.ru/shell.php?videoid=... и извлекает прямой .mp4 поток
  static Future<String?> extractSibnetDirectMp4(String sibnetUrl) async {
    try {
      var u = sibnetUrl.trim();
      if (u.startsWith('//')) u = 'https:$u';
      final vidMatch = RegExp(r'videoid=(\d+)').firstMatch(u) ?? RegExp(r'video(\d+)').firstMatch(u);
      if (vidMatch != null && !u.contains('shell.php')) {
        u = 'https://video.sibnet.ru/shell.php?videoid=${vidMatch.group(1)}';
      }
      final r = await http.get(
        Uri.parse(u),
        headers: {
          'User-Agent': Net.ua,
          'Referer': 'https://video.sibnet.ru/',
        },
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final m = RegExp(r'src\s*:\s*["\x27](/v/[^"\x27]+\.mp4[^"\x27]*)["\x27]').firstMatch(r.body);
        if (m != null) {
          final mp4Path = m.group(1)!;
          return 'https://video.sibnet.ru$mp4Path';
        }
      }
    } catch (_) {}
    return null;
  }
}

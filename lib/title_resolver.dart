import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secrets.dart';
import 'models.dart';
import 'dict.dart';

class TitleResolver {
  static final Map<String, String> _cache = {};

  static Future<(String?, String?)> resolve(Drama d) async {
    final key = d.imdb.isNotEmpty ? d.imdb : 'name:${d.en}';
    if (_cache.containsKey(key)) {
      final v = _cache[key]!;
      if (v.isEmpty) return (null, null);
      return (v, 'cache');
    }
    if (d.imdb.isNotEmpty && Secrets.kinopoiskApiKey.isNotEmpty) {
      final r = await _kinopoiskByImdb(d.imdb);
      if (r != null) { _cache[key] = r; return (r, 'kinopoisk'); }
    }
    if (Secrets.kinopoiskApiKey.isNotEmpty) {
      final r = await _kinopoiskByName(d.en, d.year);
      if (r != null) { _cache[key] = r; return (r, 'kinopoisk'); }
    }
    _cache[key] = '';
    return (null, null);
  }

  static Future<String?> _kinopoiskByImdb(String imdb) async {
    try {
      final url = Uri.parse('https://api.kinopoisk.dev/v1.4/movie?externalId.imdb=$imdb&limit=1');
      final r = await http.get(url, headers: {
        'X-API-KEY': Secrets.kinopoiskApiKey,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['docs'] is List && (j['docs'] as List).isNotEmpty) {
        final m = (j['docs'] as List)[0];
        final name = (m['name'] ?? '').toString();
        if (name.isNotEmpty && hasCyr(name)) return name;
        final alt = (m['alternativeName'] ?? '').toString();
        if (alt.isNotEmpty && hasCyr(alt)) return alt;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> _kinopoiskByName(String en, int? year) async {
    try {
      final params = <String, String>{'query': en, 'limit': '1', 'type': 'tv-series'};
      if (year != null) params['year'] = '$year';
      final url = Uri.https('api.kinopoisk.dev', '/v1.4/movie/search', params);
      final r = await http.get(url, headers: {
        'X-API-KEY': Secrets.kinopoiskApiKey,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map && j['docs'] is List && (j['docs'] as List).isNotEmpty) {
        final m = (j['docs'] as List)[0];
        final name = (m['name'] ?? '').toString();
        if (name.isNotEmpty && hasCyr(name)) return name;
        final alt = (m['alternativeName'] ?? '').toString();
        if (alt.isNotEmpty && hasCyr(alt)) return alt;
      }
    } catch (_) {}
    return null;
  }
}

import 'dict.dart';
import 'models.dart';
import 'net.dart';

class Tvmaze {
  static const String base = 'https://api.tvmaze.com';
  static const Map<String, String> _countryOk = {
    'KR': 'KR', 'JP': 'JP', 'CN': 'CN', 'TH': 'TH', 'TW': 'TW', 'HK': 'CN',
  };
  static const Map<String, String> _langOk = {
    'Korean': 'KR', 'Japanese': 'JP', 'Chinese': 'CN', 'Mandarin': 'CN', 'Cantonese': 'CN', 'Thai': 'TH',
  };

  static String? originOf(Map s) {
    String? code;
    final n = s['network'];
    final w = s['webChannel'];
    if (n is Map && n['country'] is Map) code = (n['country'] as Map)['code']?.toString();
    if (code == null && w is Map && w['country'] is Map) code = (w['country'] as Map)['code']?.toString();
    if (code != null && _countryOk.containsKey(code)) return _countryOk[code];
    final lang = s['language'];
    if (lang is String && _langOk.containsKey(lang)) return _langOk[lang];
    return null;
  }

  static Drama? parse(dynamic s, {int minYear = 2020}) {
    if (s is! Map) return null;
    if (s['type'] != 'Scripted') return null;
    final o = originOf(s);
    if (o == null) return null;
    final id = s['id'];
    if (id is! int) return null;
    final prem = (s['premiered'] ?? '').toString();
    int? year;
    if (prem.length >= 4) year = int.tryParse(prem.substring(0, 4));
    final status = (s['status'] ?? '').toString();
    if (year != null && (year < minYear || year > 2030)) return null;
    if (year == null && status != 'In Development' && status != 'Running') return null;
    var poster = '';
    final img = s['image'];
    if (img is Map && img['medium'] != null) {
      poster = img['medium'].toString().replaceFirst('http://', 'https://');
    }
    double? rating;
    final rt = s['rating'];
    if (rt is Map && rt['average'] is num) rating = (rt['average'] as num).toDouble();
    var imdb = '';
    final ex = s['externals'];
    if (ex is Map && ex['imdb'] != null) imdb = ex['imdb'].toString();
    var net = '';
    final n = s['network'];
    final w = s['webChannel'];
    if (n is Map && n['name'] != null) {
      net = n['name'].toString();
    } else if (w is Map && w['name'] != null) {
      net = w['name'].toString();
    }
    final g = s['genres'];
    return Drama(
      id: id,
      en: (s['name'] ?? '').toString(),
      year: year,
      date: prem,
      poster: poster,
      rating: rating,
      genres: g is List ? g.map((e) => e.toString()).toList() : <String>[],
      imdb: imdb,
      country: o,
      status: status,
      network: net,
    );
  }

  static Future<Drama?> single(String name, int? year) async {
    final j = await Net.json(Uri.https('api.tvmaze.com', '/singlesearch/shows', {'q': name}), retries: 1);
    final d = parse(j, minYear: 2018);
    if (d == null) return null;
    if (nk(d.en) != nk(name)) return null;
    if (year != null && d.year != null && (d.year! - year).abs() > 1) return null;
    return d;
  }

  static Future<List<Drama>> search(String q) async {
    final j = await Net.json(Uri.https('api.tvmaze.com', '/search/shows', {'q': q}));
    final out = <Drama>[];
    if (j is List) {
      for (final x in j) {
        if (x is Map) {
          final d = parse(x['show'], minYear: 0);
          if (d != null) out.add(d);
        }
      }
    }
    return out;
  }

  static Future<Map<String, dynamic>?> detail(int id) async {
    final j = await Net.json(Uri.parse('$base/shows/$id?embed=nextepisode'));
    if (j is! Map) return null;
    return Map<String, dynamic>.from(j);
  }

  static Future<int?> episodeCount(int id) async {
    final j = await Net.json(Uri.parse('$base/shows/$id/episodes'));
    if (j is List) return j.length;
    return null;
  }

  static String stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

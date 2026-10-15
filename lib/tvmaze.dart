import 'dict.dart';
import 'models.dart';
import 'net.dart';

class Tvmaze {
  static const String base = 'https://api.tvmaze.com';

  static String? originOf(Map s) {
    String? code;
    final n = s['network'];
    final w = s['webChannel'];
    if (n is Map && n['country'] is Map) code = (n['country'] as Map)['code']?.toString();
    if (code == null && w is Map && w['country'] is Map) code = (w['country'] as Map)['code']?.toString();
    if (code == 'KR') return 'KR';
    final lang = s['language'];
    if (lang == 'Korean') return 'KR';
    return null;
  }

  static Drama? parse(dynamic s, {int minYear = 0}) {
    if (s is! Map) return null;
    if (s['type'] != 'Scripted') return null;
    final o = originOf(s);
    if (o != 'KR') return null;
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
    if (n is Map && n['name'] != null) net = n['name'].toString();
    else if (w is Map && w['name'] != null) net = w['name'].toString();
    final g = s['genres'];
    return Drama(
      id: id, en: (s['name'] ?? '').toString(),
      year: year, date: prem, poster: poster, rating: rating,
      genres: g is List ? g.map((e) => e.toString()).toList() : <String>[],
      imdb: imdb, country: 'KR', status: status, network: net,
    );
  }

  static Future<Drama?> single(String name, int? year) async {
    final j = await Net.json(Uri.https('api.tvmaze.com', '/singlesearch/shows', {'q': name}), retries: 1);
    final d = parse(j, minYear: 0);
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

  static Future<Drama?> resolve(String en, int? year, String imdb) async {
    if (imdb.isNotEmpty) {
      final j = await Net.json(Uri.parse('$base/lookup/shows?imdb=$imdb'), retries: 0);
      final d = parse(j, minYear: 0);
      if (d != null) return d;
    }
    if (en.isEmpty) return null;
    final l = await search(en);
    final key = nk(en);
    Drama? best;
    for (final d in l) {
      if (nk(d.en) == key) {
        if (year == null || d.year == null || (d.year! - year).abs() <= 1) return d;
        best ??= d;
      }
    }
    return best;
  }

  static Future<List<Ep>?> episodes(int id) async {
    final j = await Net.json(Uri.parse('$base/shows/$id/episodes'));
    if (j is! List) return null;
    final out = <Ep>[];
    for (final e in j) {
      if (e is! Map) continue;
      final n = e['number'];
      if (n is! int) continue;
      final s = e['season'];
      out.add(Ep(s is int ? s : 1, n, (e['name'] ?? '').toString(),
          (e['airdate'] ?? '').toString(), (e['airtime'] ?? '').toString()));
    }
    return out;
  }

  static Future<List<Actor>> cast(int id) async {
    final j = await Net.json(Uri.parse('$base/shows/$id/cast'));
    final out = <Actor>[];
    final seen = <int>{};
    if (j is List) {
      for (final x in j) {
        if (x is! Map) continue;
        final p = x['person'];
        final c = x['character'];
        if (p is! Map || p['id'] is! int) continue;
        final pid = p['id'] as int;
        if (!seen.add(pid)) continue;
        var photo = '';
        final img = p['image'];
        if (img is Map && img['medium'] != null) {
          photo = img['medium'].toString().replaceFirst('http://', 'https://');
        }
        out.add(Actor(pid, (p['name'] ?? '').toString(),
            c is Map ? (c['name'] ?? '').toString() : '', photo));
        if (out.length >= 24) break;
      }
    }
    return out;
  }

  static Future<List<Drama>> actorShows(int personId) async {
    final j = await Net.json(Uri.parse('$base/people/$personId/castcredits?embed=show'));
    final out = <Drama>[];
    final seen = <int>{};
    if (j is List) {
      for (final x in j) {
        if (x is! Map) continue;
        final e = x['_embedded'];
        if (e is! Map) continue;
        final d = parse(e['show']);
        if (d != null && seen.add(d.id)) out.add(d);
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  static String stripHtml(String s) {
    return s.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"').replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'").replaceAll('&nbsp;', ' ').trim();
  }
}

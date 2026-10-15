import 'dict.dart';
import 'models.dart';
import 'net.dart';

class Wiki {
  static const String _cs = 'wd:Q884';
  static const Map<String, String> cMap = {'Q884': 'KR'};

  static Future<List<dynamic>?> _bindings(String q) async {
    final j = await Net.json(
      Uri.https('query.wikidata.org', '/sparql', {'format': 'json', 'query': q}),
      retries: 1, timeout: const Duration(seconds: 60),
    );
    if (j is Map && j['results'] is Map && (j['results'] as Map)['bindings'] is List) {
      return (j['results'] as Map)['bindings'] as List;
    }
    return null;
  }
  static String _v(dynamic b, String k) {
    if (b is Map) {
      final x = b[k];
      if (x is Map && x['value'] != null) return x['value'].toString();
    }
    return '';
  }
  static String _lit(String s) => '"${s.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"@en';

  static Future<Map<String, String>?> byImdb(List<String> ids) async {
    final vals = ids.map((e) => '"$e"').join(' ');
    final q = 'SELECT ?im ?l WHERE{VALUES ?im{$vals} ?x wdt:P345 ?im. ?x rdfs:label ?l. FILTER(LANG(?l)="ru")}';
    final b = await _bindings(q);
    if (b == null) return null;
    final out = <String, String>{};
    for (final r in b) {
      final im = _v(r, 'im'); final l = _v(r, 'l');
      if (im.isNotEmpty && hasCyr(l)) out[im] = l;
    }
    return out;
  }

  static Future<Map<String, String>?> byEnglish(List<String> names) async {
    final vals = names.map(_lit).join(' ');
    final q = 'SELECT ?en ?l WHERE{VALUES ?en{$vals} ?x rdfs:label ?en. ?x wdt:P495 ?c. VALUES ?c{$_cs} ?x wdt:P31 wd:Q5398426. ?x rdfs:label ?l. FILTER(LANG(?l)="ru")}';
    final b = await _bindings(q);
    if (b == null) return null;
    final out = <String, String>{};
    for (final r in b) {
      final en = _v(r, 'en').toLowerCase(); final l = _v(r, 'l');
      if (en.isNotEmpty && hasCyr(l)) out[en] = l;
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>?> announced(int fromYear, {int limit = 700}) async {
    final q = 'SELECT ?x ?en ?ru ?d ?im ?c WHERE { VALUES ?c { $_cs } VALUES ?t { wd:Q5398426 wd:Q1259759 } '
        '?x wdt:P31 ?t . ?x wdt:P495 ?c . { ?x wdt:P580 ?d } UNION { ?x wdt:P577 ?d } '
        'FILTER(?d >= "$fromYear-01-01T00:00:00Z"^^xsd:dateTime) '
        '?x rdfs:label ?en . FILTER(LANG(?en) = "en") '
        'OPTIONAL { ?x rdfs:label ?ru . FILTER(LANG(?ru) = "ru") } '
        'OPTIONAL { ?x wdt:P345 ?im } } LIMIT $limit';
    final b = await _bindings(q);
    if (b == null) return null;
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final r in b) {
      final xs = _v(r, 'x');
      final qn = int.tryParse(xs.split('/Q').last);
      if (qn == null || seen.contains(qn)) continue;
      seen.add(qn);
      final d = _v(r, 'd');
      out.add({
        'q': qn, 'en': _v(r, 'en'), 'ru': _v(r, 'ru'),
        'date': d.length >= 10 ? d.substring(0, 10) : '',
        'im': _v(r, 'im'), 'c': 'KR',
      });
    }
    return out;
  }

  static Future<List<RuHit>?> searchRu(String q) async {
    final t = q.trim().toLowerCase().replaceAll('\\', ' ').replaceAll('"', ' ');
    if (t.length < 2) return null;
    final sq = 'SELECT ?x ?en ?ru ?im ?d WHERE { ?x wdt:P31 wd:Q5398426 . ?x wdt:P495 $_cs . '
        '?x rdfs:label ?ru . FILTER(LANG(?ru) = "ru" && CONTAINS(LCASE(?ru), "$t")) '
        '?x rdfs:label ?en . FILTER(LANG(?en) = "en") '
        'OPTIONAL { ?x wdt:P345 ?im } OPTIONAL { ?x wdt:P577 ?d } } LIMIT 15';
    final b = await _bindings(sq);
    if (b == null) return null;
    final seen = <String>{};
    final out = <RuHit>[];
    for (final r in b) {
      final en = _v(r, 'en');
      final ru = _v(r, 'ru');
      if (en.isEmpty || !hasCyr(ru) || !seen.add(en)) continue;
      final d = _v(r, 'd');
      out.add(RuHit(ru, en, d.length >= 4 ? int.tryParse(d.substring(0, 4)) : null, _v(r, 'im'), 'wiki'));
    }
    return out;
  }

  static Future<List<Map<String, String>>?> ruSearch(String en) async {
    final j = await Net.json(
      Uri.https('ru.wikipedia.org', '/w/api.php', {
        'action': 'query', 'list': 'search', 'srlimit': '4',
        'format': 'json', 'origin': '*', 'srsearch': '"$en" телесериал',
      }),
      retries: 1,
    );
    if (j == null) return null;
    final out = <Map<String, String>>[];
    if (j is Map && j['query'] is Map && (j['query'] as Map)['search'] is List) {
      for (final x in (j['query'] as Map)['search'] as List) {
        if (x is Map) {
          out.add({
            't': (x['title'] ?? '').toString(),
            's': (x['snippet'] ?? '').toString()
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll('&quot;', '"').replaceAll('&amp;', '&'),
          });
        }
      }
    }
    return out;
  }

  static String? pick(String en, List<Map<String, String>> r) {
    final key = nk(en);
    for (final x in r) {
      final t = x['t'] ?? ''; final s = x['s'] ?? '';
      if (t.startsWith('Список') || !hasCyr(t)) continue;
      if (!RegExp(r'сериал|дорам', caseSensitive: false).hasMatch(s)) continue;
      if (!RegExp(r'корей', caseSensitive: false).hasMatch(s + t)) continue;
      if (key.isNotEmpty && !nk(s).contains(key)) continue;
      return t.replaceAll(RegExp(r'\s*\(.*\)$'), '');
    }
    return null;
  }
}

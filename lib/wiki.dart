import 'dict.dart';
import 'net.dart';

class Wiki {
  static const String _cs = 'wd:Q884 wd:Q17 wd:Q148 wd:Q869 wd:Q865';
  static const Map<String, String> cMap = {
    'Q884': 'KR', 'Q17': 'JP', 'Q148': 'CN', 'Q869': 'TH', 'Q865': 'TW',
  };

  static Future<List<dynamic>?> _bindings(String q) async {
    final j = await Net.json(
      Uri.https('query.wikidata.org', '/sparql', {'format': 'json', 'query': q}),
      retries: 1,
      timeout: const Duration(seconds: 60),
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
      final im = _v(r, 'im');
      final l = _v(r, 'l');
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
      final en = _v(r, 'en').toLowerCase();
      final l = _v(r, 'l');
      if (en.isNotEmpty && hasCyr(l)) out[en] = l;
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>?> announced(int fromYear) async {
    final q = 'SELECT ?x ?en ?ru ?d ?im ?c WHERE { VALUES ?c { $_cs } VALUES ?t { wd:Q5398426 wd:Q1259759 } '
        '?x wdt:P31 ?t . ?x wdt:P495 ?c . { ?x wdt:P580 ?d } UNION { ?x wdt:P577 ?d } '
        'FILTER(?d >= "$fromYear-01-01T00:00:00Z"^^xsd:dateTime) '
        '?x rdfs:label ?en . FILTER(LANG(?en) = "en") '
        'OPTIONAL { ?x rdfs:label ?ru . FILTER(LANG(?ru) = "ru") } '
        'OPTIONAL { ?x wdt:P345 ?im } } LIMIT 700';
    final b = await _bindings(q);
    if (b == null) return null;
    final seen = <int>{};
    final out = <Map<String, dynamic>>[];
    for (final r in b) {
      final xs = _v(r, 'x');
      final qn = int.tryParse(xs.split('/Q').last);
      if (qn == null || seen.contains(qn)) continue;
      seen.add(qn);
      final cs = _v(r, 'c').split('/').last;
      final d = _v(r, 'd');
      out.add({
        'q': qn,
        'en': _v(r, 'en'),
        'ru': _v(r, 'ru'),
        'date': d.length >= 10 ? d.substring(0, 10) : '',
        'im': _v(r, 'im'),
        'c': cMap[cs] ?? '',
      });
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
            's': (x['snippet'] ?? '')
                .toString()
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll('&quot;', '"')
                .replaceAll('&amp;', '&'),
          });
        }
      }
    }
    return out;
  }

  static String? pick(String en, List<Map<String, String>> r) {
    final key = nk(en);
    for (final x in r) {
      final t = x['t'] ?? '';
      final s = x['s'] ?? '';
      if (t.startsWith('Список') || !hasCyr(t)) continue;
      if (!RegExp(r'сериал|дорам', caseSensitive: false).hasMatch(s)) continue;
      if (!RegExp(r'корей|япон|китай|тайск|тайван', caseSensitive: false).hasMatch(s + t)) continue;
      if (key.isNotEmpty && !nk(s).contains(key)) continue;
      return t.replaceAll(RegExp(r'\s*\(.*\)$'), '');
    }
    return null;
  }
}

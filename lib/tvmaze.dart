import 'models.dart';
import 'net.dart';

class Tvmaze {
  static const String base = 'https://api.tvmaze.com';
  static String? originOf(Map s) => null;
  static Drama? parse(dynamic s, {int minYear = 0, bool forceKR = false}) => null;
  static Future<Drama?> single(String name, int? year) async => null;
  static Future<List<Drama>> search(String q) async => <Drama>[];
  static Future<Map<String, dynamic>?> detail(int id) async => null;
  static Future<int?> episodeCount(int id) async => null;
  static Future<Map<String, dynamic>?> showByImdb(String imdb) async => null;
  static Future<Drama?> resolve(String en, int? year, String imdb) async => null;
  static Future<List<Ep>?> episodes(int id) async => null;
  static Future<List<Actor>> cast(int id) async => <Actor>[];
  static Future<List<Drama>> actorShows(int personId) async => <Drama>[];

  // Автоматический поиск свежего фото (Википедия / Wikimedia Commons — высокий приоритет для свежих фото).
  static Future<String> wikiPageImage(String title, {String lang = 'en'}) async {
    final q = title.trim();
    if (q.isEmpty) return '';
    try {
      final u1 = Uri.parse(
        'https://$lang.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(q)}&prop=pageimages&format=json&pithumbsize=600&redirects=1',
      );
      final j1 = await Net.json(u1, retries: 1, timeout: const Duration(seconds: 12));
      final img1 = _extractWikiThumb(j1);
      if (img1.isNotEmpty) return img1;

      final u2 = Uri.parse(
        'https://$lang.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent(q)}&gsrlimit=1&prop=pageimages&format=json&pithumbsize=600',
      );
      final j2 = await Net.json(u2, retries: 1, timeout: const Duration(seconds: 12));
      return _extractWikiThumb(j2);
    } catch (_) {
      return '';
    }
  }

  static String _extractWikiThumb(dynamic j) {
    try {
      if (j is! Map) return '';
      final q = j['query'];
      if (q is! Map) return '';
      final pages = q['pages'];
      if (pages is! Map) return '';
      for (final p in pages.values) {
        if (p is Map && p['thumbnail'] is Map) {
          final src = (p['thumbnail']['source'] ?? '').toString().trim();
          if (src.isNotEmpty) return src;
        }
      }
    } catch (_) {}
    return '';
  }

  // Поиск свежего постера для дорамы (TVmaze + Wikipedia EN/RU, без API-ключей).
  static Future<String> findPoster(String en, {String ru = ''}) async {
    final q = en.trim();
    if (q.isNotEmpty) {
      try {
        final u = Uri.parse('$base/singlesearch/shows?q=${Uri.encodeComponent(q)}');
        final j = await Net.json(u, retries: 1, timeout: const Duration(seconds: 12));
        if (j is Map && j['image'] is Map) {
          final img = j['image'] as Map;
          final url = (img['original'] ?? img['medium'] ?? '').toString().trim();
          if (url.isNotEmpty) return url.replaceFirst('http://', 'https://');
        }
      } catch (_) {}
      final wEn = await wikiPageImage('$q (South Korean TV series)', lang: 'en');
      if (wEn.isNotEmpty) return wEn;
      final wEn2 = await wikiPageImage(q, lang: 'en');
      if (wEn2.isNotEmpty) return wEn2;
    }
    if (ru.trim().isNotEmpty) {
      final wRu = await wikiPageImage(ru.trim(), lang: 'ru');
      if (wRu.isNotEmpty) return wRu;
    }
    return '';
  }

  // Поиск свежего фото актёра: сначала свежие портреты из Википедии/Wikimedia Commons, затем TVmaze.
  static Future<(int?, String)> findPerson(String name, {String ruName = ''}) async {
    final clean = name.trim();
    if (clean.isEmpty) return (null, '');
    final wEn = await wikiPageImage(clean, lang: 'en');
    if (wEn.isNotEmpty) return (null, wEn);
    if (ruName.trim().isNotEmpty) {
      final wRu = await wikiPageImage(ruName.trim(), lang: 'ru');
      if (wRu.isNotEmpty) return (null, wRu);
    }
    try {
      final u = Uri.parse('$base/search/people?q=${Uri.encodeComponent(clean)}');
      final j = await Net.json(u, retries: 1, timeout: const Duration(seconds: 12));
      if (j is List && j.isNotEmpty) {
        for (final item in j) {
          if (item is! Map) continue;
          final p = item['person'];
          if (p is! Map) continue;
          final pid = p['id'] is int ? p['id'] as int : null;
          if (p['image'] is Map) {
            final img = p['image'] as Map;
            final url = (img['original'] ?? img['medium'] ?? '').toString().trim();
            if (url.isNotEmpty) return (pid, url.replaceFirst('http://', 'https://'));
          }
        }
      }
    } catch (_) {}
    return (null, '');
  }

  static String stripHtml(String s) {
    return s.replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&quot;', '"').replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'").replaceAll('&nbsp;', ' ').trim();
  }
}

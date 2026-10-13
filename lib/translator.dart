import 'dart:math' as math;
import 'config.dart';
import 'dict.dart';
import 'glossary.dart';
import 'models.dart';
import 'net.dart';
import 'openrouter.dart';
import 'tvmaze.dart';
import 'wiki.dart';

abstract class TrHost {
  Map<int, String> get custom;
  Map<int, String> get tr;
  Map<int, String> get trSrc;
  Map<int, int> get tried;
  Iterable<Drama> get allDramas;
  Set<int> get userIds;
  void changed();
}

const String _sysTitles =
    'Ты редактор русскоязычного каталога азиатских сериалов (дорам). Для каждого сериала из списка '
    'дай название на русском так, как его называют русскоязычные зрители и сайты (Википедия, Кинопоиск, '
    'Dorama.land, MyDramaList). Если в контексте уже есть русское название — используй его. '
    'Если устоявшегося названия нет, придумай естественное литературное название по смыслу, '
    'как перевёл бы живой редактор: НЕ дословно, НЕ транслитом, без кавычек. '
    'Имена собственные — в принятой русской транскрипции. '
    'Формат строки: номер | английское название | год | страна | жанры | студия | контекст. '
    'Ответь ТОЛЬКО JSON-массивом вида [{"i":0,"ru":"название"}] без пояснений и без markdown.';

const String _sysSummary =
    'Переведи описание сериала на русский живым литературным языком, как в аннотации на сайте о дорамах. '
    'Не добавляй ничего от себя, не пересказывай, не используй markdown. Названия сериалов и имена — '
    'в принятой русской транскрипции. Ответь только переводом.';

class Translator {
  final TrHost h;
  Translator(this.h);

  bool busy = false;
  int left = 0;
  bool _again = false;
  bool _gtxDown = false;
  int _gtxFails = 0;
  int _tick = 0;
  final Map<int, String> _ctx = {};
  final Map<int, int> _aiTries = {};

  static const Map<String, int> _rank = {'local': 0, 'mt': 1, 'ai': 2, 'wiki': 3};

  bool _resolved(Drama d) {
    if (h.custom.containsKey(d.id)) return true;
    if (dictLookup(d.en) != null) return true;
    final s = h.trSrc[d.id];
    return h.tr.containsKey(d.id) && s != 'mt' && s != 'local';
  }

  bool _hasAny(Drama d) =>
      h.custom.containsKey(d.id) || dictLookup(d.en) != null || h.tr.containsKey(d.id);

  bool _has(Drama d, int b) => ((h.tried[d.id] ?? 0) & b) != 0;
  void _flag(Drama d, int b) => h.tried[d.id] = (h.tried[d.id] ?? 0) | b;

  void _set(Drama d, String ru, String src) {
    final c = _clean(ru);
    if (c == null) return;
    final old = h.trSrc[d.id];
    if (h.tr.containsKey(d.id) && (_rank[src] ?? 0) < (_rank[old ?? 'local'] ?? 0)) return;
    h.tr[d.id] = c;
    h.trSrc[d.id] = src;
    _tick++;
    if (_tick % 20 == 0) h.changed();
  }

  String? _clean(String s) {
    var t = s.trim().replaceAll(RegExp(r'[«»"“”]'), '').trim();
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
    if (t.length < 2 || t.length > 90 || !hasCyr(t)) return null;
    return t;
  }

  List<Drama> _queue(bool Function(Drama) test) {
    final u = h.userIds;
    final l = h.allDramas.where(test).toList();
    l.sort((a, b) {
      final pa = u.contains(a.id) ? 1 : 0;
      final pb = u.contains(b.id) ? 1 : 0;
      if (pa != pb) return pb - pa;
      return b.date.compareTo(a.date);
    });
    return l;
  }

  void _updateLeft() {
    left = h.allDramas.where((d) => !_resolved(d)).length;
  }

  Future<void> _pool<T>(List<T> list, int n, Future<void> Function(T) fn) async {
    var i = 0;
    Future<void> worker() async {
      while (i < list.length) {
        final x = list[i++];
        try { await fn(x); } catch (_) {}
      }
    }
    await Future.wait(List.generate(math.min(n, list.length), (_) => worker()));
  }

  Future<void> run() async {
    if (busy) { _again = true; return; }
    busy = true;
    try {
      do {
        _again = false;
        _gtxDown = false;
        _gtxFails = 0;
        _updateLeft();
        h.changed();
        await _stageWiki();
        await _stageAi();
        await _stageFallback();
      } while (_again);
    } catch (_) {
    } finally {
      busy = false;
      _updateLeft();
      h.changed();
    }
  }

  Future<void> _stageWiki() async {
    var todo = _queue((d) => !_resolved(d) && d.imdb.isNotEmpty && !_has(d, 1));
    for (var i = 0; i < todo.length; i += 40) {
      final b = todo.sublist(i, math.min(i + 40, todo.length));
      final res = await Wiki.byImdb(b.map((d) => d.imdb).toList());
      if (res == null) continue;
      for (final d in b) {
        _flag(d, 1);
        final ru = res[d.imdb];
        if (ru != null) _set(d, ru, 'wiki');
      }
      h.changed();
    }
    todo = _queue((d) => !_resolved(d) && !_has(d, 16));
    var fail = 0;
    for (var i = 0; i < todo.length; i += 30) {
      final b = todo.sublist(i, math.min(i + 30, todo.length));
      final names = b.map((d) => d.en).where((e) => e.isNotEmpty).toSet().toList();
      if (names.isEmpty) continue;
      final res = await Wiki.byEnglish(names);
      if (res == null) {
        fail++;
        if (fail >= 3) break;
        continue;
      }
      for (final d in b) {
        _flag(d, 16);
        final ru = res[d.en.toLowerCase()];
        if (ru != null) _set(d, ru, 'wiki');
      }
      h.changed();
    }
    final t3 = _queue((d) => !_resolved(d) && !_has(d, 4)).take(300).toList();
    await _pool<Drama>(t3, 3, (d) async {
      if (_resolved(d)) return;
      final r = await Wiki.ruSearch(d.en);
      if (r == null) return;
      _flag(d, 4);
      if (r.isEmpty) return;
      _ctx[d.id] = r.take(2).map((x) => '${x['t']}: ${x['s']}').join(' | ');
      final p = Wiki.pick(d.en, r);
      if (p != null) _set(d, p, 'wiki');
    });
    h.changed();
  }

  Future<void> _stageAi() async {
    if (OpenRouter.key.trim().isEmpty || OpenRouter.badKey) return;
    var fails = 0;
    var rounds = 0;
    while (rounds < 60) {
      rounds++;
      final todo = _queue((d) =>
          !_resolved(d) && (_aiTries[d.id] ?? 0) < 2 && dictLookup(d.en) == null && !h.custom.containsKey(d.id));
      final b = todo.take(12).toList();
      if (b.isEmpty) break;
      final out = await _askAi(b);
      for (final d in b) {
        _aiTries[d.id] = (_aiTries[d.id] ?? 0) + 1;
      }
      if (out == null) {
        fails++;
        if (fails >= 2) break;
        await Net.sleep(2500);
        continue;
      }
      fails = 0;
      out.forEach((i, ru) => _set(b[i], ru, 'ai'));
      h.changed();
      _updateLeft();
      await Net.sleep(3200);
    }
  }

  Future<Map<int, String>?> _askAi(List<Drama> b) async {
    final sb = StringBuffer();
    for (var i = 0; i < b.length; i++) {
      final d = b[i];
      final ctx = _ctx[d.id];
      sb.writeln('$i | ${d.en} | ${d.year ?? "?"} | ${Cfg.countries[d.country] ?? d.country} | '
          '${d.genres.take(3).join(", ")} | ${d.network}${ctx != null ? " | википедия: $ctx" : ""}');
    }
    final txt = await OpenRouter.chat(_sysTitles, sb.toString(), maxTokens: 1500);
    if (txt == null) return null;
    final j = OpenRouter.extractJson(txt);
    if (j is! List) return null;
    final out = <int, String>{};
    for (final x in j) {
      if (x is Map) {
        final i = int.tryParse('${x['i']}');
        final ru = x['ru'];
        if (i != null && i >= 0 && i < b.length && ru is String) {
          final c = _clean(ru);
          if (c != null) out[i] = c;
        }
      }
    }
    return out;
  }

  Future<void> _stageFallback() async {
    final todo = _queue((d) => !_hasAny(d));
    await _pool<Drama>(todo, 3, _fallbackOne);
    h.changed();
  }

  Future<void> _fallbackOne(Drama d) async {
    if (_hasAny(d)) return;
    String? t;
    if (!_gtxDown) {
      t = await gtx(d.en);
      if (t == null) {
        _gtxFails++;
        if (_gtxFails >= 4) _gtxDown = true;
      } else {
        _gtxFails = 0;
      }
    }
    if (t != null) {
      final c = _clean(t);
      if (c != null) { _set(d, c, 'mt'); return; }
    }
    _set(d, localTranslate(d.en), 'local');
  }

  Future<void> ensureOne(Drama d) async {
    if (_resolved(d)) return;
    final r = await Wiki.ruSearch(d.en);
    if (r != null && r.isNotEmpty) {
      _ctx[d.id] = r.take(2).map((x) => '${x['t']}: ${x['s']}').join(' | ');
      final p = Wiki.pick(d.en, r);
      if (p != null) _set(d, p, 'wiki');
    }
    if (!_resolved(d)) {
      final out = await _askAi([d]);
      final ru = out == null ? null : out[0];
      if (ru != null) _set(d, ru, 'ai');
    }
    if (!_hasAny(d)) await _fallbackOne(d);
    h.changed();
  }

  Future<void> ensureMany(List<Drama> l) async {
    final todo = l.where((d) => !_resolved(d)).take(12).toList();
    await _pool<Drama>(todo, 2, ensureOne);
  }

  Future<SumRes?> summary(String en) async {
    final text = en.trim();
    if (text.isEmpty) return null;
    final ai = await OpenRouter.chat(_sysSummary, text, maxTokens: 1000);
    if (ai != null && hasCyr(ai)) return SumRes(ai.trim(), 'ai');
    final sb = StringBuffer();
    for (final part in _chunks(text)) {
      final t = await gtx(part);
      if (t == null) return null;
      sb.write('$t ');
    }
    final out = sb.toString().trim();
    return out.isEmpty ? null : SumRes(out, 'mt');
  }

  List<String> _chunks(String s) {
    final out = <String>[];
    var cur = '';
    for (final m in RegExp(r'[^.!?]+[.!?]*\s*').allMatches(s)) {
      final p = m.group(0) ?? '';
      if (cur.isNotEmpty && cur.length + p.length > 900) {
        out.add(cur); cur = '';
      }
      cur += p;
    }
    if (cur.isNotEmpty) out.add(cur);
    return out;
  }

  static Future<String?> gtx(String text) async {
    final j = await Net.json(
      Uri.https('translate.googleapis.com', '/translate_a/single',
          {'client': 'gtx', 'sl': 'auto', 'tl': 'ru', 'dt': 't', 'q': text}),
      retries: 1,
    );
    if (j is List && j.isNotEmpty && j[0] is List) {
      final sb = StringBuffer();
      for (final seg in j[0] as List) {
        if (seg is List && seg.isNotEmpty && seg[0] != null) sb.write(seg[0]);
      }
      final out = sb.toString().trim();
      return out.isEmpty ? null : out;
    }
    return null;
  }

  static String strip(String s) => Tvmaze.stripHtml(s);
}

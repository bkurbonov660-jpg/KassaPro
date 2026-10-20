import 'dart:math' as math;
import 'config.dart';
import 'dict.dart';
import 'models.dart';
import 'store.dart';

class Trope {
  final String id;
  final String label;
  final List<String> strong;
  final List<String> weak;
  final int minWeak;
  final List<String> genres;
  const Trope(this.id, this.label, this.strong, this.weak,
      {this.minWeak = 2, this.genres = const <String>[]});
}

const List<Trope> kTropes = [
  Trope('slowburn', 'Слоуберн',
      ['слоуберн', 'медленно разгора', 'постепенно влюб', 'шаг за шагом', 'тайно влюблен', 'молча любит', 'давняя любовь'],
      ['постепенно', 'медленно', 'со временем', 'друг детства', 'друзья детства', 'скрыва', 'чувств', 'годы'],
      minWeak: 3, genres: ['Romance']),
  Trope('enemies', 'Враги в любовь',
      ['враги', 'от ненависти к любви', 'ненавидят друг друга', 'вражд', 'заклят'],
      ['соперни', 'конкурент', 'ссор', 'конфликт', 'противосто', 'ненавид', 'не выносят', 'терпеть не'],
      minWeak: 2, genres: ['Romance', 'Comedy']),
  Trope('strongfl', 'Сильная героиня',
      ['сильная героиня', 'независимая женщина', 'амбициозная женщина', 'решительная героиня', 'отважная героиня', 'самостоятельная женщина', 'сильная женщина'],
      ['героиня', 'амбициозн', 'независим', 'самостоятельн', 'карьер', 'прокурор', 'адвокат', 'следовател', 'хирург', 'борется', 'добивается', 'отважн', 'решительн'],
      minWeak: 3),
  Trope('fake', 'Фиктивные отношения',
      ['фиктивн', 'притворя', 'притворн', 'договорн', 'брак по контракту', 'контрактн', 'ненастоящ', 'делают вид'],
      ['контракт', 'договор', 'обман', 'притвор'],
      minWeak: 2),
  Trope('second', 'Второй шанс',
      ['второй шанс', 'второго шанса', 'бывш', 'спустя годы', 'спустя много лет', 'встречаются вновь', 'снова встреча'],
      ['прошлое', 'вновь', 'воссоед', 'расстал'],
      minWeak: 3, genres: ['Romance']),
  Trope('timeslip', 'Путешествие во времени',
      ['путешествие во времени', 'путешествия во времени', 'машин времени', 'петл', 'вернуться в прошлое', 'возвращается в прошлое', 'в прошлое', 'из будущего', 'перемещается во времени'],
      ['время', 'будущее'],
      minWeak: 2),
  Trope('revenge', 'Месть',
      ['месть', 'мстит', 'отомстить', 'мщен', 'мстить'],
      ['предательств', 'жажд', 'расплат'],
      minWeak: 2),
  Trope('office', 'Офисный роман',
      ['коллег', 'начальник', 'босс', 'секретар', 'генеральный директор', 'сотрудник'],
      ['офис', 'компани', 'работ', 'карьер', 'стартап'],
      minWeak: 2, genres: ['Romance']),
  Trope('cinderella', 'Богач и простушка',
      ['наследник', 'золушк', 'чеболь', 'миллионер', 'олигарх', 'из бедной семьи'],
      ['богат', 'бедн', 'состоятельн', 'корпораци', 'директор'],
      minWeak: 3, genres: ['Romance']),
  Trope('triangle', 'Любовный треугольник',
      ['любовный треугольник', 'треугольник', 'между двумя', 'двух мужчин', 'двое мужчин', 'два парня', 'выбор между'],
      <String>[],
      minWeak: 1),
  Trope('palace', 'Дворцовые интриги',
      ['дворц', 'принц', 'король', 'королев', 'династи', 'чосон', 'наследный', 'трон', 'императр'],
      ['интриг', 'власть', 'заговор'],
      minWeak: 2, genres: ['History']),
  Trope('school', 'Школа и юность',
      ['школ', 'старшеклассник', 'выпускной класс', 'подростк', 'одноклассник'],
      ['университет', 'студент', 'класс', 'выпускн'],
      minWeak: 2),
];

String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

class Rec {
  final Drama d;
  final double score;
  final String why;
  const Rec(this.d, this.score, this.why);
  int get pct => (score * 130).round().clamp(5, 98).toInt();
}

class RecRow {
  final String title;
  final List<Rec> items;
  const RecRow(this.title, this.items);
}

class _Liked {
  final Drama d;
  final double w;
  final int r;
  const _Liked(this.d, this.w, this.r);
}

class Taste {
  static final Map<int, Set<String>> _tc = <int, Set<String>>{};
  static final Map<int, int> _tcLen = <int, int>{};
  static final Map<int, Map<String, double>> _vc = <int, Map<String, double>>{};
  static Map<String, double> _idf = <String, double>{};
  static int _idfN = -1;
  static String _sig = '';
  static String _recSig = '';
  static bool _built = false;
  static List<_Liked> _liked = <_Liked>[];
  static List<_Liked> _bad = <_Liked>[];
  static Map<String, double> _tastePos = <String, double>{};
  static Map<String, double> _tasteNeg = <String, double>{};
  static Set<String> _fav = <String>{};
  static List<RecRow> _rows = <RecRow>[];

  // ── Темы (тропы) ──
  static bool _hit(Trope t, String text, Drama d) {
    if (t.genres.isNotEmpty && !d.genres.any((g) => t.genres.contains(g))) return false;
    for (final k in t.strong) {
      if (text.contains(k)) return true;
    }
    var n = 0;
    for (final k in t.weak) {
      if (text.contains(k)) {
        n++;
        if (n >= t.minWeak) return true;
      }
    }
    return false;
  }

  static Set<String> tropesOf(Drama d) {
    final s = store.sumRu[d.id];
    final len = s == null ? -1 : s.length;
    final c = _tc[d.id];
    if (c != null && _tcLen[d.id] == len) return c;
    final out = <String>{};
    if (s != null && s.isNotEmpty) {
      final text = _norm('${store.ruTitle(d)} $s');
      for (final t in kTropes) {
        if (_hit(t, text, d)) out.add(t.id);
      }
    }
    _tc[d.id] = out;
    _tcLen[d.id] = len;
    return out;
  }

  static bool hasTrope(Drama d, Trope t) => tropesOf(d).contains(t.id);

  static List<String> tropeLabels(Drama d) {
    final s = tropesOf(d);
    return [for (final t in kTropes) if (s.contains(t.id)) t.label];
  }

  static Trope? tropeForQuery(String q) {
    final qq = _norm(q.trim());
    if (qq.length < 4) return null;
    for (final t in kTropes) {
      final l = _norm(t.label);
      if (l.contains(qq) || qq == l) return t;
    }
    return null;
  }

  // Поиск по описаниям и по актёрам: слово или фраза в русских описаниях, имя в составе.
  static List<Drama> searchAll(String q) {
    final qq = _norm(q.trim());
    if (qq.length < 3) return <Drama>[];
    final out = <Drama>[];
    final seen = <int>{};
    for (final e in store.sumRu.entries) {
      if (!_norm(e.value).contains(qq)) continue;
      final d = store.find(e.key);
      if (d == null || d.country != 'KR' || !seen.add(d.id)) continue;
      out.add(d);
      if (out.length >= 80) break;
    }
    final ql = q.trim().toLowerCase();
    final hitKeys = <String>[];
    store.aliasByTitle.forEach((k, al) {
      if (al.any((n) => n.toLowerCase().contains(ql))) hitKeys.add(k);
    });
    store.castByTitle.forEach((k, names) {
      if (names.any((n) => n.toLowerCase().contains(ql))) hitKeys.add(k);
    });
    if (hitKeys.isNotEmpty) {
      for (final d in store.allDramas) {
        if (d.country == 'KR' && hitKeys.contains(store.keyOf(d)) && seen.add(d.id)) out.add(d);
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  // ── Векторы признаков (жанры, темы, канал, год) с весом IDF ──
  static void _buildIdf() {
    final n = store.allDramas.length;
    if (n == _idfN) return;
    _idfN = n;
    final df = <String, int>{};
    var tot = 0;
    for (final d in store.allDramas) {
      if (d.country != 'KR') continue;
      tot++;
      for (final g in d.genres) {
        df['g:$g'] = (df['g:$g'] ?? 0) + 1;
      }
      for (final t in tropesOf(d)) {
        df['t:$t'] = (df['t:$t'] ?? 0) + 1;
      }
      if (d.network.isNotEmpty) {
        df['n:${d.network}'] = (df['n:${d.network}'] ?? 0) + 1;
      }
    }
    final m = <String, double>{};
    df.forEach((k, v) {
      m[k] = math.log((tot + 1) / (v + 1)) + 1.0;
    });
    _idf = m;
    _vc.clear();
  }

  static Map<String, double> _vec(Drama d) {
    final c = _vc[d.id];
    if (c != null) return c;
    final v = <String, double>{};
    for (final g in d.genres) {
      v['g:$g'] = _idf['g:$g'] ?? 1.0;
    }
    for (final t in tropesOf(d)) {
      v['t:$t'] = (_idf['t:$t'] ?? 1.0) * 1.3;
    }
    if (d.network.isNotEmpty) {
      v['n:${d.network}'] = (_idf['n:${d.network}'] ?? 1.0) * 0.5;
    }
    final y = d.year;
    if (y != null) {
      v['y:$y'] = 0.4;
      v['y:${y - 1}'] = 0.2;
      v['y:${y + 1}'] = 0.2;
    }
    _vc[d.id] = v;
    return v;
  }

  static double _cos(Map<String, double> a, Map<String, double> b) {
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    a.forEach((k, x) {
      na += x * x;
      final y = b[k];
      if (y != null) dot += x * y;
    });
    b.forEach((k, y) {
      nb += y * y;
    });
    if (na == 0 || nb == 0) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }

  static double sim(Drama a, Drama b) => _cos(_vec(a), _vec(b));

  // ── Профиль вкуса ──
  static String _signature() {
    var h = 17;
    store.rate.forEach((k, v) {
      h = (h * 31 + k * 7 + v) & 0x3fffffff;
    });
    store.listOf.forEach((k, v) {
      h = (h * 31 + k + v.length) & 0x3fffffff;
    });
    final n = store.allDramas.length ~/ 150;
    return '$h:$n:${store.sumRu.length ~/ 100}:${store.hidden.length}:${todayIso()}';
  }

  static void _ensure() {
    final sig = _signature();
    if (_built && sig == _sig) return;
    _sig = sig;
    _built = true;
    _vc.clear();
    _buildIdf();
    final liked = <_Liked>[];
    final bad = <_Liked>[];
    for (final id in store.userIds) {
      final d = store.find(id);
      if (d == null) continue;
      final r = store.rate[id];
      final st = store.listOf[id];
      if (r != null) {
        if (r >= 7) {
          liked.add(_Liked(d, (r - 5) / 5.0, r));
        } else if (r <= 4) {
          bad.add(_Liked(d, (5 - r) / 4.0, r));
        }
      } else if (st == 'done') {
        liked.add(_Liked(d, 0.3, 0));
      } else if (st == 'watch' && (store.prog[id] ?? 0) >= 3) {
        liked.add(_Liked(d, 0.2, 0));
      } else if (st == 'drop') {
        bad.add(_Liked(d, 0.5, 0));
      }
    }
    final pos = <String, double>{};
    for (final l in liked) {
      _vec(l.d).forEach((k, x) {
        pos[k] = (pos[k] ?? 0) + x * l.w;
      });
    }
    final neg = <String, double>{};
    for (final b in bad) {
      _vec(b.d).forEach((k, x) {
        neg[k] = (neg[k] ?? 0) + x * b.w;
      });
    }
    final gs = <MapEntry<String, double>>[];
    pos.forEach((k, v) {
      if (k.startsWith('g:')) gs.add(MapEntry(k.substring(2), v));
    });
    gs.sort((a, b) => b.value.compareTo(a.value));
    _fav = gs.take(3).map((e) => e.key).toSet();
    _liked = liked;
    _bad = bad;
    _tastePos = pos;
    _tasteNeg = neg;
    _recSig = '';
  }

  static bool get hasProfile {
    _ensure();
    return _liked.isNotEmpty;
  }

  static Rec? _score(Drama c) {
    if (_liked.isEmpty) return null;
    final vc = _vec(c);
    final parts = <(double, double)>[];
    Drama? best;
    var bestV = 0.0;
    var bestR = 0;
    for (final l in _liked) {
      if (l.d.id == c.id) continue;
      final v = l.w * _cos(vc, _vec(l.d));
      parts.add((v, l.w));
      if (v > bestV) {
        bestV = v;
        best = l.d;
        bestR = l.r;
      }
    }
    if (parts.isEmpty) return null;
    parts.sort((a, b) => b.$1.compareTo(a.$1));
    var sn = 0.0;
    var sd = 0.0;
    for (final p in parts.take(3)) {
      sn += p.$1;
      sd += p.$2;
    }
    final knn = sd > 0 ? sn / sd : 0.0;
    final pos = _cos(_tastePos, vc);
    final neg = _bad.isEmpty ? 0.0 : _cos(_tasteNeg, vc);
    final rt = c.rating;
    final q = rt == null ? 0.0 : math.max(0.0, math.min(1.0, (rt - 6.0) / 4.0));
    final y = c.year;
    final fresh = (y != null && y >= DateTime.now().year - 1) ? 0.04 : 0.0;
    final s = 0.40 * knn + 0.30 * pos + 0.16 * q + fresh - 0.35 * neg;
    var why = '';
    if (best != null) {
      why = 'Похоже на «${store.ruTitle(best)}»' +
          (bestR > 0 ? ' — ваша оценка $bestR' : ' — вам зашло');
    }
    return Rec(c, s, why);
  }

  // Совпадение дорамы с вашим вкусом, 5–98 %. null — пока мало данных.
  static int? match(Drama d) {
    _ensure();
    if (_liked.isEmpty) return null;
    final r = _score(d);
    return r?.pct;
  }

  static List<String> why(Drama d) {
    _ensure();
    final out = <String>[];
    if (_liked.isEmpty) return out;
    final r = _score(d);
    if (r != null && r.why.isNotEmpty) out.add(r.why);
    final fav = <String>[];
    for (final g in d.genres) {
      if (_fav.contains(g)) fav.add(Cfg.genres[g] ?? g);
    }
    if (fav.isNotEmpty) out.add('Ваши любимые жанры: ${fav.join(", ")}');
    final tl = tropeLabels(d);
    if (tl.isNotEmpty) out.add('Темы: ${tl.join(", ")}');
    return out;
  }

  // Подбор с разнообразием: не выдаёт десять одинаковых дорам подряд.
  static List<Rec> _mmr(List<Rec> pool, int n) {
    final sel = <Rec>[];
    final left = List<Rec>.from(pool);
    while (sel.length < n && left.isNotEmpty) {
      Rec? best;
      var bv = -999.0;
      for (final r in left) {
        var mx = 0.0;
        final vr = _vec(r.d);
        for (final s in sel) {
          final v = _cos(vr, _vec(s.d));
          if (v > mx) mx = v;
        }
        final val = 0.75 * r.score - 0.25 * mx;
        if (val > bv) {
          bv = val;
          best = r;
        }
      }
      if (best == null) break;
      sel.add(best);
      left.remove(best);
    }
    return sel;
  }

  // Подборки для главного экрана.
  static List<RecRow> rows() {
    _ensure();
    if (_liked.isEmpty) return <RecRow>[];
    if (_recSig == _sig) return _rows;
    final today = todayIso();
    final cands = <Rec>[];
    final c26 = <Rec>[];
    for (final d in store.allDramas) {
      if (d.country != 'KR' || d.genres.isEmpty) continue;
      if (store.listOf.containsKey(d.id) || store.rate.containsKey(d.id) || store.hidden.contains(d.id)) continue;
      final r = _score(d);
      if (r == null) continue;
      final released = d.date.isEmpty || d.date.compareTo(today) <= 0;
      final rt = d.rating;
      if (released && rt != null && rt >= 6.5 && r.score > 0.15) cands.add(r);
      if (d.year == 2026 && r.score > 0.1) c26.add(r);
    }
    cands.sort((a, b) => b.score.compareTo(a.score));
    c26.sort((a, b) => b.score.compareTo(a.score));
    final out = <RecRow>[];
    final main = _mmr(cands.take(60).toList(), 12);
    if (main.isNotEmpty) out.add(RecRow('Подобрано для вас', main));
    final top = List<_Liked>.from(_liked);
    top.sort((a, b) => b.w.compareTo(a.w));
    var made = 0;
    for (final l in top) {
      if (made >= 2) break;
      final vl = _vec(l.d);
      final sims = <Rec>[];
      for (final c in cands) {
        final sm = _cos(vl, _vec(c.d));
        if (sm > 0.3) sims.add(Rec(c.d, sm, 'Похоже на «${store.ruTitle(l.d)}»'));
      }
      if (sims.length < 3) continue;
      sims.sort((a, b) => b.score.compareTo(a.score));
      out.add(RecRow('Потому что вам понравилась «${store.ruTitle(l.d)}»', sims.take(10).toList()));
      made++;
    }
    if (c26.isNotEmpty) {
      out.add(RecRow('Дорамы 2026 по вашему вкусу', c26.take(12).toList()));
    }
    _rows = out;
    _recSig = _sig;
    return _rows;
  }

  static List<Drama> byTrope(Trope t, {int seed = 1, int limit = 10}) {
    _ensure();
    final today = todayIso();
    final scored = <MapEntry<Drama, double>>[];
    for (final d in store.allDramas) {
      if (d.country != 'KR') continue;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) continue;
      if (!tropesOf(d).contains(t.id)) continue;
      if (store.hidden.contains(d.id)) continue;
      final st = store.listOf[d.id];
      if (st != null && st != 'plan') continue;
      var sc = d.rating ?? 6.0;
      if (_liked.isNotEmpty) {
        final m = _score(d);
        if (m != null) sc += 3 * m.score;
      }
      scored.add(MapEntry(d, sc));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final pool = scored.take(limit * 4).map((e) => e.key).toList();
    pool.shuffle(math.Random(seed));
    return pool.take(limit).toList();
  }

  // Список для рулетки: «В планах» или общая подборка хороших дорам.
  static List<Drama> roulettePool(bool fromPlan) {
    if (fromPlan) return store.listItems('plan');
    final today = todayIso();
    final l = <Drama>[];
    for (final d in store.allDramas) {
      if (d.country != 'KR' || d.poster.isEmpty) continue;
      if (store.listOf.containsKey(d.id) || store.hidden.contains(d.id)) continue;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) continue;
      final r = d.rating;
      if (r == null || r < 7.0) continue;
      l.add(d);
    }
    l.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return l.take(120).toList();
  }
}

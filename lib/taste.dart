import 'dart:math' as math;
import 'config.dart';
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

class _Liked {
  final Drama d;
  final double w;
  final int r;
  const _Liked(this.d, this.w, this.r);
}

class Taste {
  static final Map<int, Set<String>> _tc = <int, Set<String>>{};
  static final Map<int, int> _tcLen = <int, int>{};
  static String _sig = '';
  static String _recSig = '';
  static bool _built = false;
  static List<_Liked> _liked = <_Liked>[];
  static List<_Liked> _bad = <_Liked>[];
  static Map<String, double> _gpref = <String, double>{};
  static List<Rec> _recs = <Rec>[];

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

  // Поиск по описаниям: ищет слово или фразу в русских описаниях дорам.
  static List<Drama> searchDesc(String q) {
    final qq = _norm(q.trim());
    if (qq.length < 3) return <Drama>[];
    final out = <Drama>[];
    for (final e in store.sumRu.entries) {
      if (!_norm(e.value).contains(qq)) continue;
      final d = store.find(e.key);
      if (d == null || d.country != 'KR') continue;
      out.add(d);
      if (out.length >= 80) break;
    }
    out.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return out;
  }

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
    return '$h:$n:${store.sumRu.length ~/ 100}:${todayIso()}';
  }

  static void _ensure() {
    final sig = _signature();
    if (_built && sig == _sig) return;
    _sig = sig;
    _built = true;
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
      } else if (st == 'drop') {
        bad.add(_Liked(d, 0.5, 0));
      }
    }
    final gp = <String, double>{};
    for (final l in liked) {
      for (final g in l.d.genres) {
        gp[g] = (gp[g] ?? 0) + l.w;
      }
    }
    var mx = 0.0;
    gp.forEach((_, v) {
      if (v > mx) mx = v;
    });
    if (mx > 0) {
      gp.updateAll((_, v) => v / mx);
    }
    _liked = liked;
    _bad = bad;
    _gpref = gp;
  }

  static bool get hasProfile {
    _ensure();
    return _liked.isNotEmpty;
  }

  static double _jacL(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var i = 0;
    for (final x in a) {
      if (b.contains(x)) i++;
    }
    final u = a.length + b.length - i;
    return u <= 0 ? 0 : i / u;
  }

  static double _jacS(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var i = 0;
    for (final x in a) {
      if (b.contains(x)) i++;
    }
    final u = a.length + b.length - i;
    return u <= 0 ? 0 : i / u;
  }

  // Похожесть двух дорам: жанры, темы, канал, близость года.
  static double sim(Drama a, Drama b) {
    var s = 0.55 * _jacL(a.genres, b.genres);
    final ta = tropesOf(a);
    final tb = tropesOf(b);
    if (ta.isNotEmpty && tb.isNotEmpty) s += 0.25 * _jacS(ta, tb);
    if (a.network.isNotEmpty && a.network == b.network) s += 0.10;
    if (a.year != null && b.year != null) {
      final dy = (a.year! - b.year!).abs();
      s += 0.10 * (1 - math.min(dy, 6) / 6.0);
    }
    return s;
  }

  static Rec? _score(Drama c) {
    if (_liked.isEmpty) return null;
    final parts = <(double, double)>[];
    Drama? best;
    var bestV = 0.0;
    var bestR = 0;
    for (final l in _liked) {
      if (l.d.id == c.id) continue;
      final v = l.w * sim(c, l.d);
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
    final aff = sd > 0 ? sn / sd : 0.0;
    var gp = 0.0;
    if (c.genres.isNotEmpty) {
      for (final g in c.genres) {
        gp += _gpref[g] ?? 0;
      }
      gp = math.min(1.0, gp / c.genres.length);
    }
    final rt = c.rating;
    final q = rt == null ? 0.0 : math.max(0.0, math.min(1.0, (rt - 6.0) / 4.0));
    var pen = 0.0;
    for (final b in _bad) {
      if (b.d.id == c.id) continue;
      final v = b.w * sim(c, b.d);
      if (v > pen) pen = v;
    }
    final s = 0.6 * aff + 0.25 * gp + 0.15 * q - 0.5 * pen;
    var why = '';
    if (best != null) {
      why = 'Похоже на «${store.ruTitle(best)}»' +
          (bestR > 0 ? ' — ваша оценка $bestR' : ' — вы её досмотрели');
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
      if ((_gpref[g] ?? 0) >= 0.6) fav.add(Cfg.genres[g] ?? g);
    }
    if (fav.isNotEmpty) out.add('Ваши любимые жанры: ${fav.join(", ")}');
    final tl = tropeLabels(d);
    if (tl.isNotEmpty) out.add('Темы: ${tl.join(", ")}');
    return out;
  }

  // Рекомендации: по вашим оценкам и просмотренному, а не только по жанру.
  static List<Rec> forYou({int limit = 12}) {
    _ensure();
    if (_liked.isEmpty) return <Rec>[];
    if (_recSig == _sig) return _recs.take(limit).toList();
    final today = todayIso();
    final out = <Rec>[];
    for (final d in store.allDramas) {
      if (d.country != 'KR' || d.genres.isEmpty) continue;
      if (store.listOf.containsKey(d.id) || store.rate.containsKey(d.id)) continue;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) continue;
      final r = d.rating;
      if (r == null || r < 6.5) continue;
      final s = _score(d);
      if (s != null && s.score > 0.15) out.add(s);
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    _recs = out.take(40).toList();
    _recSig = _sig;
    return _recs.take(limit).toList();
  }

  static List<Drama> byTrope(Trope t, {int seed = 1, int limit = 10}) {
    _ensure();
    final today = todayIso();
    final scored = <MapEntry<Drama, double>>[];
    for (final d in store.allDramas) {
      if (d.country != 'KR') continue;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) continue;
      if (!tropesOf(d).contains(t.id)) continue;
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
      if (store.listOf.containsKey(d.id)) continue;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) continue;
      final r = d.rating;
      if (r == null || r < 7.0) continue;
      l.add(d);
    }
    l.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return l.take(120).toList();
  }
}

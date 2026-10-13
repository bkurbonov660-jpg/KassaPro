import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'dict.dart';
import 'models.dart';
import 'net.dart';
import 'openrouter.dart';
import 'translator.dart';
import 'tvmaze.dart';
import 'wiki.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String todayIso() {
  final n = DateTime.now();
  return '${n.year}-${_two(n.month)}-${_two(n.day)}';
}

class Store extends ChangeNotifier implements TrHost {
  SharedPreferences? _p;

  final Map<int, Drama> catalog = {};
  final Map<int, Drama> pinned = {};
  final Map<int, Drama> temp = {};
  final Map<int, String> listOf = {};
  final Map<int, int> prog = {};
  final Map<int, int> rate = {};
  @override
  final Map<int, String> custom = {};
  @override
  final Map<int, String> tr = {};
  @override
  final Map<int, String> trSrc = {};
  @override
  final Map<int, int> tried = {};
  final Map<int, String> sumRu = {};
  final Map<int, String> sumSrc = {};

  List<LiveItem> live = [];
  final List<Drama> newFinds = [];
  bool scanning = false;
  double scanProgress = 0;
  bool refreshing = false;
  DateTime? lastUpdate;
  String lastError = '';
  int scanMax = 0, scanLow = 0, scanTarget = 0;
  bool seeded = false;

  late final Translator translator = Translator(this);
  Timer? _timer, _saveT;
  bool _notifyPending = false;
  List<Drama>? _allCache;

  @override
  Iterable<Drama> get allDramas {
    _allCache ??= _merge();
    return _allCache!;
  }

  List<Drama> _merge() {
    final m = <int, Drama>{};
    m.addAll(pinned);
    m.addAll(catalog);
    return m.values.toList();
  }

  @override
  Set<int> get userIds => {...listOf.keys, ...rate.keys};

  @override
  void changed() {
    _saveSoon();
    _poke();
  }

  void _poke() {
    if (_notifyPending) return;
    _notifyPending = true;
    Timer(const Duration(milliseconds: 350), () {
      _notifyPending = false;
      notifyListeners();
    });
  }

  String ruTitle(Drama d) {
    final c = custom[d.id];
    if (c != null && c.isNotEmpty) return c;
    final x = dictLookup(d.en);
    if (x != null) return x;
    return tr[d.id] ?? d.en;
  }

  bool hasRu(Drama d) => ruTitle(d) != d.en || hasCyr(ruTitle(d));

  String titleNote(Drama d) {
    if (custom.containsKey(d.id)) return 'Ваше название';
    if (dictLookup(d.en) != null) return 'Из словаря точных названий';
    switch (trSrc[d.id]) {
      case 'wiki': return 'Название из Википедии / Викиданных';
      case 'ai': return 'Перевод ИИ (живой, не дословный)';
      case 'mt': return 'Автоперевод — ИИ уточнит позже';
      case 'local': return 'Встроенный перевод — ИИ уточнит позже';
    }
    return 'Переводится…';
  }

  Drama? find(int id) => catalog[id] ?? pinned[id] ?? temp[id];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _load();
    notifyListeners();
    _timer = Timer.periodic(const Duration(minutes: 8), (_) => refresh());
    refresh();
  }

  Map<int, T> _readMap<T>(dynamic raw) {
    final out = <int, T>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && v is T) out[i] = v;
      });
    }
    return out;
  }

  void _load() {
    final raw = _p!.getString('dp_catalog');
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
          catalog[d.id] = d;
        }
      } catch (_) {}
    }
    final u = _p!.getString('dp_user');
    if (u != null) {
      try {
        final m = jsonDecode(u) as Map<String, dynamic>;
        listOf.addAll(_readMap<String>(m['list']));
        prog.addAll(_readMap<int>(m['prog']));
        rate.addAll(_readMap<int>(m['rate']));
        custom.addAll(_readMap<String>(m['custom']));
        tr.addAll(_readMap<String>(m['tr']));
        trSrc.addAll(_readMap<String>(m['trSrc']));
        tried.addAll(_readMap<int>(m['tried']));
        sumRu.addAll(_readMap<String>(m['sumRu']));
        sumSrc.addAll(_readMap<String>(m['sumSrc']));
        if (m['pinned'] is List) {
          for (final e in m['pinned'] as List) {
            final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
            pinned[d.id] = d;
          }
        }
        scanMax = (m['scanMax'] ?? 0) as int;
        scanLow = (m['scanLow'] ?? 0) as int;
        scanTarget = (m['scanTarget'] ?? 0) as int;
        seeded = (m['seeded'] ?? false) as bool;
        if (m['orKey'] is String && (m['orKey'] as String).isNotEmpty) OpenRouter.key = m['orKey'] as String;
        OpenRouter.webPlugin = (m['web'] ?? false) as bool;
      } catch (_) {}
    }
    _allCache = null;
  }

  Map<String, T> _sm<T>(Map<int, T> m) => m.map((k, v) => MapEntry('$k', v));

  void _saveSoon() {
    _saveT?.cancel();
    _saveT = Timer(const Duration(seconds: 2), _saveNow);
  }

  Future<void> _saveNow() async {
    final p = _p;
    if (p == null) return;
    try {
      await p.setString('dp_catalog', jsonEncode(catalog.values.map((d) => d.toJson()).toList()));
      await p.setString('dp_user', jsonEncode({
        'list': _sm(listOf),
        'prog': _sm(prog),
        'rate': _sm(rate),
        'custom': _sm(custom),
        'tr': _sm(tr),
        'trSrc': _sm(trSrc),
        'tried': _sm(tried),
        'sumRu': _sm(sumRu),
        'sumSrc': _sm(sumSrc),
        'pinned': pinned.values.map((d) => d.toJson()).toList(),
        'scanMax': scanMax, 'scanLow': scanLow, 'scanTarget': scanTarget, 'seeded': seeded,
        'orKey': OpenRouter.key == Cfg.orKey ? '' : OpenRouter.key,
        'web': OpenRouter.webPlugin,
      }));
    } catch (_) {}
  }

  void saveNow() => _saveNow();

  Future<void> refresh({bool deep = false}) async {
    if (refreshing) return;
    refreshing = true;
    lastError = '';
    _poke();
    try {
      await loadLive();
      translator.run();
      await scanCatalog();
      await discoverAnnounced();
      lastUpdate = DateTime.now();
      translator.run();
    } catch (e) {
      lastError = 'Ошибка обновления: $e';
    } finally {
      refreshing = false;
      _saveSoon();
      _poke();
    }
  }

  Drama _upsert(Drama d) {
    final ex = catalog[d.id];
    if (ex == null) {
      d.seen = seeded ? DateTime.now().millisecondsSinceEpoch : 0;
      catalog[d.id] = d;
      _allCache = null;
      if (seeded) newFinds.insert(0, d);
      return d;
    }
    if (d.poster.isNotEmpty) ex.poster = d.poster;
    if (d.rating != null) ex.rating = d.rating;
    if (d.date.isNotEmpty) { ex.date = d.date; ex.year = d.year; }
    if (d.status.isNotEmpty) ex.status = d.status;
    if (d.genres.isNotEmpty) ex.genres = d.genres;
    if (d.imdb.isNotEmpty) ex.imdb = d.imdb;
    if (d.network.isNotEmpty) ex.network = d.network;
    return ex;
  }

  Future<void> loadLive() async {
    final iso = todayIso();
    final urls = <Uri>[Uri.parse('${Tvmaze.base}/schedule/web?date=$iso')];
    for (final c in Cfg.countries.keys) {
      urls.add(Uri.parse('${Tvmaze.base}/schedule?country=$c&date=$iso'));
    }
    final res = await Future.wait(urls.map((u) => Net.json(u)));
    final m = <int, LiveItem>{};
    for (final r in res) {
      if (r is! List) continue;
      for (final e in r) {
        if (e is! Map) continue;
        dynamic show = e['show'];
        if (show == null && e['_embedded'] is Map) show = (e['_embedded'] as Map)['show'];
        final d = Tvmaze.parse(show);
        if (d == null || m.containsKey(d.id)) continue;
        m[d.id] = LiveItem(
          drama: _upsert(d),
          time: (e['airtime'] ?? '').toString(),
          number: e['number'] is int ? e['number'] as int : null,
        );
      }
    }
    if (m.isNotEmpty || res.any((r) => r is List)) {
      live = m.values.toList()..sort((a, b) => a.time.compareTo(b.time));
    }
    _poke();
  }

  void deepScan() {
    if (scanTarget > 1) scanTarget = math.max(1, scanTarget - 120);
    refresh();
  }

  Future<void> scanCatalog() async {
    if (scanning) return;
    scanning = true;
    scanProgress = 0;
    _poke();
    try {
      final cache = <int, List<dynamic>>{};
      Future<int> probe(int p) async {
        final r = await Net.get(Uri.parse('${Tvmaze.base}/shows?page=$p'), retries: 1);
        if (r.code == 200 && r.data is List) { cache[p] = r.data as List; return 1; }
        if (r.code == 404) return 0;
        return -1;
      }

      var lo = 0, hi = 0;
      final guess = scanMax > 0 ? scanMax : 400;
      var s = await probe(guess);
      if (s < 0) {
        lastError = 'Нет сети — показываем сохранённый каталог';
        return;
      }
      if (s == 1) {
        lo = guess;
        while (true) {
          final p = lo + 10;
          s = await probe(p);
          if (s < 0) return;
          if (s == 1) { lo = p; } else { hi = p; break; }
        }
      } else {
        hi = guess;
        while (true) {
          final p = hi - 20;
          if (p < 1) { lo = 1; break; }
          s = await probe(p);
          if (s < 0) return;
          if (s == 1) { lo = p; break; } else { hi = p; }
        }
      }
      while (hi - lo > 1) {
        final m = (lo + hi) ~/ 2;
        s = await probe(m);
        if (s < 0) return;
        if (s == 1) { lo = m; } else { hi = m; }
      }
      final maxPage = lo;
      final firstRun = scanLow == 0;
      final pages = <int>[];
      if (firstRun) {
        scanTarget = math.max(1, maxPage - Cfg.scanDepth + 1);
        for (var p = maxPage; p >= scanTarget; p--) pages.add(p);
      } else {
        for (var p = maxPage; p >= math.max(1, scanMax - 1); p--) pages.add(p);
        for (var p = scanLow - 1; p >= scanTarget; p--) {
          if (!pages.contains(p)) pages.add(p);
        }
      }

      Future<List<dynamic>?> fetchPage(int p) async {
        if (cache.containsKey(p)) return cache[p];
        final r = await Net.get(Uri.parse('${Tvmaze.base}/shows?page=$p'));
        if (r.code == 200 && r.data is List) return r.data as List;
        return null;
      }

      var done = 0;
      var incomplete = false;
      for (var i = 0; i < pages.length; i += 3) {
        final b = pages.sublist(i, math.min(i + 3, pages.length));
        final res = await Future.wait(b.map(fetchPage));
        var bad = 0;
        for (final l in res) {
          if (l == null) { bad++; continue; }
          for (final x in l) {
            final d = Tvmaze.parse(x);
            if (d != null) _upsert(d);
          }
        }
        if (bad > 0) {
          lastError = 'Каталог загружен не полностью — продолжим при обновлении';
          incomplete = true;
          break;
        }
        done += b.length;
        scanProgress = done / pages.length;
        if (firstRun) { scanMax = maxPage; scanLow = b.last; }
        if ((i ~/ 3) % 10 == 9) {
          translator.run();
          _saveSoon();
        }
        _poke();
        await Net.sleep(1300);
      }
      if (!incomplete) {
        scanMax = maxPage;
        if (pages.isNotEmpty) scanLow = scanLow == 0 ? pages.last : math.min(scanLow, pages.last);
        if (scanLow <= scanTarget) seeded = true;
      }
      scanProgress = 1;
      await _saveNow();
    } finally {
      scanning = false;
      _poke();
    }
  }

  Future<void> discoverAnnounced() async {
    final now = DateTime.now();
    final rows = await Wiki.announced(now.year < 2026 ? 2026 : now.year);
    if (rows == null) return;
    final byImdb = <String, Drama>{};
    final byName = <String, Drama>{};
    for (final d in catalog.values) {
      if (d.imdb.isNotEmpty) byImdb[d.imdb] = d;
      byName[nk(d.en)] = d;
    }
    var lookups = 0;
    for (final r in rows) {
      final en = (r['en'] ?? '').toString();
      if (en.isEmpty) continue;
      final ru = (r['ru'] ?? '').toString();
      final im = (r['im'] ?? '').toString();
      final date = (r['date'] ?? '').toString();
      final year = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
      Drama? ex = (im.isNotEmpty ? byImdb[im] : null) ?? byName[nk(en)];
      if (ex == null) {
        Drama? nd;
        if (lookups < 25) {
          lookups++;
          nd = await Tvmaze.single(en, year);
          await Net.sleep(600);
        }
        nd ??= Drama(
          id: -(r['q'] as int),
          en: en, year: year, date: date,
          country: (r['c'] ?? '').toString(),
          status: 'Announced', imdb: im,
        );
        ex = _upsert(nd);
        byName[nk(en)] = ex;
        if (ex.imdb.isNotEmpty) byImdb[ex.imdb] = ex;
      }
      if (hasCyr(ru) && !custom.containsKey(ex.id) && dictLookup(ex.en) == null && trSrc[ex.id] != 'wiki') {
        tr[ex.id] = ru;
        trSrc[ex.id] = 'wiki';
      }
    }
    _poke();
  }

  Future<List<Drama>> searchOnline(String q) async {
    final r = await Tvmaze.search(q);
    final out = <Drama>[];
    for (final d in r) {
      final ex = find(d.id) ?? d;
      temp[ex.id] = ex;
      out.add(ex);
    }
    translator.ensureMany(out);
    return out;
  }

  void pin(Drama d) {
    if (!catalog.containsKey(d.id)) pinned[d.id] = d;
    _allCache = null;
  }

  void setList(Drama d, String? s) {
    pin(d);
    if (s == null) {
      listOf.remove(d.id);
    } else {
      listOf[d.id] = s;
      if (s == 'watch' && !prog.containsKey(d.id)) prog[d.id] = 0;
    }
    changed();
  }

  void setProg(Drama d, int v) { prog[d.id] = math.max(0, v); changed(); }

  void setRate(Drama d, int? v) {
    pin(d);
    if (v == null) { rate.remove(d.id); } else { rate[d.id] = v; }
    changed();
  }

  void setCustom(Drama d, String v) {
    final t = v.trim();
    if (t.isEmpty) { custom.remove(d.id); } else { custom[d.id] = t; }
    pin(d);
    changed();
  }

  void setSummary(Drama d, String text, String src) {
    sumRu[d.id] = text;
    sumSrc[d.id] = src;
    changed();
  }

  void setKey(String k) {
    OpenRouter.key = k.trim().isEmpty ? Cfg.orKey : k.trim();
    OpenRouter.resetErrors();
    changed();
  }

  void setWeb(bool v) { OpenRouter.webPlugin = v; changed(); }

  void retranslateAll() {
    tr.clear();
    trSrc.clear();
    tried.clear();
    OpenRouter.resetErrors();
    changed();
    translator.run();
  }

  Future<String> testAi() async {
    OpenRouter.resetErrors();
    final r = await OpenRouter.chat('Отвечай одним словом.', 'Скажи слово: готов');
    if (r == null) return 'ИИ недоступен: ${OpenRouter.lastError.isEmpty ? "нет ответа" : OpenRouter.lastError}. Работает встроенный переводчик.';
    return 'ИИ работает (${OpenRouter.lastModel}): $r';
  }

  List<Drama> browse({String? year, String? country, String? genre, String sort = 'new', String q = ''}) {
    final qq = q.trim().toLowerCase();
    final today = todayIso();
    final l = allDramas.where((d) {
      if (year == 'soon') {
        if (d.date.isEmpty || d.date.compareTo(today) <= 0) return false;
      } else if (year != null && d.year != int.tryParse(year)) return false;
      if (country != null && d.country != country) return false;
      if (genre != null && !d.genres.contains(genre)) return false;
      if (qq.length >= 2 && !ruTitle(d).toLowerCase().contains(qq) && !d.en.toLowerCase().contains(qq)) return false;
      return true;
    }).toList();
    if (year == 'soon') {
      l.sort((a, b) => a.date.compareTo(b.date));
    } else if (sort == 'top') {
      l.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    } else if (sort == 'az') {
      l.sort((a, b) => ruTitle(a).toLowerCase().compareTo(ruTitle(b).toLowerCase()));
    } else {
      l.sort((a, b) => b.date.compareTo(a.date));
    }
    return l;
  }

  List<Drama> upcoming() => browse(year: 'soon').take(30).toList();

  List<Drama> fresh() {
    final lim = DateTime.now().millisecondsSinceEpoch - 7 * 86400000;
    final l = allDramas.where((d) => d.seen > lim).toList();
    l.sort((a, b) => b.seen.compareTo(a.seen));
    return l.take(30).toList();
  }

  List<Drama> topYear() {
    final y = DateTime.now().year;
    final l = allDramas.where((d) => d.year == y && d.rating != null).toList();
    l.sort((a, b) => b.rating!.compareTo(a.rating!));
    return l.take(20).toList();
  }

  Set<String> genreSet() {
    final s = <String>{};
    for (final d in allDramas) {
      for (final g in d.genres) {
        if (Cfg.genres.containsKey(g)) s.add(g);
      }
    }
    return s;
  }

  List<Drama> listItems(String s) {
    final l = <Drama>[];
    listOf.forEach((id, v) {
      if (v == s) {
        final d = find(id);
        if (d != null) l.add(d);
      }
    });
    return l;
  }

  int get ruCount => allDramas.where((d) => hasRu(d)).length;
  int countSrc(String s) => trSrc.values.where((v) => v == s).length;

  String backup() => jsonEncode({
        'v': 1,
        'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate), 'custom': _sm(custom),
        'pinned': [
          ...pinned.values.map((d) => d.toJson()),
          ...listOf.keys.followedBy(rate.keys).map(find).whereType<Drama>().map((d) => d.toJson()),
        ],
      });

  bool restore(String s) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      listOf.addAll(_readMap<String>(m['list']));
      prog.addAll(_readMap<int>(m['prog']));
      rate.addAll(_readMap<int>(m['rate']));
      custom.addAll(_readMap<String>(m['custom']));
      if (m['pinned'] is List) {
        for (final e in m['pinned'] as List) {
          final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
          if (!catalog.containsKey(d.id)) pinned[d.id] = d;
        }
      }
      _allCache = null;
      changed();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Store store = Store();

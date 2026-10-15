import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'dict.dart';
import 'models.dart';
import 'net.dart';
import 'title_resolver.dart';
import 'translator.dart';
import 'tvmaze.dart';
import 'wiki.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _isoOf(DateTime n) => '${n.year}-${_two(n.month)}-${_two(n.day)}';
String todayIso() => _isoOf(DateTime.now());
String isoPlus(int days) => _isoOf(DateTime.now().add(Duration(days: days)));

class Store extends ChangeNotifier implements TrHost {
  SharedPreferences? _p;
  final Map<int, Drama> catalog = {};
  final Map<int, Drama> pinned = {};
  final Map<int, Drama> temp = {};
  final Map<int, String> listOf = {};
  final Map<int, int> prog = {};
  final Map<int, int> rate = {};
  final Map<int, String> notes = {};
  final Map<int, int> totals = {};
  @override final Map<int, String> custom = {};
  @override final Map<int, String> tr = {};
  @override final Map<int, String> trSrc = {};
  @override final Map<int, int> tried = {};
  final Map<String, String> actorRu = {};
  final Set<String> _actorBusy = {};
  final Map<int, String> sumRu = {};
  final Map<int, String> sumSrc = {};

  final Map<int, List<Ep>> epCache = {};
  final Map<String, List<LiveItem>> liveDays = {};
  final Map<String, int> _dayStamp = {};
  final Set<String> dayBusy = {};

  List<LiveItem> get live => liveDays[todayIso()] ?? const <LiveItem>[];

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
  Iterable<Drama> get allDramas { _allCache ??= _merge(); return _allCache!; }

  List<Drama> _merge() {
    final m = <int, Drama>{};
    m.addAll(pinned); m.addAll(catalog);
    return m.values.toList();
  }

  @override
  Set<int> get userIds => {...listOf.keys, ...rate.keys, ...notes.keys};

  @override
  void changed() { _saveSoon(); _poke(); }

  void _poke() {
    if (_notifyPending) return;
    _notifyPending = true;
    Timer(const Duration(milliseconds: 350), () {
      _notifyPending = false; notifyListeners();
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

  int get krCount => allDramas.where((d) => d.country == 'KR').length;
  int get krRuCount => allDramas.where((d) => d.country == 'KR' && hasRu(d)).length;

  String ruActor(String name) => actorRu[name] ?? name;

  // Имена актёров по-русски: сначала Википедия (точно), потом перевод.
  Future<void> ensureActorNames(List<String> names) async {
    final todo = names
        .where((n) => n.isNotEmpty && !actorRu.containsKey(n) && !_actorBusy.contains(n))
        .toSet().toList();
    if (todo.isEmpty) return;
    _actorBusy.addAll(todo);
    try {
      final res = await Wiki.actorsRu(todo);
      if (res != null) {
        for (final n in todo) {
          final ru = res[n.toLowerCase()];
          if (ru != null) actorRu[n] = ru;
        }
        changed();
      }
      var fails = 0;
      for (final n in todo) {
        if (actorRu.containsKey(n)) continue;
        final t = await Translator.gtx(n);
        if (t != null && hasCyr(t)) {
          actorRu[n] = t.trim();
        } else {
          fails++;
          if (fails >= 3) break;
        }
        await Net.sleep(150);
      }
      changed();
    } finally {
      _actorBusy.removeAll(todo);
    }
  }

  Drama? find(int id) => catalog[id] ?? pinned[id] ?? temp[id];

  Drama registerTemp(Drama d) {
    final ex = find(d.id) ?? d;
    temp[ex.id] = ex;
    return ex;
  }

  Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
      _load();
    } catch (_) {}
    await _loadSeed();
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
        notes.addAll(_readMap<String>(m['notes']));
        totals.addAll(_readMap<int>(m['totals']));
        custom.addAll(_readMap<String>(m['custom']));
        tr.addAll(_readMap<String>(m['tr']));
        trSrc.addAll(_readMap<String>(m['trSrc']));
        tried.addAll(_readMap<int>(m['tried']));
        sumRu.addAll(_readMap<String>(m['sumRu']));
        sumSrc.addAll(_readMap<String>(m['sumSrc']));
        if (m['actorRu'] is Map) {
          (m['actorRu'] as Map).forEach((k, v) { actorRu['$k'] = '$v'; });
        }
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
      } catch (_) {}
    }
    _allCache = null;
  }

  static const Map<String, int> _srcRank = {
    'local': 0, 'mt': 1, 'ai': 2, 'wiki': 3, 'kinopoisk': 6, 'user': 7,
  };
  int _rk(String? s) => _srcRank[s ?? 'local'] ?? 0;

  DateTime? _lastSync;
  bool _syncing = false;

  // База, упакованная в APK.
  Future<void> _loadSeed() async {
    try {
      final raw = await rootBundle.loadString('assets/seed_catalog.json');
      final m = jsonDecode(raw) as Map<String, dynamic>;
      await _applySeed(m, remote: false);
    } catch (_) {}
  }

  // Свежая база с сервера (обновляется каждые 2 дня без обновления APK).
  Future<void> syncCatalog() async {
    if (_syncing) return;
    final now = DateTime.now();
    final last = _lastSync;
    if (last != null && now.difference(last).inMinutes < 180 && catalog.isNotEmpty) return;
    _syncing = true;
    try {
      final meta = await Net.json(Uri.parse('${Cfg.dataBase}/meta.json'),
          retries: 1, timeout: const Duration(seconds: 20));
      _lastSync = now;
      if (meta is! Map) return;
      final built = (meta['built'] ?? '').toString();
      final have = _p?.getString('dp_seed') ?? '';
      if (built.isEmpty || (have.isNotEmpty && have.compareTo(built) >= 0 && catalog.isNotEmpty)) return;
      final r = await Net.get(Uri.parse('${Cfg.dataBase}/catalog.json'),
          retries: 1, timeout: const Duration(seconds: 120));
      if (r.code != 200 || r.data is! Map) return;
      await _applySeed(Map<String, dynamic>.from(r.data as Map), remote: true);
      translator.run();
    } catch (_) {
    } finally {
      _syncing = false;
    }
  }

  bool _isFresh(Drama d) => d.date.isNotEmpty && d.date.compareTo(isoPlus(-60)) >= 0;

  Future<bool> _applySeed(Map<String, dynamic> m, {required bool remote}) async {
    try {
      final built = (m['built'] ?? '').toString();
      final list = m['dramas'];
      if (built.isEmpty || list is! List || list.isEmpty) return false;
      final have = _p?.getString('dp_seed') ?? '';
      if (have.isNotEmpty && have.compareTo(built) >= 0 && catalog.isNotEmpty) return false;
      final firstFill = catalog.isEmpty;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      var announced = 0;
      for (final e in list) {
        final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
        final ex = catalog[d.id];
        if (ex == null) {
          d.seen = 0;
          if (remote && !firstFill && announced < 20 && _isFresh(d)) {
            d.seen = nowMs;
            newFinds.insert(0, d);
            announced++;
          }
          catalog[d.id] = d;
        } else {
          if (d.poster.isNotEmpty) ex.poster = d.poster;
          if (d.rating != null) ex.rating = d.rating;
          if (d.status.isNotEmpty) ex.status = d.status;
          if (d.date.isNotEmpty) { ex.date = d.date; ex.year = d.year; }
          if (d.genres.isNotEmpty) ex.genres = d.genres;
          if (d.imdb.isNotEmpty) ex.imdb = d.imdb;
          if (d.network.isNotEmpty) ex.network = d.network;
        }
      }
      final st = _readMap<String>(m['tr']);
      final ss = _readMap<String>(m['trSrc']);
      st.forEach((id, ru) {
        if (custom.containsKey(id)) return;
        final src = ss[id] ?? 'wiki';
        if (!tr.containsKey(id) || _rk(src) > _rk(trSrc[id])) {
          tr[id] = ru;
          trSrc[id] = src;
        }
      });
      final sm = _readMap<String>(m['sum']);
      sm.forEach((id, t) {
        if (!sumRu.containsKey(id)) { sumRu[id] = t; sumSrc[id] = 'mt'; }
      });
      final sMax = (m['scanMax'] ?? 0) as int;
      if (sMax > scanMax) scanMax = sMax;
      scanLow = 1; scanTarget = 1; seeded = true;
      _dedupeAnnounced();
      _allCache = null;
      await _p?.setString('dp_seed', built);
      changed();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Анонс без постера заменяем настоящей записью, когда она появилась в TVmaze.
  void _dedupeAnnounced() {
    final byImdb = <String, int>{};
    final byName = <String, int>{};
    for (final d in catalog.values) {
      if (d.id < 0) continue;
      if (d.imdb.isNotEmpty) byImdb[d.imdb] = d.id;
      byName[nk(d.en)] = d.id;
    }
    for (final d in catalog.values.toList()) {
      if (d.id >= 0) continue;
      final real = (d.imdb.isNotEmpty ? byImdb[d.imdb] : null) ?? byName[nk(d.en)];
      if (real == null) continue;
      _moveId(d.id, real);
      catalog.remove(d.id);
    }
  }

  void _moveId(int from, int to) {
    void mv<T>(Map<int, T> m) {
      final v = m.remove(from);
      if (v != null && !m.containsKey(to)) m[to] = v;
    }
    mv(listOf); mv(prog); mv(rate); mv(notes); mv(custom);
    mv(tr); mv(trSrc); mv(sumRu); mv(sumSrc);
    pinned.remove(from);
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
        'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate),
        'notes': _sm(notes), 'totals': _sm(totals),
        'custom': _sm(custom), 'tr': _sm(tr), 'trSrc': _sm(trSrc),
        'tried': _sm(tried), 'sumRu': _sm(sumRu), 'sumSrc': _sm(sumSrc),
        'actorRu': actorRu,
        'pinned': pinned.values.map((d) => d.toJson()).toList(),
        'scanMax': scanMax, 'scanLow': scanLow, 'scanTarget': scanTarget, 'seeded': seeded,
      }));
    } catch (_) {}
  }
  void saveNow() => _saveNow();

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true; lastError = ''; _poke();
    try {
      liveDays.removeWhere((k, _) => k.compareTo(todayIso()) < 0);
      if (catalog.isEmpty) { await syncCatalog(); } else { syncCatalog(); }
      await loadDay(todayIso(), force: true);
      translator.run();
      await scanCatalog();
      await discoverAnnounced();
      lastUpdate = DateTime.now();
      translator.run();
      _refreshWatchEps();
      _prefetchDays();
    } catch (e) {
      lastError = 'Ошибка обновления: $e';
    } finally {
      refreshing = false; _saveSoon(); _poke();
    }
  }

  Future<void> _prefetchDays() async {
    for (var i = 1; i < 7; i++) {
      await loadDay(isoPlus(i));
      await Net.sleep(300);
    }
  }

  Future<void> _refreshWatchEps() async {
    for (final d in listItems('watch').take(12)) {
      await ensureEpisodes(d);
      await Net.sleep(300);
    }
  }

  Drama _upsert(Drama d) {
    final ex = catalog[d.id];
    if (ex == null) {
      d.seen = seeded ? DateTime.now().millisecondsSinceEpoch : 0;
      catalog[d.id] = d; _allCache = null;
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

  // Расписание серий на конкретный день.
  Future<void> loadDay(String iso, {bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stamp = _dayStamp[iso];
    if (!force && stamp != null && now - stamp < 20 * 60000) return;
    if (dayBusy.contains(iso)) return;
    dayBusy.add(iso); _poke();
    try {
      final urls = <Uri>[
        Uri.parse('${Tvmaze.base}/schedule?country=KR&date=$iso'),
        Uri.parse('${Tvmaze.base}/schedule/web?date=$iso'),
      ];
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
        liveDays[iso] = m.values.toList()..sort((a, b) => a.time.compareTo(b.time));
        _dayStamp[iso] = now;
      }
    } finally {
      dayBusy.remove(iso); _poke();
    }
  }

  int airedCount(Drama d) {
    final l = epCache[d.id];
    if (l == null) return 0;
    final t = todayIso();
    return l.where((e) => e.airdate.isNotEmpty && e.airdate.compareTo(t) <= 0).length;
  }

  int newEps(Drama d) {
    if (!epCache.containsKey(d.id)) return 0;
    final n = airedCount(d) - (prog[d.id] ?? 0);
    return n > 0 ? n : 0;
  }

  Future<List<Ep>?> ensureEpisodes(Drama d, {bool force = false}) async {
    if (d.id < 0) return null;
    if (!force && epCache.containsKey(d.id)) return epCache[d.id];
    final l = await Tvmaze.episodes(d.id);
    if (l == null) return epCache[d.id];
    epCache[d.id] = l;
    if (l.isNotEmpty) {
      totals[d.id] = l.length;
      final p = prog[d.id];
      if (p != null && p > l.length) prog[d.id] = l.length;
    }
    changed();
    return l;
  }

  Future<void> scanCatalog() async {
    if (scanning) return;
    scanning = true; scanProgress = 0; _poke();
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
      if (s < 0) { lastError = 'Нет сети — показываем сохранённый каталог'; return; }
      if (s == 1) {
        lo = guess;
        while (true) {
          final p = lo + 10; s = await probe(p);
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
        final m = (lo + hi) ~/ 2; s = await probe(m);
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
        for (var p = scanLow - 1; p >= scanTarget; p--) { if (!pages.contains(p)) pages.add(p); }
      }

      Future<List<dynamic>?> fetchPage(int p) async {
        if (cache.containsKey(p)) return cache[p];
        final r = await Net.get(Uri.parse('${Tvmaze.base}/shows?page=$p'));
        if (r.code == 200 && r.data is List) return r.data as List;
        return null;
      }

      var done = 0; var incomplete = false;
      for (var i = 0; i < pages.length; i += 3) {
        final b = pages.sublist(i, math.min(i + 3, pages.length));
        final res = await Future.wait(b.map(fetchPage));
        var bad = 0;
        for (final l in res) {
          if (l == null) { bad++; continue; }
          for (final x in l) {
            final d = Tvmaze.parse(x, minYear: 0);
            if (d != null) _upsert(d);
          }
        }
        if (bad > 0) { lastError = 'Каталог загружен не полностью'; incomplete = true; break; }
        done += b.length; scanProgress = done / pages.length;
        if (firstRun) { scanMax = maxPage; scanLow = b.last; }
        if ((i ~/ 3) % 8 == 7) { translator.run(); _saveSoon(); }
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
      scanning = false; _poke();
    }
  }

  Future<void> discoverAnnounced() async {
    final from = DateTime.now().year;
    final rows = await Wiki.announced(from);
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
        if (lookups < 25) { lookups++; nd = await Tvmaze.single(en, year); await Net.sleep(600); }
        nd ??= Drama(
          id: -(r['q'] as int), en: en, year: year, date: date,
          country: 'KR', status: 'Announced', imdb: im,
        );
        ex = _upsert(nd);
        byName[nk(en)] = ex;
        if (ex.imdb.isNotEmpty) byImdb[ex.imdb] = ex;
      }
      if (hasCyr(ru) && !custom.containsKey(ex.id) && dictLookup(ex.en) == null && trSrc[ex.id] != 'kinopoisk') {
        tr[ex.id] = ru; trSrc[ex.id] = 'wiki';
      }
    }
    _poke();
  }

  Future<List<Map<String, dynamic>>> _safeMaps(Future<List<RuHit>?> f) async {
    try {
      final l = await f.timeout(const Duration(seconds: 25));
      if (l == null) return <Map<String, dynamic>>[];
      return l.map((h) => <String, dynamic>{'h': h}).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // Поиск: по-английски через TVmaze, по-русски через словарь, Википедию и Кинопоиск.
  Future<List<Drama>> searchOnline(String q) async {
    final out = <Drama>[];
    void add(Drama d) {
      final ex = registerTemp(d);
      if (!out.any((x) => x.id == ex.id)) out.add(ex);
    }

    if (hasCyr(q)) {
      final hits = <RuHit>[];
      for (final e in dictSearch(q)) { hits.add(RuHit(e[1], e[0], null, '', 'dict')); }
      final res = await Future.wait([
        _safeMaps(Wiki.searchRu(q)),
        _safeMaps(TitleResolver.searchRu(q)),
      ]);
      for (final l in res) {
        for (final m in l) { hits.add(m['h'] as RuHit); }
      }
      final seen = <String>{};
      var n = 0;
      for (final h in hits) {
        final key = h.imdb.isNotEmpty ? h.imdb : nk(h.en);
        if (key.isEmpty || !seen.add(key)) continue;
        if (++n > 8) break;
        final d = await Tvmaze.resolve(h.en, h.year, h.imdb);
        if (d == null) continue;
        add(d);
        if (h.src != 'dict' && hasCyr(h.ru) && !custom.containsKey(d.id) &&
            dictLookup(d.en) == null && trSrc[d.id] != 'kinopoisk') {
          tr[d.id] = h.ru; trSrc[d.id] = h.src;
        }
      }
    } else {
      for (final d in await Tvmaze.search(q)) { add(d); }
    }
    translator.ensureMany(out);
    changed();
    return out;
  }

  void pin(Drama d) { if (!catalog.containsKey(d.id)) pinned[d.id] = d; _allCache = null; }

  void setList(Drama d, String? s) {
    pin(d);
    if (s == null) {
      listOf.remove(d.id);
    } else {
      listOf[d.id] = s;
      if (s == 'watch') {
        if (!prog.containsKey(d.id)) prog[d.id] = 0;
        ensureEpisodes(d);
      }
    }
    changed();
  }

  void setProg(Drama d, int v) {
    var x = math.max(0, v);
    final t = totals[d.id];
    x = (t != null && t > 0) ? math.min(x, t) : math.min(x, 999);
    prog[d.id] = x;
    changed();
  }

  void finishWatching(Drama d) {
    final t = totals[d.id];
    if (t != null && t > 0) prog[d.id] = t;
    setList(d, 'done');
  }

  void setRate(Drama d, int? v) {
    pin(d);
    if (v == null) { rate.remove(d.id); } else { rate[d.id] = v; }
    changed();
  }

  void setCustom(Drama d, String v) {
    final t = v.trim();
    if (t.isEmpty) { custom.remove(d.id); } else { custom[d.id] = t; }
    pin(d); changed();
  }

  void setNote(Drama d, String v) {
    final t = v.trim();
    if (t.isEmpty) { notes.remove(d.id); } else { notes[d.id] = v; }
    pin(d); changed();
  }

  void setSummary(Drama d, String text, String src) {
    sumRu[d.id] = text; sumSrc[d.id] = src; changed();
  }

  List<Drama> browse({String? year, String? genre, String sort = 'new', String q = ''}) {
    final qq = q.trim().toLowerCase().replaceAll('ё', 'е');
    final today = todayIso();
    final l = allDramas.where((d) {
      if (d.country != 'KR') return false;
      if (year == 'soon') {
        if (d.date.isEmpty || d.date.compareTo(today) <= 0) return false;
      } else if (year == 'running') {
        if (d.status != 'Running') return false;
      } else if (year == 'old') {
        if (d.year == null || d.year! >= Cfg.minYear) return false;
      } else if (year != null && d.year != int.tryParse(year)) {
        return false;
      }
      if (genre != null && !d.genres.contains(genre)) return false;
      if (qq.length >= 2 &&
          !ruTitle(d).toLowerCase().replaceAll('ё', 'е').contains(qq) &&
          !d.en.toLowerCase().contains(qq)) return false;
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
    final l = allDramas.where((d) => d.country == 'KR' && d.seen > lim).toList();
    l.sort((a, b) => b.seen.compareTo(a.seen));
    return l.take(30).toList();
  }
  List<Drama> topYear() {
    final y = DateTime.now().year;
    final l = allDramas.where((d) => d.country == 'KR' && d.year == y && d.rating != null).toList();
    l.sort((a, b) => b.rating!.compareTo(a.rating!));
    return l.take(20).toList();
  }
  Set<String> genreSet() {
    final s = <String>{};
    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      for (final g in d.genres) { if (Cfg.genres.containsKey(g)) s.add(g); }
    }
    return s;
  }
  List<Drama> listItems(String s) {
    final l = <Drama>[];
    listOf.forEach((id, v) { if (v == s) { final d = find(id); if (d != null) l.add(d); } });
    return l;
  }

  // Подборка по настроению.
  List<Drama> pickByMood(List<String> genres, int seed) {
    final today = todayIso();
    final l = allDramas.where((d) {
      if (d.country != 'KR' || d.rating == null || d.rating! < 7.0) return false;
      if (listOf.containsKey(d.id)) return false;
      if (d.date.isNotEmpty && d.date.compareTo(today) > 0) return false;
      return d.genres.any((g) => genres.contains(g));
    }).toList();
    l.sort((a, b) => b.rating!.compareTo(a.rating!));
    final pool = l.take(40).toList();
    pool.shuffle(math.Random(seed));
    return pool.take(8).toList();
  }

  // Похожие дорамы: по общим жанрам, рейтингу и близости года.
  List<Drama> similar(Drama d) {
    if (d.genres.isEmpty) return <Drama>[];
    final gs = d.genres.toSet();
    final scored = <MapEntry<Drama, double>>[];
    for (final x in allDramas) {
      if (x.id == d.id || x.country != 'KR') continue;
      final shared = x.genres.where((g) => gs.contains(g)).length;
      if (shared == 0) continue;
      var sc = shared * 10.0 + (x.rating ?? 5.0);
      if (d.year != null && x.year != null) sc -= (d.year! - x.year!).abs() * 0.3;
      scored.add(MapEntry(x, sc));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(12).map((e) => e.key).toList();
  }

  // Любимые жанры по вашим спискам и оценкам.
  List<MapEntry<String, int>> topGenres() {
    final c = <String, int>{};
    for (final id in userIds) {
      final d = find(id);
      if (d == null) continue;
      final w = 1 + ((rate[id] ?? 0) >= 8 ? 1 : 0);
      for (final g in d.genres) {
        if (Cfg.genres.containsKey(g)) c[g] = (c[g] ?? 0) + w;
      }
    }
    final l = c.entries.toList();
    l.sort((a, b) => b.value.compareTo(a.value));
    return l.take(6).toList();
  }

  String backup() => jsonEncode({
    'v': 3,
    'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate), 'custom': _sm(custom),
    'notes': _sm(notes),
    'pinned': [
      ...pinned.values.map((d) => d.toJson()),
      ...userIds.map(find).whereType<Drama>().map((d) => d.toJson()),
    ],
  });

  bool restore(String s) {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      listOf.addAll(_readMap<String>(m['list']));
      prog.addAll(_readMap<int>(m['prog']));
      rate.addAll(_readMap<int>(m['rate']));
      custom.addAll(_readMap<String>(m['custom']));
      notes.addAll(_readMap<String>(m['notes']));
      if (m['pinned'] is List) {
        for (final e in m['pinned'] as List) {
          final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
          if (!catalog.containsKey(d.id)) pinned[d.id] = d;
        }
      }
      _allCache = null; changed();
      return true;
    } catch (_) { return false; }
  }
}

final Store store = Store();

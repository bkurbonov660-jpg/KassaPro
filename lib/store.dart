import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'data2026.dart';
import 'dict.dart';
import 'models.dart';
import 'net.dart';
import 'title_resolver.dart';
import 'translator.dart';
import 'tvmaze.dart';
import 'native.dart';
import 'wiki.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _isoOf(DateTime n) => '${n.year}-${_two(n.month)}-${_two(n.day)}';
String todayIso() => _isoOf(DateTime.now());
String isoPlus(int days) => _isoOf(DateTime.now().add(Duration(days: days)));

class _SafePrefs {
  final Map<String, String> _mem = <String, String>{};
  SharedPreferences? _sp;

  Future<void> init() async {
    try {
      final all = await Native.prefsAll();
      _mem.addAll(all);
    } catch (_) {}
    try {
      _sp = await SharedPreferences.getInstance();
      for (final k in _sp!.getKeys()) {
        final v = _sp!.get(k);
        if (v is String && !_mem.containsKey(k)) _mem[k] = v;
      }
    } catch (_) {}
  }

  String? getString(String key) {
    if (_mem.containsKey(key)) return _mem[key];
    try {
      return _sp?.getString(key);
    } catch (_) {
      return null;
    }
  }

  bool containsKey(String key) {
    if (_mem.containsKey(key)) return true;
    try {
      return _sp?.containsKey(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setString(String key, String value) async {
    _mem[key] = value;
    var ok = false;
    try {
      ok = await Native.prefWrite(key, value);
    } catch (_) {}
    try {
      if (_sp != null) {
        final r = await _sp!.setString(key, value);
        ok = ok || r;
      }
    } catch (_) {}
    return ok;
  }

  Future<bool> remove(String key) async {
    _mem.remove(key);
    var ok = false;
    try {
      ok = await Native.prefRemove(key);
    } catch (_) {}
    try {
      if (_sp != null) {
        final r = await _sp!.remove(key);
        ok = ok || r;
      }
    } catch (_) {}
    return ok;
  }
}

class Store extends ChangeNotifier implements TrHost {
  _SafePrefs? _p;
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
  final Map<String, List<AwardItem>> actorAwards = {};
  final Set<String> _awardBusy = {};
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

  // Сообщение разработчика, конфиг и план уведомлений приходят/хранятся отдельно от каталога.
  String noticeId = '', noticeText = '', noticeTitle = '';
  String _noticeClosed = '';
  final Map<String, dynamic> remoteCfg = {};
  final Map<String, int> plan = {};
  final Map<int, int> _epStamp = {};

  late final Translator translator = Translator(this);
  Timer? _timer, _saveT, _catT;
  bool _loaded = false;
  bool _hadStored = false, _userEdited = false;
  String? _fMine, _fCache, _fCat, _fScan;
  final Set<int> hidden = <int>{};
  final Map<String, List<String>> castByTitle = <String, List<String>>{};
  final Map<String, DateTime> _res26 = <String, DateTime>{};
  // Диагностика сохранения (показывается в профиле).
  String loadedFrom = '';
  DateTime? lastSaved;
  bool fileOk = false, prefsOk = false;
  String lastErr = '';
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
    if (trSrc[d.id] == 'fix') {
      final f = tr[d.id];
      if (f != null && f.isNotEmpty) return f;
    }
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

  // Быстрая загрузка личных данных: вызывается в main() до запуска интерфейса.
  Future<void> loadLocal() async {
    if (_loaded) return;
    actorRu.addAll(kActorsRu2026);
    kActorAwards.forEach((k, v) {
      actorAwards.putIfAbsent(k, () => List<AwardItem>.from(v));
    });
    try {
      final sp = _SafePrefs();
      await sp.init();
      _p = sp;
    } catch (_) {}
    try {
      _fMine = await Native.fileRead('mine.json');
      _fCache = await Native.fileRead('cache.json');
      _fCat = await Native.fileRead('catalog.json');
      _fScan = await Native.fileRead('scan.json');
    } catch (_) {}
    try {
      _load();
    } catch (_) {}
    _loaded = true;
    await _saveMine();
  }

  Future<void> init() async {
    await loadLocal();
    await _loadSeed();
    seed2026();
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

  // Из нескольких копий личных данных выбираем самую свежую: файл, prefs, резервная копия.
  Map<String, dynamic>? _pickMine() {
    final cands = <Map<String, dynamic>?>[
      _decodeMap(_fMine),
      _decodeMap(_p?.getString('dp_mine')),
      _decodeMap(_p?.getString('dp_mine_bak')),
    ];
    Map<String, dynamic>? best;
    var bs = -1;
    var bn = -1;
    var idx = 0;
    for (final c in cands) {
      idx++;
      if (c == null) continue;
      final tsv = c['ts'];
      final ts = tsv is int ? tsv : 0;
      final lv = c['list'];
      final n = lv is Map ? lv.length : 0;
      if (ts > bs || (ts == bs && n > bn)) {
        best = c;
        bs = ts;
        bn = n;
        loadedFrom = idx == 1 ? 'файл' : (idx == 2 ? 'prefs' : 'резервная копия');
      }
    }
    return best;
  }

  void _tryLoad(void Function() f) {
    try {
      f();
    } catch (_) {}
  }

  Map<String, dynamic>? _decodeMap(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final v = jsonDecode(s);
      if (v is Map) return Map<String, dynamic>.from(v);
    } catch (_) {}
    return null;
  }

  void _loadMineFrom(Map<String, dynamic> m) {
    _tryLoad(() => listOf.addAll(_readMap<String>(m['list'])));
    _tryLoad(() => prog.addAll(_readMap<int>(m['prog'])));
    _tryLoad(() => rate.addAll(_readMap<int>(m['rate'])));
    _tryLoad(() => notes.addAll(_readMap<String>(m['notes'])));
    _tryLoad(() => totals.addAll(_readMap<int>(m['totals'])));
    _tryLoad(() => custom.addAll(_readMap<String>(m['custom'])));
    _tryLoad(() {
      final h = m['hide'];
      if (h is List) {
        for (final x in h) {
          if (x is int) hidden.add(x);
        }
      }
    });
    _tryLoad(() {
      final pl = m['pinned'];
      if (pl is List) {
        for (final e in pl) {
          if (e is Map) {
            final d = Drama.fromJson(Map<String, dynamic>.from(e));
            pinned[d.id] = d;
          }
        }
      }
    });
  }

  void _loadScanFrom(Map<String, dynamic> m) {
    _tryLoad(() {
      scanMax = (m['scanMax'] ?? 0) as int;
      scanLow = (m['scanLow'] ?? 0) as int;
      scanTarget = (m['scanTarget'] ?? 0) as int;
      seeded = (m['seeded'] ?? false) as bool;
    });
  }

  void _load() {
    final raw = _fCat ?? _p?.getString('dp_catalog');
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
          catalog[d.id] = d;
        }
      } catch (_) {}
    }
    // Кэш переводов (старый ключ dp_user; в старых версиях там же лежали и личные данные).
    final u = _decodeMap(_fCache ?? _p?.getString('dp_user'));
    if (u != null) {
      _tryLoad(() => tr.addAll(_readMap<String>(u['tr'])));
      _tryLoad(() => trSrc.addAll(_readMap<String>(u['trSrc'])));
      _tryLoad(() => tried.addAll(_readMap<int>(u['tried'])));
      _tryLoad(() => sumRu.addAll(_readMap<String>(u['sumRu'])));
      _tryLoad(() => sumSrc.addAll(_readMap<String>(u['sumSrc'])));
      _tryLoad(() {
        final a = u['actorRu'];
        if (a is Map) {
          a.forEach((k, v) {
            actorRu['$k'] = '$v';
          });
        }
        _readAwardsMap(u['awards']);
      });
      _loadScanFrom(u);
      _loadMineFrom(u);
    }
    final sc = _decodeMap(_fScan ?? _p?.getString('dp_scan'));
    if (sc != null) _loadScanFrom(sc);
    // Личные данные: отдельный компактный ключ + резервная копия предыдущей записи.
    final mine = _pickMine();
    if (mine != null) {
      _hadStored = true;
      hidden.clear();
      listOf.clear(); prog.clear(); rate.clear(); notes.clear();
      totals.clear(); custom.clear(); pinned.clear();
      _loadMineFrom(mine);
    }
    try {
      _noticeClosed = _p?.getString('dp_notice_closed') ?? '';
      final nraw = _p?.getString('dp_notice');
      if (nraw != null) {
        final nm = jsonDecode(nraw);
        if (nm is Map) {
          noticeId = (nm['id'] ?? '').toString();
          noticeText = (nm['text'] ?? '').toString();
          noticeTitle = (nm['title'] ?? '').toString();
        }
      }
      final craw = _p?.getString('dp_rcfg');
      if (craw != null) {
        final cm = jsonDecode(craw);
        if (cm is Map) remoteCfg.addAll(Map<String, dynamic>.from(cm));
      }
      final praw = _p?.getString('dp_plan');
      if (praw != null) {
        final pm = jsonDecode(praw);
        if (pm is Map) {
          pm.forEach((k, v) { if (v is int) plan['$k'] = v; });
        }
      }
    } catch (_) {}
    if (listOf.isNotEmpty || rate.isNotEmpty || prog.isNotEmpty || notes.isNotEmpty) _hadStored = true;
    // Каталог не сохранился — сканируем заново; личные дорамы держим в pinned.
    if (catalog.isEmpty) {
      scanMax = 0; scanLow = 0; scanTarget = 0; seeded = false;
    }
    for (final id in userIds) {
      final d = catalog[id];
      if (d != null) pinned.putIfAbsent(id, () => d);
    }
    _allCache = null;
  }

  static const Map<String, int> _srcRank = {
    'local': 0, 'mt': 1, 'ai': 2, 'wiki': 3, 'kinopoisk': 6, 'user': 7, 'fix': 8,
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
      _applyNotice(Map<String, dynamic>.from(meta));
      final built = (meta['built'] ?? '').toString();
      final have = _p?.getString('dp_seed') ?? '';
      if (built.isEmpty || (have.isNotEmpty && have.compareTo(built) >= 0 && catalog.isNotEmpty)) return;
      final r = await Net.get(Uri.parse('${Cfg.dataBase}/catalog.json'),
          retries: 1, timeout: const Duration(seconds: 300));
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
      _applyNotice(m);
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
      final aRu = m['actorRu'];
      if (aRu is Map) {
        aRu.forEach((k, v) {
          if ('$v'.trim().isNotEmpty) actorRu['$k'] = '$v';
        });
      }
      _readAwardsMap(m['awards']);
      scanLow = 1; scanTarget = 1; seeded = true;
      seed2026();
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
    _saveT = Timer(const Duration(milliseconds: 700), () { _saveMine(); });
    final ct = _catT;
    if (ct == null || !ct.isActive) {
      _catT = Timer(const Duration(seconds: 15), () { _saveNow(); });
    }
  }

  // Личные данные: списки, прогресс, оценки, заметки. Пишутся в ФАЙЛ и в prefs одновременно.
  bool _mineRun = false, _mineAgain = false;

  Future<void> _saveMine() async {
    if (_mineRun) {
      _mineAgain = true;
      return;
    }
    _mineRun = true;
    try {
      do {
        _mineAgain = false;
        await _saveMineOnce();
      } while (_mineAgain);
    } finally {
      _mineRun = false;
    }
  }

  Future<void> _saveMineOnce() async {
    if (!_loaded) return;
    final empty = listOf.isEmpty && rate.isEmpty && prog.isEmpty && notes.isEmpty && custom.isEmpty;
    if (empty && _hadStored && !_userEdited) return;
    final s = jsonEncode({
      'v': 3, 'ts': DateTime.now().millisecondsSinceEpoch,
      'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate),
      'notes': _sm(notes), 'totals': _sm(totals), 'custom': _sm(custom),
      'hide': hidden.toList(),
      'pinned': pinned.values.map((d) => d.toJson()).toList(),
    });
    var okF = false;
    var okP = false;
    try {
      okF = await Native.fileWrite('mine.json', s);
    } catch (_) {}
    final p = _p;
    if (p != null) {
      try {
        final old = p.getString('dp_mine');
        if (old != null && old != s && old.length > 20) {
          await p.setString('dp_mine_bak', old);
        }
        okP = await p.setString('dp_mine', s);
      } catch (_) {}
    }
    fileOk = okF;
    prefsOk = okP;
    if (okF || okP) {
      lastSaved = DateTime.now();
      _hadStored = true;
      lastErr = '';
    }
  }

  // Большие данные — в файл; если файл недоступен, то в prefs.
  Future<bool> _saveBig(String name, String prefKey, String s) async {
    var ok = false;
    try {
      ok = await Native.fileWrite(name, s);
    } catch (_) {}
    if (ok) {
      if (lastSaved != null && _p != null && _p!.containsKey(prefKey)) {
        try {
          await _p!.remove(prefKey);
        } catch (_) {}
      }
      return true;
    }
    try {
      if (_p != null) ok = await _p!.setString(prefKey, s);
    } catch (_) {}
    return ok;
  }

  void _readAwardsMap(dynamic raw) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final key = nk(k.toString());
      if (key.isEmpty || v is! List) return;
      final list = <AwardItem>[];
      for (final x in v) {
        if (x is Map) {
          final it = AwardItem.fromJson(Map<String, dynamic>.from(x));
          if (it.award.isNotEmpty) list.add(it);
        }
      }
      if (list.isNotEmpty) {
        final existing = actorAwards[key] ?? <AwardItem>[];
        final seen = existing.map((e) => '${e.year}|${nk(e.award)}').toSet();
        final merged = List<AwardItem>.from(existing);
        for (final it in list) {
          if (seen.add('${it.year}|${nk(it.award)}')) merged.add(it);
        }
        merged.sort((a, b) => b.year.compareTo(a.year));
        actorAwards[key] = merged;
      }
    });
  }

  // Кэш: переводы названий и описаний.
  Future<void> _saveCache() async {
    if (!_loaded) return;
    try {
      await _saveBig('cache.json', 'dp_user', jsonEncode({
        'tr': _sm(tr), 'trSrc': _sm(trSrc), 'tried': _sm(tried),
        'sumRu': _sm(sumRu), 'sumSrc': _sm(sumSrc), 'actorRu': actorRu,
        'awards': actorAwards.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      }));
    } catch (_) {}
  }

  // Каталог и состояние сканирования: состояние пишется только после успешной записи каталога.
  Future<void> _saveCatalog() async {
    if (!_loaded) return;
    try {
      final ok = await _saveBig('catalog.json', 'dp_catalog',
          jsonEncode(catalog.values.map((d) => d.toJson()).toList()));
      if (ok) {
        await _saveBig('scan.json', 'dp_scan', jsonEncode({
          'scanMax': scanMax, 'scanLow': scanLow, 'scanTarget': scanTarget, 'seeded': seeded,
        }));
      }
    } catch (_) {}
  }

  Future<void> _saveNow() async {
    await _saveMine();
    await _saveCache();
    await _saveCatalog();
  }

  void saveNow() => _saveNow();

  // Вызывается при сворачивании приложения: личные данные пишутся сразу.
  Future<void> flush({bool all = false}) async {
    _saveT?.cancel();
    await _saveMine();
    if (all) {
      await _saveCache();
      await _saveCatalog();
    }
  }

  // ── Дорамы 2026: встроенный список, расписание TVmaze за каждый день года, поиск настоящих записей ──
  void seed2026() {
    actorRu.addAll(kActorsRu2026);
    kActorAwards.forEach((k, v) {
      actorAwards.putIfAbsent(k, () => List<AwardItem>.from(v));
    });
    final byName = <String, Drama>{};
    for (final d in allDramas) {
      byName[nk(d.en)] = d;
    }
    var added = false;
    for (final row in k2026) {
      final p = row.split('|');
      if (p.length < 4) continue;
      final en = p[0].trim();
      final key = nk(en);
      if (key.isEmpty) continue;
      final net = p[1].trim();
      final date = p[2].trim();
      final stc = p[3].trim();
      if (p.length > 4 && p[4].trim().isNotEmpty) {
        castByTitle[key] = p[4].split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      final year = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
      final future = date.compareTo(todayIso()) > 0;
      final status = stc == 'O' ? 'Running' : (stc == 'A' || future ? 'Announced' : 'Ended');
      final rich = kRich2026[key];
      Drama? ex = byName[key];
      if (ex != null) {
        if (ex.network.isEmpty || (rich != null && ex.network == 'KBS2')) ex.network = net;
        if (ex.date.isEmpty) {
          ex.date = date;
          ex.year = year;
        }
        if (rich != null) ex.status = status;
      } else {
        final id = -(2000000000 + (int.parse(_fnv(key), radix: 16) % 90000000));
        if (!catalog.containsKey(id)) {
          ex = Drama(id: id, en: en, year: year, date: date, country: 'KR', status: status, network: net);
          catalog[id] = ex;
          byName[key] = ex;
          added = true;
        } else {
          ex = catalog[id];
        }
      }
      if (ex != null && rich != null) {
        if (ex.genres.isEmpty && rich.genres.isNotEmpty) ex.genres = rich.genres;
        if (ex.rating == null && rich.rating != null) ex.rating = rich.rating;
        if (ex.poster.isEmpty && rich.poster.isNotEmpty) ex.poster = rich.poster;
        if (rich.ruTitle.isNotEmpty && !custom.containsKey(ex.id)) {
          tr[ex.id] = rich.ruTitle;
          trSrc[ex.id] = 'fix';
        }
        if (rich.summary.isNotEmpty && !sumRu.containsKey(ex.id)) {
          sumRu[ex.id] = rich.summary;
          sumSrc[ex.id] = 'fix';
        }
        if (rich.episodes > 0) {
          totals[ex.id] = rich.episodes;
          if (!epCache.containsKey(ex.id)) {
            epCache[ex.id] = List<Ep>.generate(
              rich.episodes,
              (i) => Ep(1, i + 1, 'Серия ${i + 1}', date, ''),
            );
          }
        }
      }
    }
    if (added) {
      _dedupeAnnounced();
      _allCache = null;
      changed();
    }
  }

  String _dramaKey(Drama d) {
    final k = nk(d.en);
    if (kCast2026.containsKey(k) || castByTitle.containsKey(k)) return k;
    final rt = ruTitle(d).toLowerCase().replaceAll('ё', 'е');
    if (rt.contains('подзаряди') || k.contains('takecharge') || k.contains('rechargeme') || k.contains('chargeme')) {
      return 'takechargeofmyheart';
    }
    return k;
  }

  List<String> castOf(Drama d) => castByTitle[_dramaKey(d)] ?? const <String>[];

  List<Actor> richCastOf(Drama d) {
    final key = _dramaKey(d);
    final rich = kCast2026[key];
    if (rich != null && rich.isNotEmpty) return rich;
    final names = castByTitle[key];
    if (names == null || names.isEmpty) return const <Actor>[];
    return [
      for (var i = 0; i < names.length; i++)
        Actor(-(1000 + i), names[i], '', ''),
    ];
  }

  List<AwardItem> awardsOf(String name) {
    final key = nk(name);
    return actorAwards[key] ?? kActorAwards[key] ?? const <AwardItem>[];
  }

  Future<List<AwardItem>> ensureActorAwards(String name) async {
    final key = nk(name);
    if (key.isEmpty) return const <AwardItem>[];
    final base = List<AwardItem>.from(awardsOf(name));
    if ( base.isNotEmpty && !actorAwards.containsKey(key) ) {
      actorAwards[key] = base;
    }
    if (_awardBusy.contains(key)) return actorAwards[key] ?? base;
    _awardBusy.add(key);
    try {
      final rows = await Wiki.actorAwards(name);
      if (rows != null && rows.isNotEmpty) {
        final seen = (actorAwards[key] ?? base).map((e) => '${e.year}|${nk(e.award)}').toSet();
        final merged = List<AwardItem>.from(actorAwards[key] ?? base);
        for (final r in rows.take(16)) {
          final yr = (r['y'] ?? '').trim();
          var aw = (r['aRu'] ?? '').trim();
          final awEn = (r['aEn'] ?? '').trim();
          if (aw.isEmpty && awEn.isNotEmpty) {
            final t = await Translator.gtx(awEn);
            aw = (t != null && hasCyr(t)) ? t.trim() : awEn;
          }
          if (aw.isEmpty) continue;
          var wk = (r['wRu'] ?? '').trim();
          final wkEn = (r['wEn'] ?? '').trim();
          if (wk.isEmpty && wkEn.isNotEmpty) {
            wk = dictLookup(wkEn) ?? '';
            if (wk.isEmpty) {
              final t = await Translator.gtx(wkEn);
              wk = (t != null && hasCyr(t)) ? t.trim() : wkEn;
            }
          }
          final sig = '$yr|${nk(aw)}';
          if (!seen.add(sig)) continue;
          final why = wk.isNotEmpty
              ? 'За яркую роль и актёрское мастерство в проекте «$wk»'
              : 'За выдающееся актёрское мастерство и признание зрителей';
          merged.add(AwardItem(yr.isEmpty ? 'Награда' : yr, aw, why));
        }
        merged.sort((a, b) => b.year.compareTo(a.year));
        actorAwards[key] = merged;
        changed();
      }
    } catch (_) {
    } finally {
      _awardBusy.remove(key);
    }
    return actorAwards[key] ?? base;
  }

  Future<List<Drama>> actorDramasFor(Actor actor) async {
    final target = nk(actor.name);
    final out = <Drama>[];
    final seen = <String>{};
    void addDrama(Drama d) {
      final ex = registerTemp(d);
      final k = nk(ex.en);
      if (k.isNotEmpty && seen.add(k)) out.add(ex);
    }

    // 1. Встроенная фильмография и каталог приложения
    final byKey = <String, Drama>{};
    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      byKey[nk(d.en)] = d;
      if (castOf(d).any((n) => nk(n) == target) ||
          richCastOf(d).any((a) => nk(a.name) == target)) {
        addDrama(d);
      }
    }
    final known = kActorDramas[target] ?? const <String>[];
    final missingKnown = <String>[];
    for (final en in known) {
      final ex = byKey[nk(en)];
      if (ex != null) {
        addDrama(ex);
      } else {
        missingKnown.add(en);
      }
    }

    // 2. Поиск фильмографии в TVmaze (с дефисом и без дефиса)
    var pid = actor.id;
    if (pid <= 0) {
      final (foundId, _) = await Tvmaze.findPerson(actor.name);
      if (foundId != null) pid = foundId;
    }
    if (pid > 0) {
      final tvList = await Tvmaze.actorShows(pid);
      for (final d in tvList) {
        addDrama(d);
      }
    }

    // 3. Догружаем известные дорамы актёра из TVmaze, если их ещё не было в локальном кэше
    for (final en in missingKnown.take(8)) {
      if (seen.contains(nk(en))) continue;
      final resolved = await Tvmaze.resolve(en, null, '');
      if (resolved != null) {
        addDrama(resolved);
      } else {
        final id = -(1900000000 + (int.parse(_fnv(nk(en)), radix: 16) % 90000000));
        final d = Drama(id: id, en: en, country: 'KR', status: 'Ended');
        final ru = dictLookup(en);
        if (ru != null) {
          tr[id] = ru;
          trSrc[id] = 'fix';
        }
        addDrama(d);
      }
    }

    // 4. Фильмография из Wikidata
    final wRows = await Wiki.actorShows(actor.name);
    if (wRows != null) {
      for (final r in wRows) {
        final en = (r['en'] ?? '').toString();
        final k = nk(en);
        if (k.isEmpty || seen.contains(k)) continue;
        final ex = byKey[k];
        if (ex != null) {
          addDrama(ex);
          continue;
        }
        final date = (r['date'] ?? '').toString();
        final yr = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
        final qn = (r['q'] as int?) ?? en.hashCode.abs();
        final nd = Drama(
          id: -qn,
          en: en,
          year: yr,
          date: date,
          country: 'KR',
          imdb: (r['im'] ?? '').toString(),
          status: 'Ended',
        );
        final ru = (r['ru'] ?? '').toString();
        if (hasCyr(ru)) {
          tr[nd.id] = ru;
          trSrc[nd.id] = 'wiki';
        }
        addDrama(nd);
      }
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    translator.ensureMany(out);
    return out;
  }

  Drama _upsertQuiet(Drama d) {
    final ex = catalog[d.id];
    if (ex == null) {
      d.seen = 0;
      catalog[d.id] = d;
      _allCache = null;
      return d;
    }
    return _upsert(d);
  }

  String _nextIso(String iso) {
    final y = int.tryParse(iso.substring(0, 4)) ?? 2026;
    final m = int.tryParse(iso.substring(5, 7)) ?? 1;
    final dd = int.tryParse(iso.substring(8, 10)) ?? 1;
    return _isoOf(DateTime.utc(y, m, dd).add(const Duration(days: 1)));
  }

  DateTime? _wrap26;

  Future<void> crawl2026() async {
    final p = _p;
    var cur = p?.getString('dp_crawl26') ?? '2026-01-01';
    var limit = isoPlus(45);
    if (limit.compareTo('2026-12-31') > 0) limit = '2026-12-31';
    if (cur.compareTo(limit) > 0) {
      final w = _wrap26;
      if (w != null && DateTime.now().difference(w).inHours < 6) return;
      _wrap26 = DateTime.now();
      cur = todayIso();
    }
    var n = 0;
    while (cur.compareTo(limit) <= 0 && n < 30) {
      final urls = <Uri>[
        Uri.parse('${Tvmaze.base}/schedule?country=KR&date=$cur'),
        Uri.parse('${Tvmaze.base}/schedule/web?date=$cur'),
      ];
      final res = await Future.wait(urls.map((u) => Net.json(u)));
      for (final r in res) {
        if (r is! List) continue;
        for (final e in r) {
          if (e is! Map) continue;
          dynamic show = e['show'];
          if (show == null && e['_embedded'] is Map) show = (e['_embedded'] as Map)['show'];
          final d = Tvmaze.parse(show);
          if (d != null) _upsertQuiet(d);
        }
      }
      cur = _nextIso(cur);
      n++;
      await Net.sleep(250);
    }
    await p?.setString('dp_crawl26', cur);
    _dedupeAnnounced();
    _allCache = null;
    _poke();
  }

  Future<void> resolve2026() async {
    final now = DateTime.now();
    var n = 0;
    for (final d in catalog.values.toList()) {
      if (d.id >= 0 || (d.year ?? 0) < 2025) continue;
      final last = _res26[d.en];
      if (last != null && now.difference(last).inHours < 6) continue;
      if (n >= 12) break;
      n++;
      _res26[d.en] = now;
      final real = await Tvmaze.resolve(d.en, d.year, d.imdb);
      await Net.sleep(350);
      if (real == null || real.id < 0) continue;
      final ex = _upsertQuiet(real);
      if (ex.id != d.id) {
        _moveId(d.id, ex.id);
        catalog.remove(d.id);
      }
    }
    _allCache = null;
    _poke();
  }

  void hide(Drama d) {
    hidden.add(d.id);
    _userEdited = true;
    changed();
    _saveMine();
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true; lastError = ''; _poke();
    try {
      liveDays.removeWhere((k, _) => k.compareTo(todayIso()) < 0);
      syncRemote();
      if (catalog.isEmpty) { await syncCatalog(); } else { syncCatalog(); }
      await loadDay(todayIso(), force: true);
      translator.run();
      await scanCatalog();
      await discoverAnnounced();
      seed2026();
      await crawl2026();
      await resolve2026();
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
    for (final d in listItems('watch').take(40)) {
      final age = DateTime.now().millisecondsSinceEpoch - (_epStamp[d.id] ?? 0);
      await ensureEpisodes(d, force: age > 6 * 3600000);
      await Net.sleep(250);
    }
    scheduleNotifSoon();
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
    _epStamp[d.id] = DateTime.now().millisecondsSinceEpoch;
    if (listOf[d.id] == 'watch') scheduleNotifSoon();
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
        final depth = math.max(20, math.min(600, cfgInt('scanDepth', Cfg.scanDepth)));
        scanTarget = math.max(1, maxPage - depth + 1);
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
    final rows = <Map<String, dynamic>>[];
    for (var off = 0; off < 3600; off += 1200) {
      final part = await Wiki.announced(from, limit: 1200, offset: off);
      if (part == null) {
        if (off == 0) return;
        break;
      }
      rows.addAll(part);
      if (part.isEmpty) break;
    }
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
      if (hasCyr(ru) && !custom.containsKey(ex.id) && dictLookup(ex.en) == null &&
          trSrc[ex.id] != 'kinopoisk' && trSrc[ex.id] != 'fix') {
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
            dictLookup(d.en) == null && trSrc[d.id] != 'kinopoisk' && trSrc[d.id] != 'fix') {
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

  void pin(Drama d) { pinned[d.id] = d; _userEdited = true; _allCache = null; }

  void setList(Drama d, String? s) {
    pin(d);
    if (s == null) {
      listOf.remove(d.id);
    } else {
      listOf[d.id] = s;
      if (s == 'watch') {
        if (!prog.containsKey(d.id)) prog[d.id] = 0;
        ensureEpisodes(d);
        Native.notifPermission();
      }
    }
    changed();
    _saveMine();
    scheduleNotifSoon();
  }

  void setProg(Drama d, int v) {
    var x = math.max(0, v);
    final t = totals[d.id];
    x = (t != null && t > 0) ? math.min(x, t) : math.min(x, 999);
    prog[d.id] = x;
    _userEdited = true;
    changed();
    _saveMine();
    scheduleNotifSoon();
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
    _saveMine();
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
    final qq = q.trim().toLowerCase().replaceAll('ё', 'е').replaceAll('подзариди', 'подзаряди').replaceAll('зариди', 'заряди');
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

  // ── Тихая докачка (OTA): сообщение разработчика, исправления названий и описаний, конфиг ──
  static String _fnv(String s) {
    var h = 0x811c9dc5;
    for (final u in s.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  bool get noticeVisible => noticeText.isNotEmpty && noticeId != _noticeClosed;

  void closeNotice() {
    _noticeClosed = noticeId;
    _p?.setString('dp_notice_closed', noticeId);
    notifyListeners();
  }

  int cfgInt(String k, int def) {
    final v = remoteCfg[k];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  void _applyNotice(Map<String, dynamic> m, {bool authoritative = false}) {
    dynamic raw = m['notice'];
    if (raw == null || (raw is String && raw.trim().isEmpty)) raw = m['dev_message'];
    var text = '';
    var id = '';
    var title = '';
    if (raw is String) {
      text = raw.trim();
    } else if (raw is Map) {
      text = (raw['text'] ?? raw['message'] ?? raw['body'] ?? '').toString().trim();
      id = (raw['id'] ?? '').toString();
      title = (raw['title'] ?? '').toString().trim();
    }
    if (text.isEmpty) {
      if (authoritative && noticeText.isNotEmpty) {
        noticeText = ''; noticeId = ''; noticeTitle = '';
        _p?.remove('dp_notice');
        notifyListeners();
      }
      return;
    }
    if (id.isEmpty) id = _fnv(text);
    if (id == noticeId && text == noticeText && title == noticeTitle) return;
    noticeText = text; noticeId = id; noticeTitle = title;
    _p?.setString('dp_notice', jsonEncode({'id': id, 'text': text, 'title': title}));
    notifyListeners();
  }

  DateTime? _lastRemote;

  // remote.json: {"notice": "...", "fix": {"titles": {...}, "summaries": {...}}, "config": {...}}
  Future<void> syncRemote({bool force = false}) async {
    final now = DateTime.now();
    final last = _lastRemote;
    if (!force && last != null && now.difference(last).inMinutes < 30) return;
    _lastRemote = now;
    try {
      final j = await Net.json(Uri.parse('${Cfg.dataBase}/remote.json'),
          retries: 1, timeout: const Duration(seconds: 300));
      if (j is! Map) return;
      final m = Map<String, dynamic>.from(j);
      _applyNotice(m, authoritative: true);
      final cfg = m['config'];
      if (cfg is Map) {
        remoteCfg..clear()..addAll(Map<String, dynamic>.from(cfg));
        await _p?.setString('dp_rcfg', jsonEncode(remoteCfg));
      }
      final fix = m['fix'];
      if (fix is! Map) return;
      final byImdb = <String, Drama>{};
      final byName = <String, Drama>{};
      for (final d in allDramas) {
        if (d.imdb.isNotEmpty) byImdb[d.imdb] = d;
        byName[nk(d.en)] = d;
      }
      Drama? look(String k) {
        final key = k.trim();
        if (key.isEmpty) return null;
        final id = int.tryParse(key);
        if (id != null) return find(id);
        if (key.startsWith('tt')) return byImdb[key];
        return byName[nk(key)];
      }
      var any = false;
      final ft = fix['titles'];
      if (ft is Map) {
        ft.forEach((k, v) {
          final ru = v.toString().trim();
          if (ru.isEmpty || !hasCyr(ru)) return;
          final d = look(k.toString());
          if (d == null || custom.containsKey(d.id)) return;
          if (tr[d.id] != ru || trSrc[d.id] != 'fix') {
            tr[d.id] = ru; trSrc[d.id] = 'fix'; any = true;
          }
        });
      }
      final fs = fix['summaries'];
      if (fs is Map) {
        fs.forEach((k, v) {
          final t = v.toString().trim();
          if (t.isEmpty) return;
          final d = look(k.toString());
          if (d == null) return;
          if (sumRu[d.id] != t || sumSrc[d.id] != 'fix') {
            sumRu[d.id] = t; sumSrc[d.id] = 'fix'; any = true;
          }
        });
      }
      if (any) { _allCache = null; changed(); }
    } catch (_) {}
    try {
      final aw = await Net.json(Uri.parse('${Cfg.dataBase}/actors_awards.json'),
          retries: 1, timeout: const Duration(seconds: 60));
      if (aw is Map) {
        final aRu = aw['actorRu'];
        if (aRu is Map) {
          aRu.forEach((k, v) {
            if ('$v'.trim().isNotEmpty) actorRu['$k'] = '$v';
          });
        }
        _readAwardsMap(aw['awards']);
        changed();
      }
    } catch (_) {}
  }

  // ── Уведомления о новых сериях (локальные, через AlarmManager) ──
  Timer? _notifT;

  void scheduleNotifSoon() {
    _notifT?.cancel();
    _notifT = Timer(const Duration(seconds: 4), () { rebuildNotifications(); });
  }

  int? _epMoment(Ep e, int hour) {
    if (e.airdate.length < 10) return null;
    final y = int.tryParse(e.airdate.substring(0, 4));
    final mo = int.tryParse(e.airdate.substring(5, 7));
    final dd = int.tryParse(e.airdate.substring(8, 10));
    if (y == null || mo == null || dd == null) return null;
    final parts = e.time.split(':');
    if (parts.length >= 2) {
      final hh = int.tryParse(parts[0]);
      final mm = int.tryParse(parts[1]);
      if (hh != null && mm != null) {
        // Время выхода в TVmaze указано по Корее (UTC+9).
        return DateTime.utc(y, mo, dd, hh, mm).subtract(const Duration(hours: 9)).millisecondsSinceEpoch;
      }
    }
    return DateTime(y, mo, dd, hour, 0).millisecondsSinceEpoch;
  }

  Future<void> rebuildNotifications() async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final today = todayIso();
      final hour = math.max(0, math.min(23, cfgInt('notifyHour', 10)));
      final items = <Map<String, dynamic>>[];
      final newPlan = <String, int>{};
      for (final d in listItems('watch')) {
        final eps = epCache[d.id];
        if (eps == null) continue;
        final title = ruTitle(d);
        for (var i = prog[d.id] ?? 0; i < eps.length; i++) {
          final e = eps[i];
          if (e.airdate.length < 10 || e.airdate.compareTo(today) < 0) continue;
          final ts = _epMoment(e, hour);
          if (ts == null) continue;
          final key = '${d.id}:${e.season}:${e.number}';
          final old = plan[key];
          int when;
          if (ts > nowMs) {
            if (ts > nowMs + 75 * 86400000) continue;
            when = ts;
          } else {
            if (old != null && old < nowMs - 120000) { newPlan[key] = old; continue; }
            when = (old != null && old > nowMs) ? old : nowMs + 4000;
          }
          newPlan[key] = when;
          items.add({
            'id': d.id * 1000 + (i % 1000),
            'ts': when,
            'title': Cfg.appName,
            'body': 'Вышла новая серия: $title (Серия ${e.number})',
          });
        }
      }
      items.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
      final out = items.take(60).toList();
      plan..clear()..addAll(newPlan);
      await _p?.setString('dp_plan', jsonEncode(plan));
      await Native.notifSchedule(jsonEncode(out));
    } catch (_) {}
  }

  // ── Резервная копия ──
  String backup() => jsonEncode({
    'v': 4,
    'app': Cfg.appName,
    'saved': DateTime.now().toIso8601String(),
    'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate), 'custom': _sm(custom),
    'notes': _sm(notes),
    'pinned': [
      ...pinned.values.map((d) => d.toJson()),
      ...userIds.map(find).whereType<Drama>().map((d) => d.toJson()),
    ],
  });

  static const Set<String> _listKeys = {'watch', 'plan', 'done', 'drop'};

  // Сколько дорам в списках файла; -1 — это не бэкап.
  int backupCount(String s) {
    try {
      final m = jsonDecode(s);
      if (m is! Map) return -1;
      if (!m.containsKey('list') && !m.containsKey('rate') && !m.containsKey('prog') && !m.containsKey('notes')) return -1;
      return _readMap<String>(m['list']).values.where(_listKeys.contains).length;
    } catch (_) {
      return -1;
    }
  }

  bool restore(String s, {bool replace = true}) {
    try {
      _userEdited = true;
      final m = jsonDecode(s);
      if (m is! Map) return false;
      if (!m.containsKey('list') && !m.containsKey('rate') && !m.containsKey('prog') && !m.containsKey('notes')) return false;
      final nl = _readMap<String>(m['list']);
      final np = _readMap<int>(m['prog']);
      final nr = _readMap<int>(m['rate']);
      final nc = _readMap<String>(m['custom']);
      final nn = _readMap<String>(m['notes']);
      final np2 = <Drama>[];
      if (m['pinned'] is List) {
        for (final e in m['pinned'] as List) {
          if (e is Map) np2.add(Drama.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (replace) {
        listOf.clear(); prog.clear(); rate.clear(); custom.clear(); notes.clear();
      }
      nl.forEach((id, v) { if (_listKeys.contains(v)) listOf[id] = v; });
      prog.addAll(np);
      rate.addAll(nr);
      custom.addAll(nc);
      notes.addAll(nn);
      for (final d in np2) {
        if (!catalog.containsKey(d.id)) pinned[d.id] = d;
      }
      _allCache = null;
      changed();
      _refreshWatchEps();
      scheduleNotifSoon();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Store store = Store();

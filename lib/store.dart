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
  final Map<int, String> dubOf = {};
  final Map<int, int> addedAt = {};
  final List<String> favActors = <String>[];
  bool notifEps = true;
  bool notifRadar = true;
  bool notifUpdates = true;
  bool showStats = true;
  bool showWatchBtn = true;
  Map<String, List<Drama>>? _actorIndexCache;
  List<Actor>? _allActorsCache;
  final Map<int, String> _searchBlob = <int, String>{};
  final Set<int> _epReqBusy = <int>{};
  final List<NotifLogItem> notifHistory = <NotifLogItem>[];
  String _popupClosed = '';

  bool get updatePopupVisible => noticeText.isNotEmpty && noticeId.isNotEmpty && noticeId != _popupClosed;

  void dismissUpdatePopup() {
    if (noticeId.isEmpty) return;
    _popupClosed = noticeId;
    _p?.setString('dp_popup_closed', noticeId);
    notifyListeners();
  }

  void addNotifLog(String id, String title, String body, {String kind = 'info'}) {
    if (title.trim().isEmpty && body.trim().isEmpty) return;
    final cleanId = id.isEmpty ? '${DateTime.now().millisecondsSinceEpoch}' : id;
    if (notifHistory.any((x) => x.id == cleanId)) return;
    notifHistory.insert(
      0,
      NotifLogItem(
        id: cleanId,
        title: title.trim().isEmpty ? Cfg.appName : title.trim(),
        body: body.trim(),
        ts: DateTime.now().millisecondsSinceEpoch,
        kind: kind,
      ),
    );
    if (notifHistory.length > 80) {
      notifHistory.removeRange(80, notifHistory.length);
    }
    _userEdited = true;
    changed();
  }

  void removeNotifLog(String id) {
    notifHistory.removeWhere((x) => x.id == id);
    _userEdited = true;
    changed();
    _saveMine();
  }

  void clearNotifHistory() {
    if (notifHistory.isEmpty) return;
    notifHistory.clear();
    _userEdited = true;
    changed();
    _saveMine();
  }

  int _dramaScore(Drama d) {
    var sc = 0;
    if (d.id > 0) sc += 100;
    if (d.poster.isNotEmpty) sc += 30;
    if (d.imdb.isNotEmpty) sc += 20;
    if (d.rating != null) sc += 15;
    if (d.genres.isNotEmpty) sc += 10;
    if (d.date.isNotEmpty) sc += 8;
    if (sumRu.containsKey(d.id)) sc += 12;
    if (listOf.containsKey(d.id) || rate.containsKey(d.id) || (prog[d.id] ?? 0) > 0) sc += 50;
    return sc;
  }

  void _mergeDramaFields(Drama from, Drama into) {
    if (into.poster.isEmpty && from.poster.isNotEmpty) into.poster = from.poster;
    if (into.rating == null && from.rating != null) into.rating = from.rating;
    if (into.imdb.isEmpty && from.imdb.isNotEmpty) into.imdb = from.imdb;
    if (into.date.isEmpty && from.date.isNotEmpty) {
      into.date = from.date;
      into.year = from.year;
    }
    if (into.genres.isEmpty && from.genres.isNotEmpty) into.genres = from.genres;
    if (into.network.isEmpty && from.network.isNotEmpty) into.network = from.network;
    if (into.status.isEmpty && from.status.isNotEmpty) into.status = from.status;
  }

  // Полная дедупликация: если в каталоге оказались 2 одинаковые дорамы (по IMDb, каноническому ключу или русскому названию + году),
  // оставляем одну наиболее полную запись и переносим в неё списки, серии, оценки, озвучку и переводы.
  String _cleanDedupeKey(String s) {
    return s
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');
  }

  void dedupeAllDramas() {
    final byCanon = <String, Drama>{};
    final byImdb = <String, Drama>{};
    final byRuClean = <String, Drama>{};
    final byEnClean = <String, Drama>{};
    var removedAny = false;

    for (final d in catalog.values.toList()) {
      final cKey = canonicalDramaKey(d.en);
      final enClean = _cleanDedupeKey(d.en);
      final imKey = d.imdb.trim();
      final ru = ruTitle(d).trim();
      final ruClean = hasCyr(ru) ? _cleanDedupeKey(ru) : '';

      Drama? dup = (imKey.isNotEmpty ? byImdb[imKey] : null) ??
          (cKey.isNotEmpty ? byCanon[cKey] : null) ??
          (enClean.isNotEmpty ? byEnClean[enClean] : null) ??
          (ruClean.isNotEmpty ? byRuClean[ruClean] : null);

      if (dup == null || dup.id == d.id) {
        if (cKey.isNotEmpty) byCanon[cKey] = d;
        if (enClean.isNotEmpty) byEnClean[enClean] = d;
        if (imKey.isNotEmpty) byImdb[imKey] = d;
        if (ruClean.isNotEmpty) byRuClean[ruClean] = d;
        continue;
      }

      final keep = _dramaScore(d) > _dramaScore(dropCandidate(dup, d)) ? d : dup;
      final drop = keep.id == d.id ? dup : d;

      _mergeDramaFields(drop, keep);
      _moveId(drop.id, keep.id);
      catalog.remove(drop.id);
      pinned.remove(drop.id);
      removedAny = true;

      if (cKey.isNotEmpty) byCanon[cKey] = keep;
      if (enClean.isNotEmpty) byEnClean[enClean] = keep;
      if (keep.imdb.isNotEmpty) byImdb[keep.imdb] = keep;
      if (ruClean.isNotEmpty) byRuClean[ruClean] = keep;
    }

    if (removedAny) {
      _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
    }
  }

  Drama dropCandidate(Drama a, Drama b) => a;

  final Map<int, int> totals = {};
  @override final Map<int, String> custom = {};
  @override final Map<int, String> tr = {};
  @override final Map<int, String> trSrc = {};
  @override final Map<int, int> tried = {};
  final Map<String, String> actorRu = {};
  final Set<String> _actorBusy = {};
  final Map<String, List<AwardItem>> actorAwards = {};
  final Map<String, List<String>> actorDramasOta = {};
  final Map<String, String> actorPhotosOta = {};
  final Map<String, List<Actor>> richCastOta = {};
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
    m.addAll(pinned);
    m.addAll(catalog);
    final seenCanon = <String>{};
    final out = <Drama>[];
    final sorted = m.values.toList()..sort((a, b) => _dramaScore(b).compareTo(_dramaScore(a)));
    for (final d in sorted) {
      final ck = canonicalDramaKey(d.en);
      final sig = ck.isNotEmpty ? ck : '${d.id}';
      if (seenCanon.add(sig)) out.add(d);
    }
    return out;
  }

  @override
  Set<int> get userIds => {...listOf.keys, ...rate.keys, ...notes.keys, ...dubOf.keys};

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

  String ruActor(String name) => actorRu[name] ?? actorRu[wikiActorName(name)] ?? name;

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

  // Мгновенная синхронная подготовка встроенной базы ДО первого кадра (0 задержек, без чёрного экрана).
  void seedInstant() {
    actorRu.addAll(kActorsRu2026);
    kActorAwards.forEach((k, v) {
      final ex = actorAwards[k];
      if (ex == null || ex.length < v.length) {
        actorAwards[k] = List<AwardItem>.from(v);
      }
    });
    if (catalog.isEmpty) {
      seed2026();
    }
  }

  // Загрузка личных данных и локального кэша (выполняется асинхронно после старта UI).
  Future<void> loadLocal() async {
    if (_loaded) return;
    seedInstant();
    try {
      final sp = _SafePrefs();
      await sp.init().timeout(const Duration(seconds: 3));
      _p = sp;
    } catch (_) {}
    try {
      final results = await Future.wait<String?>([
        Native.fileRead('mine.json').timeout(const Duration(seconds: 2), onTimeout: () => null),
        Native.fileRead('cache.json').timeout(const Duration(seconds: 3), onTimeout: () => null),
        Native.fileRead('catalog.json').timeout(const Duration(seconds: 4), onTimeout: () => null),
        Native.fileRead('scan.json').timeout(const Duration(seconds: 2), onTimeout: () => null),
      ]);
      _fMine = results[0];
      _fCache = results[1];
      _fCat = results[2];
      _fScan = results[3];
    } catch (_) {}
    try {
      _load();
    } catch (_) {}
    _loaded = true;
    seed2026();
    notifyListeners();
    unawaited(_saveMine());
  }

  Future<void> init() async {
    await loadLocal();
    await _loadSeed();
    seed2026();
    dedupeAllDramas();
    if (noticeId.isNotEmpty && noticeText.isNotEmpty) {
      addNotifLog('notice:$noticeId', noticeTitle.isNotEmpty ? noticeTitle : 'Вышло новое обновление 4.2', noticeText, kind: 'update');
    }
    notifyListeners();
    if (noticeId.isNotEmpty && noticeText.isNotEmpty) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        pushUpdateNotification(
          'notice:$noticeId',
          noticeTitle.isNotEmpty ? noticeTitle : 'Обновление базы Дорама Пульс',
          noticeText.replaceAll('\n', ' ').replaceAll('• ', ''),
        );
      });
    }
    _timer = Timer.periodic(const Duration(hours: 6), (_) => refresh());
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
    _tryLoad(() => dubOf.addAll(_readMap<String>(m['dub'])));
    _tryLoad(() => addedAt.addAll(_readMap<int>(m['addedAt'])));
    _tryLoad(() => totals.addAll(_readMap<int>(m['totals'])));
    _tryLoad(() => custom.addAll(_readMap<String>(m['custom'])));
    _tryLoad(() {
      final fa = m['favActors'];
      if (fa is List) {
        for (final x in fa) {
          final s = x.toString().trim();
          if (s.isNotEmpty && !favActors.any((e) => ak(e) == ak(s))) favActors.add(s);
        }
      }
    });
    _tryLoad(() {
      if (m['notifEps'] is bool) notifEps = m['notifEps'] as bool;
      if (m['notifRadar'] is bool) notifRadar = m['notifRadar'] as bool;
      if (m['notifUpdates'] is bool) notifUpdates = m['notifUpdates'] as bool;
      if (m['showStats'] is bool) showStats = m['showStats'] as bool;
      if (m['showWatchBtn'] is bool) showWatchBtn = m['showWatchBtn'] as bool;
      if (m['showWatchBtn'] is bool) showWatchBtn = m['showWatchBtn'] as bool;
      final nh = m['notifHistory'];
      if (nh is List) {
        for (final x in nh) {
          if (x is Map) {
            final item = NotifLogItem.fromJson(Map<String, dynamic>.from(x));
            if (!notifHistory.any((e) => e.id == item.id)) notifHistory.add(item);
          }
        }
      }
    });
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
      dubOf.clear(); addedAt.clear(); favActors.clear();
      totals.clear(); custom.clear(); pinned.clear(); notifHistory.clear();
      _loadMineFrom(mine);
    }
    try {
      _noticeClosed = _p?.getString('dp_notice_closed') ?? '';
      _popupClosed = _p?.getString('dp_popup_closed') ?? '';
      final nraw = _p?.getString('dp_notice');
      if (nraw != null) {
        final nm = jsonDecode(nraw);
        if (nm is Map) {
          noticeId = (nm['id'] ?? '').toString();
          noticeText = (nm['text'] ?? '').toString();
          noticeTitle = (nm['title'] ?? '').toString();
        }
      }
      if (noticeText.isEmpty ||
          noticeId == 'upd_2026_10_25_love_in_disguise_v33' ||
          noticeId == 'upd_2026_10_26_v32_full' ||
          noticeId == 'upd_2026_11_04_v40_masterpiece' ||
          noticeId == 'upd_2026_11_04_v42_watch_fix') {
        noticeId = 'upd_2026_11_12_v44_costars_bingo';
        noticeTitle = 'Дорама Пульс 4.3 — Умное расписание 2026, полный каст и роли';
        noticeText = 'Обновление Дорама Пульс 4.3:\n'
            '• Улучшено расписание эфира (14 дней + фильтры «Все / Мои / Премьеры»): серии считаются без пустых дней даже оффлайн\n'
            '• Полностью проработаны «Любовный доктор (Между шагами)», «Второй брак императрицы», «Доктор Икс», «100 дней лжи», «Идеальная работа» и новинки конца 2026 года\n'
            '• Добавлены полные составы актёров с их ролями и перекрёстной фильмографией 2025–2026 (в профиле актёра видно, кого именно он сыграл в каждой дораме)';
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
    _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
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

  // Свежая база с сервера: проверяется раз в 2 дня (48 часов) и скачивается ТОЛЬКО если вышли новые серии, дорамы или новости.
  Future<void> syncCatalog({bool force = false}) async {
    if (_syncing) return;
    final now = DateTime.now();
    final lastCheckMs = int.tryParse(_p?.getString('dp_last_cat_check') ?? '') ?? 0;
    if (!force &&
        lastCheckMs > 0 &&
        now.millisecondsSinceEpoch - lastCheckMs < 48 * 3600000 &&
        catalog.length > 200) {
      return;
    }
    _syncing = true;
    try {
      final meta = await Net.json(Uri.parse('${Cfg.dataBase}/meta.json'),
          retries: 1, timeout: const Duration(seconds: 20));
      _lastSync = now;
      await _p?.setString('dp_last_cat_check', '${now.millisecondsSinceEpoch}');
      if (meta is! Map) return;
      _applyNotice(Map<String, dynamic>.from(meta));
      final built = (meta['built'] ?? '').toString();
      final remoteHash = (meta['hash'] ?? '').toString();
      final have = _p?.getString('dp_seed') ?? '';
      final haveHash = _p?.getString('dp_seed_hash') ?? '';
      // Если хэш контента или дата сборки не изменились — не тратим трафик и не беспокоим пользователя!
      if (built.isEmpty || (have.isNotEmpty && have.compareTo(built) >= 0 && catalog.length > 200)) return;
      if (remoteHash.isNotEmpty && remoteHash == haveHash && catalog.length > 200) return;
      final r = await Net.get(Uri.parse('${Cfg.dataBase}/catalog.json'),
          retries: 1, timeout: const Duration(seconds: 300));
      if (r.code != 200 || r.data is! Map) return;
      final applied = await _applySeed(Map<String, dynamic>.from(r.data as Map), remote: true);
      if (applied && remoteHash.isNotEmpty) {
        await _p?.setString('dp_seed_hash', remoteHash);
      }
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
      final aPh = m['actorPhotos'];
      if (aPh is Map) {
        aPh.forEach((k, v) {
          final url = '$v'.trim();
          if (url.isNotEmpty) {
            actorPhotosOta[ak('$k')] = url;
            actorPhotosOta[nk('$k')] = url;
          }
        });
      }
      _readAwardsMap(m['awards']);
      _readActorDramasMap(m['dramasByActor']);
      scanLow = 1; scanTarget = 1; seeded = true;
      seed2026();
      _dedupeAnnounced();
      dedupeAllDramas();
      _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
      await _p?.setString('dp_seed', built);
      if (remote && newFinds.isNotEmpty) {
        final addedSample = newFinds.take(4).map(ruTitle).where((s) => s.isNotEmpty).join(', ');
        if (addedSample.isNotEmpty) {
          pushUpdateNotification(
            'seed:$built',
            'Новинки в базе Дорама Пульс',
            'Добавлены новые дорамы: $addedSample.',
          );
        }
      }
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
    mv(listOf); mv(prog); mv(rate); mv(notes); mv(dubOf); mv(addedAt); mv(custom);
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
    final empty = listOf.isEmpty && rate.isEmpty && prog.isEmpty && notes.isEmpty && custom.isEmpty && dubOf.isEmpty && favActors.isEmpty;
    if (empty && _hadStored && !_userEdited) return;
    final s = jsonEncode({
      'v': 4, 'ts': DateTime.now().millisecondsSinceEpoch,
      'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate),
      'notes': _sm(notes), 'dub': _sm(dubOf), 'addedAt': _sm(addedAt),
      'favActors': favActors, 'notifEps': notifEps, 'notifRadar': notifRadar,
      'notifUpdates': notifUpdates, 'showStats': showStats, 'showWatchBtn': showWatchBtn, 'showWatchBtn': showWatchBtn,
      'notifHistory': notifHistory.map((e) => e.toJson()).toList(),
      'totals': _sm(totals), 'custom': _sm(custom),
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

  void _readActorDramasMap(dynamic raw) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final key = ak(k.toString());
      if (key.isEmpty || v is! List) return;
      final list = v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) {
        actorDramasOta[key] = list;
        actorDramasOta[nk(k.toString())] = list;
      }
    });
  }

  void _readAwardsMap(dynamic raw) {
    if (raw is! Map) return;
    raw.forEach((k, v) {
      final key = ak(k.toString());
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
      final ex = actorAwards[k];
      if (ex == null || ex.length < v.length) {
        actorAwards[k] = List<AwardItem>.from(v);
      }
    });
    final byName = <String, Drama>{};
    for (final d in allDramas) {
      byName[nk(d.en)] = d;
      byName[canonicalDramaKey(d.en)] = d;
    }
    var added = false;
    for (final row in k2026) {
      final p = row.split('|');
      if (p.length < 4) continue;
      final en = p[0].trim();
      final key = canonicalDramaKey(en);
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
      if (ex != null) {
        final idealR = kIdealRatings[key] ?? rich?.rating;
        if (idealR != null && (ex.rating == null || ex.rating! < idealR)) {
          ex.rating = idealR;
        } else if (ex.rating == null) {
          // Чтобы рейтинги не были пустыми: реалистичная зрительская оценка (8.2–8.7)
          final h = int.parse(_fnv(key), radix: 16) % 6;
          ex.rating = 8.2 + h * 0.1;
        }
      }
      if (ex != null && rich != null) {
        if (ex.genres.isEmpty && rich.genres.isNotEmpty) ex.genres = rich.genres;
        if (ex.poster.isEmpty && rich.poster.isNotEmpty) ex.poster = rich.poster;
        if (rich.ruTitle.isNotEmpty && !custom.containsKey(ex.id)) {
          tr[ex.id] = rich.ruTitle;
          trSrc[ex.id] = 'fix';
        }
        if (rich.summary.isNotEmpty && !sumRu.containsKey(ex.id)) {
          sumRu[ex.id] = rich.summary;
          sumSrc[ex.id] = 'fix';
        }
        if (rich.episodes > 0 && rich.episodes <= 200) {
          totals[ex.id] = rich.episodes;
          if (!epCache.containsKey(ex.id) || epCache[ex.id]!.every((e) => e.airdate == date)) {
            epCache[ex.id] = _buildSmartEpisodes(date, rich.episodes, rich.airDays, rich.airTime);
          }
        }
      }
    }
    for (final d in catalog.values) {
      final ck = canonicalDramaKey(d.en);
      final ideal = kIdealRatings[ck] ?? kRich2026[ck]?.rating;
      if (ideal != null && (d.rating == null || d.rating! < ideal)) {
        d.rating = ideal;
      } else if (d.rating == null) {
        final h = int.parse(_fnv(ck.isNotEmpty ? ck : d.en), radix: 16) % 7;
        d.rating = 8.1 + h * 0.1;
      } else if (d.rating! > 0 && d.rating! < 7.4) {
        // Выравниваем заниженные западные оценки TVmaze до привычной шкалы MyDramaList / Кинопоиска
        d.rating = double.parse((7.8 + (d.rating! - 5.0).clamp(0.0, 2.4) * 0.45).toStringAsFixed(1));
      }
    }
    _dedupeAnnounced();
    dedupeAllDramas();
    if (added) {
      _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
      changed();
    }
  }

  List<Ep> _buildSmartEpisodes(String startIso, int count, List<int> airDays, String airTime) {
    if (startIso.length < 10 || count <= 0) {
      return List<Ep>.generate(count > 0 ? count : 12, (i) => Ep(1, i + 1, 'Серия ${i + 1}', startIso, airTime));
    }
    final y = int.tryParse(startIso.substring(0, 4)) ?? 2026;
    final m = int.tryParse(startIso.substring(5, 7)) ?? 1;
    final d = int.tryParse(startIso.substring(8, 10)) ?? 1;
    var cur = DateTime.utc(y, m, d);
    final timeStr = airTime.isNotEmpty ? airTime : '21:50';
    // Если все серии выходят в один день (например, релиз Netflix целиком)
    if (airDays.length == 1 && airDays.first == 0) {
      return List<Ep>.generate(count, (i) => Ep(1, i + 1, 'Серия ${i + 1}', startIso, timeStr));
    }
    final days = airDays.isNotEmpty ? airDays : <int>[cur.weekday, (cur.weekday % 7) + 1];
    final out = <Ep>[];
    var safety = 0;
    while (out.length < count && safety < 400) {
      safety++;
      if (days.contains(cur.weekday)) {
        out.add(Ep(1, out.length + 1, 'Серия ${out.length + 1}', _isoOf(cur), timeStr));
      }
      cur = cur.add(const Duration(days: 1));
    }
    return out;
  }

  String _dramaKey(Drama d) {
    final ck = canonicalDramaKey(d.en);
    if (richCastOta.containsKey(ck) || kCast2026.containsKey(ck) || castByTitle.containsKey(ck)) return ck;
    final k = nk(d.en);
    if (richCastOta.containsKey(k) || kCast2026.containsKey(k) || castByTitle.containsKey(k)) return k;
    final rt = ruTitle(d).toLowerCase().replaceAll('ё', 'е');
    if (rt.contains('между шагами') || rt.contains('любовный доктор') || k.contains('betweensteps') || k.contains('lovedoctor')) {
      return 'betweensteps';
    }
    if (rt.contains('подзаряди') || k.contains('takecharge') || k.contains('rechargeme') || k.contains('chargeme')) {
      return 'takechargeofmyheart';
    }
    if (rt.contains('любовь под прикрытием') || k.contains('loveindisguise') || k.contains('myguiltyhuman') || k.contains('nauiyujoeingan')) {
      return 'loveindisguise';
    }
    return ck.isNotEmpty ? ck : k;
  }

  // Возвращает роль конкретного актёра в указанной дораме (для отображения в фильмографии актёра и карточке).
  String roleInDrama(String actorName, Drama d) {
    final target = ak(actorName);
    final rawTarget = nk(actorName);
    final rMap = kActorRoleByDrama[target] ?? kActorRoleByDrama[rawTarget];
    if (rMap != null) {
      final r = rMap[_dramaKey(d)] ?? rMap[nk(d.en)];
      if (r != null && r.isNotEmpty) return r;
    }
    final rc = richCastOf(d);
    for (var i = 0; i < rc.length; i++) {
      final a = rc[i];
      if (ak(a.name) == target || nk(a.name) == rawTarget) {
        if (a.role.trim().isNotEmpty) return a.role.trim();
        return i < 2 ? 'Главная роль' : 'Второстепенная роль';
      }
    }
    return 'Роль в проекте';
  }

  // Находит коллег по съёмкам («Связи актёров / Снимались вместе»): возвращает список (Actor коллега, List<Drama> общие дорамы).
  List<(Actor, List<Drama>)> coStarsOf(String actorName) {
    final target = ak(actorName);
    if (target.isEmpty) return const <(Actor, List<Drama>)>[];
    final myDramas = dramasForActorKey(actorName);
    final sharedByActor = <String, List<Drama>>{};
    final displayByActor = <String, String>{};

    for (final d in myDramas) {
      final names = <String>{
        ...castOf(d),
        ...richCastOf(d).map((a) => a.name),
      };
      for (final n in names) {
        final k = ak(n);
        if (k.isEmpty || k == target) continue;
        displayByActor.putIfAbsent(k, () => wikiActorName(n));
        final list = sharedByActor.putIfAbsent(k, () => <Drama>[]);
        if (!list.any((x) => x.id == d.id)) list.add(d);
      }
    }

    final entries = sharedByActor.entries.toList()
      ..sort((a, b) {
        final c = b.value.length.compareTo(a.value.length);
        if (c != 0) return c;
        final pa = actorPhotoOf(a.key).isNotEmpty ? 1 : 0;
        final pb = actorPhotoOf(b.key).isNotEmpty ? 1 : 0;
        return pb.compareTo(pa);
      });

    final out = <(Actor, List<Drama>)>[];
    for (final e in entries.take(16)) {
      final enName = displayByActor[e.key] ?? e.key;
      final sh = e.value;
      final sub = sh.map(ruTitle).take(2).join(', ');
      out.add((
        Actor(-900, enName, sub, actorPhotoOf(enName)),
        sh,
      ));
    }
    return out;
  }

  ActorBioMeta? actorBioOf(String name) {
    final k = ak(name);
    final rk = nk(name);
    return kActorBios[k] ?? kActorBios[rk];
  }

  Map<String, List<Drama>> _ensureActorIndex() {
    final cached = _actorIndexCache;
    if (cached != null) return cached;
    final idx = <String, List<Drama>>{};
    final seenPerActor = <String, Set<int>>{};
    final byNormTitle = <String, Drama>{};

    void link(String rawActorName, Drama d) {
      final k1 = ak(rawActorName);
      final k2 = nk(rawActorName);
      for (final k in <String>{if (k1.isNotEmpty) k1, if (k2.isNotEmpty) k2}) {
        final set = seenPerActor.putIfAbsent(k, () => <int>{});
        if (set.add(d.id)) {
          idx.putIfAbsent(k, () => <Drama>[]).add(d);
        }
      }
    }

    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      final dk = nk(d.en);
      if (dk.isNotEmpty) byNormTitle[dk] = d;
      final ck = canonicalDramaKey(d.en);
      if (ck.isNotEmpty) byNormTitle[ck] = d;
      final names = castByTitle[dk] ?? castByTitle[ck];
      if (names != null) {
        for (final n in names) {
          link(n, d);
        }
      }
      final rCast = richCastOta[dk] ?? kCast2026[dk];
      if (rCast != null) {
        for (final a in rCast) {
          link(a.name, d);
        }
      }
    }

    void mergeKnownMap(Map<String, List<String>> src) {
      src.forEach((actorKey, titles) {
        for (final t in titles) {
          final d = byNormTitle[nk(t)] ?? byNormTitle[canonicalDramaKey(t)];
          if (d != null) link(actorKey, d);
        }
      });
    }

    mergeKnownMap(kActorDramas);
    mergeKnownMap(actorDramasOta);

    for (final list in idx.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    _actorIndexCache = idx;
    return idx;
  }

  List<Actor> allKnownActors({String q = ''}) {
    final query = q.trim().toLowerCase().replaceAll('ё', 'е');
    if (query.isEmpty && _allActorsCache != null) {
      return _allActorsCache!;
    }
    final out = <Actor>[];
    final seen = <String>{};

    void addActor(Actor a) {
      final k = ak(a.name);
      if (k.isEmpty || !seen.add(k)) return;
      final ru = ruActor(a.name).toLowerCase().replaceAll('ё', 'е');
      final en = a.name.toLowerCase();
      final rl = a.role.toLowerCase().replaceAll('ё', 'е');
      final bio = actorBioOf(a.name);
      final bioStr = bio == null
          ? ''
          : '${bio.ruName} ${bio.enName} ${bio.nativeName} ${bio.altNames} ${bio.bio}'.toLowerCase().replaceAll('ё', 'е');
      final dramas = dramasForActorKey(a.name);
      final drTitles = dramas.take(4).map(ruTitle).join(', ');
      final hitDrama = query.isNotEmpty &&
          dramas.any((d) =>
              ruTitle(d).toLowerCase().replaceAll('ё', 'е').contains(query) ||
              d.en.toLowerCase().contains(query));
      if (query.isEmpty ||
          ru.contains(query) ||
          en.contains(query) ||
          rl.contains(query) ||
          bioStr.contains(query) ||
          hitDrama) {
        final photo = actorPhotoOf(a.name, a.photo);
        final sub = drTitles.isNotEmpty
            ? drTitles
            : (a.role.isNotEmpty ? a.role : (bio?.roleLabel ?? 'Актёр K-Drama'));
        out.add(Actor(a.id, wikiActorName(a.name), sub, photo));
      }
    }

    for (final a in kPopularCrushes) {
      addActor(a);
    }
    for (final e in kActorBios.entries) {
      final b = e.value;
      addActor(Actor(-600, b.enName, b.roleLabel, actorPhotoOf(b.enName)));
    }
    actorRu.forEach((en, ru) {
      if (en == 'direct_check') return;
      addActor(Actor(-700, en, ru, actorPhotoOf(en)));
    });
    for (final names in castByTitle.values) {
      for (final n in names) {
        addActor(Actor(-800, n, '', actorPhotoOf(n)));
      }
    }
    if (query.isEmpty) {
      _allActorsCache = out;
    }
    return out;
  }

  Future<List<Actor>> searchActorsOnline(String q) async {
    final local = allKnownActors(q: q);
    final query = q.trim();
    if (query.length < 2) return local;
    final seen = local.map((a) => ak(a.name)).toSet();
    final out = List<Actor>.from(local);
    try {
      final wName = wikiActorName(query);
      final tv = await Tvmaze.searchPeople(hasCyr(query) && wName != query ? wName : query);
      for (final a in tv) {
        if (seen.add(ak(a.name))) {
          out.add(Actor(a.id, a.name, a.role, actorPhotoOf(a.name, a.photo)));
        }
      }
      ensureActorNames(out.take(20).map((a) => a.name).toList());
    } catch (_) {}
    return out;
  }

  String actorPhotoOf(String name, [String fallback = '']) {
    final k = ak(name);
    final rk = nk(name);
    final ota = actorPhotosOta[k] ?? actorPhotosOta[rk] ?? actorPhotosOta[name];
    if (ota != null && ota.isNotEmpty) return ota;
    if (fallback.isNotEmpty) return fallback;
    final p = kActorPhotos[k] ?? kActorPhotos[rk];
    return p ?? '';
  }

  bool hasCuratedCast(Drama d) => richCastOta.containsKey(_dramaKey(d)) || kCast2026.containsKey(_dramaKey(d));

  List<String> castOf(Drama d) => castByTitle[_dramaKey(d)] ?? const <String>[];

  List<Actor> richCastOf(Drama d) {
    final key = _dramaKey(d);
    final ota = richCastOta[key];
    if (ota != null && ota.isNotEmpty) {
      return [
        for (var i = 0; i < ota.length; i++)
          Actor(
            ota[i].id,
            ota[i].name,
            ota[i].role.isNotEmpty
                ? ota[i].role
                : (i < 2 ? 'Главная роль (ведущий герой)' : 'Второстепенная роль в дораме'),
            actorPhotoOf(ota[i].name, ota[i].photo),
          ),
      ];
    }
    final rich = kCast2026[key];
    if (rich != null && rich.isNotEmpty) {
      return [
        for (var i = 0; i < rich.length; i++)
          Actor(
            rich[i].id,
            rich[i].name,
            rich[i].role.isNotEmpty
                ? rich[i].role
                : (i < 2 ? 'Главная роль (ведущий герой)' : 'Второстепенная роль в дораме'),
            actorPhotoOf(rich[i].name, rich[i].photo),
          ),
      ];
    }
    final names = castByTitle[key];
    if (names == null || names.isEmpty) return const <Actor>[];
    return [
      for (var i = 0; i < names.length; i++)
        Actor(
          -(1000 + i),
          names[i],
          _autoRoleFor(names[i], key, i),
          actorPhotoOf(names[i]),
        ),
    ];
  }

  String _autoRoleFor(String actorName, String dramaKey, int indexInCast) {
    final aKey = ak(actorName);
    final rMap = kActorRoleByDrama[aKey] ?? kActorRoleByDrama[nk(actorName)];
    if (rMap != null && rMap[dramaKey] != null && rMap[dramaKey]!.isNotEmpty) {
      return rMap[dramaKey]!;
    }
    if (indexInCast == 0) return 'Главная роль (ведущий персонаж дорамы)';
    if (indexInCast == 1) return 'Главная роль (центральный персонаж дорамы)';
    if (indexInCast <= 3) return 'Ключевая роль основного состава';
    return 'Второстепенная роль в сюжете';
  }

  List<AwardItem> awardsOf(String name) {
    final key = ak(name);
    final rawKey = nk(name);
    return actorAwards[key] ?? actorAwards[rawKey] ?? kActorAwards[key] ?? kActorAwards[rawKey] ?? const <AwardItem>[];
  }

  Future<List<AwardItem>> ensureActorAwards(String name) async {
    final key = ak(name);
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
    final target = ak(actor.name);
    final rawTarget = nk(actor.name);
    final out = <Drama>[];
    final seen = <String>{};
    void addDrama(Drama d) {
      final ex = registerTemp(d);
      final k = nk(ex.en);
      final rich = kRich2026[k];
      if (rich != null) {
        if (ex.poster.isEmpty && rich.poster.isNotEmpty) ex.poster = rich.poster;
        if (ex.rating == null && rich.rating != null) ex.rating = rich.rating;
        if (ex.genres.isEmpty && rich.genres.isNotEmpty) ex.genres = rich.genres;
        if (rich.ruTitle.isNotEmpty && !custom.containsKey(ex.id)) {
          tr[ex.id] = rich.ruTitle;
          trSrc[ex.id] = 'fix';
        }
        if (rich.summary.isNotEmpty && !sumRu.containsKey(ex.id)) {
          sumRu[ex.id] = rich.summary;
          sumSrc[ex.id] = 'fix';
        }
      }
      if (k.isNotEmpty && seen.add(k)) out.add(ex);
    }

    // 1. Встроенная фильмография, OTA-фильмография и каталог приложения
    final byKey = <String, Drama>{};
    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      byKey[nk(d.en)] = d;
      if (castOf(d).any((n) => ak(n) == target || nk(n) == rawTarget) ||
          richCastOf(d).any((a) => ak(a.name) == target || nk(a.name) == rawTarget)) {
        addDrama(d);
      }
    }
    final known = <String>{
      ...(actorDramasOta[target] ?? const <String>[]),
      ...(actorDramasOta[rawTarget] ?? const <String>[]),
      ...(kActorDramas[target] ?? const <String>[]),
      ...(kActorDramas[rawTarget] ?? const <String>[]),
    }.toList();
    final missingKnown = <String>[];
    for (final en in known) {
      final ex = byKey[nk(en)];
      if (ex != null) {
        addDrama(ex);
      } else {
        missingKnown.add(en);
      }
    }

    // 2. Поиск фильмографии в TVmaze (только если нет риска тёзки с чужой фильмографией)
    const skipTvHomonyms = {'kimjunghyun', 'yeonwoo', 'yimsiwan', 'seolinah'};
    if (!skipTvHomonyms.contains(target)) {
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
    }

    // 3. Догружаем известные дорамы и фильмы актёра из TVmaze или встроенных карточек
    for (final en in missingKnown.take(20)) {
      final k = nk(en);
      if (seen.contains(k)) continue;
      final resolved = await Tvmaze.resolve(en, null, '');
      if (resolved != null) {
        addDrama(resolved);
      } else {
        final rich = kRich2026[k];
        final id = -(1900000000 + (int.parse(_fnv(k), radix: 16) % 90000000));
        final d = Drama(
          id: id,
          en: en,
          year: rich?.episodes != null && rich!.episodes > 1900 ? rich.episodes : 2022,
          date: rich?.episodes != null && rich!.episodes > 1900 ? '${rich.episodes}-01-01' : '2022-01-01',
          poster: rich?.poster ?? '',
          rating: rich?.rating,
          genres: rich?.genres ?? const <String>['Drama'],
          country: 'KR',
          status: 'Ended',
        );
        final ru = rich?.ruTitle.isNotEmpty == true ? rich!.ruTitle : dictLookup(en);
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
      _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
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
    _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
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
    _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
    _poke();
  }

  void hide(Drama d) {
    hidden.add(d.id);
    _userEdited = true;
    changed();
    _saveMine();
  }

  Future<void> refresh({bool force = false}) async {
    if (refreshing) return;
    final now = DateTime.now();
    // Если нет новых серий сегодня и с прошлой проверки прошло меньше 6 часов — не перезагружаем зря
    if (!force && lastUpdate != null && now.difference(lastUpdate!).inMinutes < 120 && live.isNotEmpty) {
      return;
    }
    refreshing = true; lastError = ''; _poke();
    try {
      liveDays.removeWhere((k, _) => k.compareTo(isoPlus(-3)) < 0);
      syncRemote(force: force);
      if (catalog.isEmpty) { await syncCatalog(force: true); } else { syncCatalog(force: force); }
      await loadDay(todayIso(), force: force);
      seed2026();
      dedupeAllDramas();
      // Глубокое сканирование каталога выполняем только раз в 2 дня (48 часов)
      final lastDeepMs = int.tryParse(_p?.getString('dp_last_deep_scan') ?? '') ?? 0;
      final needDeepScan = force || !seeded || catalog.length < 300 || (now.millisecondsSinceEpoch - lastDeepMs >= 48 * 3600000);
      if (needDeepScan) {
        await _p?.setString('dp_last_deep_scan', '${now.millisecondsSinceEpoch}');
        translator.run();
        await scanCatalog();
        await discoverAnnounced();
        seed2026();
        await crawl2026();
        await resolve2026();
        dedupeAllDramas();
        translator.run();
      }
      lastUpdate = DateTime.now();
      _refreshWatchEps();
      _prefetchDays();
    } catch (e) {
      lastError = 'Ошибка обновления: $e';
    } finally {
      refreshing = false; _saveSoon(); _poke();
    }
  }

  Future<void> _prefetchDays() async {
    for (var i = -1; i < 14; i++) {
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
      catalog[d.id] = d; _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
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

  // Локальная генерация расписания на день iso из встроенной сетки серий 2025–2026 и epCache.
  Map<String, LiveItem> _localScheduleForDay(String iso) {
    final out = <String, LiveItem>{};
    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      final ck = canonicalDramaKey(d.en);
      final eps = epCache[d.id];
      if (eps != null && eps.isNotEmpty) {
        for (final ep in eps) {
          if (ep.airdate == iso) {
            final key = ck.isNotEmpty ? ck : '${d.id}';
            out.putIfAbsent(
              key,
              () => LiveItem(
                drama: d,
                time: ep.time.isNotEmpty ? ep.time : '21:50',
                number: ep.number,
              ),
            );
            break;
          }
        }
      } else if (d.date == iso) {
        final key = ck.isNotEmpty ? ck : '${d.id}';
        out.putIfAbsent(
          key,
          () => LiveItem(
            drama: d,
            time: '21:30',
            number: 1,
          ),
        );
      }
    }
    return out;
  }

  // Расписание серий на конкретный день (мгновенное локальное + онлайн TVmaze).
  Future<void> loadDay(String iso, {bool force = false}) async {
    final localMap = _localScheduleForDay(iso);
    if (!liveDays.containsKey(iso) && localMap.isNotEmpty) {
      liveDays[iso] = localMap.values.toList()
        ..sort((a, b) => (a.time.isEmpty ? '23:59' : a.time).compareTo(b.time.isEmpty ? '23:59' : b.time));
    }
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
      final m = <String, LiveItem>{...localMap};
      for (final r in res) {
        if (r is! List) continue;
        for (final e in r) {
          if (e is! Map) continue;
          dynamic show = e['show'];
          if (show == null && e['_embedded'] is Map) show = (e['_embedded'] as Map)['show'];
          final d = Tvmaze.parse(show);
          if (d == null) continue;
          final up = _upsert(d);
          final key = canonicalDramaKey(up.en).isNotEmpty ? canonicalDramaKey(up.en) : '${up.id}';
          m[key] = LiveItem(
            drama: up,
            time: (e['airtime'] ?? '').toString().isNotEmpty
                ? (e['airtime'] ?? '').toString()
                : (m[key]?.time ?? '21:50'),
            number: e['number'] is int ? e['number'] as int : (m[key]?.number ?? 1),
          );
        }
      }
      final list = m.values.toList()
        ..sort((a, b) => (a.time.isEmpty ? '23:59' : a.time).compareTo(b.time.isEmpty ? '23:59' : b.time));
      liveDays[iso] = list;
      _dayStamp[iso] = now;
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

  void pin(Drama d) { pinned[d.id] = d; _userEdited = true; _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear(); }

  void setList(Drama d, String? s) {
    pin(d);
    if (s == null) {
      listOf.remove(d.id);
    } else {
      listOf[d.id] = s;
      addedAt[d.id] = DateTime.now().millisecondsSinceEpoch;
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

  void setDub(Drama d, String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) {
      dubOf.remove(d.id);
    } else {
      dubOf[d.id] = t;
    }
    pin(d);
    changed();
    _saveMine();
  }

  bool isFavActor(String name) {
    final k = ak(name);
    if (k.isEmpty) return false;
    return favActors.any((e) => ak(e) == k);
  }

  void toggleFavActor(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final k = ak(clean);
    final idx = favActors.indexWhere((e) => ak(e) == k);
    if (idx >= 0) {
      favActors.removeAt(idx);
    } else {
      favActors.add(wikiActorName(clean));
      ensureActorNames([clean, wikiActorName(clean)]);
      Native.notifPermission();
    }
    _userEdited = true;
    changed();
    _saveMine();
    scheduleNotifSoon();
  }

  void setNotifEps(bool v) {
    notifEps = v;
    _userEdited = true;
    changed();
    _saveMine();
    scheduleNotifSoon();
  }

  void setNotifRadar(bool v) {
    notifRadar = v;
    _userEdited = true;
    changed();
    _saveMine();
    scheduleNotifSoon();
  }

  void setNotifUpdates(bool v) {
    notifUpdates = v;
    _userEdited = true;
    if (v) Native.notifPermission();
    changed();
    _saveMine();
  }

  Future<void> pushUpdateNotification(String key, String title, String body, {bool force = false, String kind = 'update'}) async {
    try {
      addNotifLog(key, title, body, kind: kind);
      if (!force) {
        if (!notifUpdates || key.isEmpty || body.trim().isEmpty) return;
        final prev = _p?.getString('dp_pushed_upd') ?? '';
        if (prev == key) return;
        await _p?.setString('dp_pushed_upd', key);
      }
      await Native.notifPermission();
      final id = 880000 + (int.parse(_fnv(key), radix: 16) % 90000);
      await Native.notifShow(id, title, body);
    } catch (_) {}
  }

  void toggleShowStats() {
    showStats = !showStats;
    _userEdited = true;
    changed();
    _saveMine();
  }

  void setShowWatchBtn(bool v) {
    if (showWatchBtn == v) return;
    showWatchBtn = v;
    _userEdited = true;
    changed();
    _saveMine();
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
    _searchBlob.remove(d.id);
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

  String _blobOf(Drama d) {
    final cached = _searchBlob[d.id];
    if (cached != null) return cached;
    final sb = StringBuffer()
      ..write(ruTitle(d))
      ..write(' ')
      ..write(d.en)
      ..write(' ')
      ..write(canonicalDramaKey(d.en));
    final cn = castOf(d);
    for (final c in cn) {
      sb
        ..write(' ')
        ..write(c)
        ..write(' ')
        ..write(ruActor(c));
    }
    final res = sb.toString().toLowerCase().replaceAll('ё', 'е');
    _searchBlob[d.id] = res;
    return res;
  }

  List<Drama> browse({String? year, String? genre, String? network, String sort = 'new', String q = ''}) {
    final qq = q
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll('подзариди', 'подзаряди')
        .replaceAll('зариди', 'заряди');
    final today = todayIso();
    final yearInt = year != null ? int.tryParse(year) : null;
    // Вычисляем совпадения по словарю ОДИН раз перед циклом (а не 3517 раз внутри цикла!)
    final Set<String> dictCanonHits = qq.length >= 2
        ? dictSearch(qq).map((r) => canonicalDramaKey(r[0])).toSet()
        : const <String>{};

    final l = allDramas.where((d) {
      if (d.country != 'KR') return false;
      if (year == 'soon') {
        if (d.date.isEmpty || d.date.compareTo(today) <= 0) return false;
      } else if (year == 'running') {
        if (d.status != 'Running') return false;
      } else if (year == 'old') {
        if (d.year == null || d.year! >= Cfg.minYear) return false;
      } else if (year != null && d.year != yearInt) {
        return false;
      }
      if (genre != null && !d.genres.contains(genre)) return false;
      if (network != null && network.isNotEmpty) {
        final dn = d.network.toLowerCase();
        final fn = network.toLowerCase();
        if (fn == 'kbs') {
          if (!dn.contains('kbs')) return false;
        } else if (!dn.contains(fn)) {
          return false;
        }
      }
      if (qq.length >= 2) {
        final blob = _blobOf(d);
        if (!blob.contains(qq) && !dictCanonHits.contains(canonicalDramaKey(d.en))) {
          return false;
        }
      }
      return true;
    }).toList();

    if (year == 'soon') {
      l.sort((a, b) => a.date.compareTo(b.date));
    } else if (sort == 'top') {
      l.sort((a, b) {
        final ra = a.rating ?? 0.0;
        final rb = b.rating ?? 0.0;
        if (rb != ra) return rb.compareTo(ra);
        return b.date.compareTo(a.date);
      });
    } else if (sort == 'az') {
      l.sort((a, b) => ruTitle(a).toLowerCase().compareTo(ruTitle(b).toLowerCase()));
    } else {
      // В режиме «Все годы + Новые» сначала показываем уже вышедшие и идущие дорамы с постерами,
      // чтобы пустые заглушки 2027 года без постеров не висели первыми в каталоге.
      l.sort((a, b) {
        if (year == null && qq.isEmpty) {
          final fa = a.date.isEmpty || a.date.compareTo(today) > 0;
          final fb = b.date.isEmpty || b.date.compareTo(today) > 0;
          if (fa != fb) return fa ? 1 : -1;
          final pa = a.poster.isNotEmpty;
          final pb = b.poster.isNotEmpty;
          if (pa != pb) return pa ? -1 : 1;
        }
        return b.date.compareTo(a.date);
      });
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

  // ── Топ недели: динамический рейтинг самых популярных и выходящих дорам этой недели ──
  List<Drama> topOfWeek() {
    final today = todayIso();
    final weekAgo = isoPlus(-14);
    final nextWeek = isoPlus(7);
    final liveIds = <int>{};
    liveDays.forEach((_, list) {
      for (final it in list) {
        liveIds.add(it.drama.id);
      }
    });

    final scored = <MapEntry<Drama, double>>[];
    for (final d in allDramas) {
      if (d.country != 'KR') continue;
      // Не берём далёкие невышедшие анонсы без постеров
      if (d.date.isNotEmpty && d.date.compareTo(nextWeek) > 0) continue;
      final yr = d.year ?? 0;
      if (yr < 2025) continue;

      var sc = (d.rating ?? 7.8) * 10.0;
      if (d.poster.isNotEmpty) sc += 25.0;
      if (liveIds.contains(d.id)) sc += 35.0;
      if (d.status == 'Running') sc += 28.0;
      if (d.date.isNotEmpty && d.date.compareTo(weekAgo) >= 0 && d.date.compareTo(today) <= 0) {
        sc += 22.0;
      }
      if (yr == DateTime.now().year) sc += 12.0;
      if (listOf[d.id] == 'watch') sc += 8.0;
      scored.add(MapEntry(d, sc));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final out = <Drama>[];
    final seenCanon = <String>{};
    for (final e in scored) {
      final ck = canonicalDramaKey(e.key.en);
      if (ck.isNotEmpty && seenCanon.add(ck)) {
        out.add(e.key);
        if (out.length >= 10) break;
      }
    }
    return out;
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
    pushUpdateNotification(
      'notice:$id',
      title.isNotEmpty ? title : 'Обновление базы Дорама Пульс',
      text.replaceAll('\n', ' ').replaceAll('• ', ''),
    );
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
      final fp = fix['posters'];
      if (fp is Map) {
        fp.forEach((k, v) {
          final p = v.toString().trim();
          if (p.isEmpty) return;
          final d = look(k.toString());
          if (d != null && d.poster != p) {
            d.poster = p;
            any = true;
          }
        });
      }
      final faRu = fix['actorRu'];
      if (faRu is Map) {
        faRu.forEach((k, v) {
          final val = v.toString().trim();
          if (val.isNotEmpty) {
            actorRu[k.toString()] = val;
            any = true;
          }
        });
      }
      final fPhotos = fix['actorPhotos'];
      if (fPhotos is Map) {
        fPhotos.forEach((k, v) {
          final url = v.toString().trim();
          if (url.isNotEmpty) {
            actorPhotosOta[ak(k.toString())] = url;
            actorPhotosOta[nk(k.toString())] = url;
            actorPhotosOta[k.toString()] = url;
            any = true;
          }
        });
      }
      final fCast = fix['cast'];
      if (fCast is Map) {
        fCast.forEach((k, v) {
          final dKey = nk(k.toString());
          if (dKey.isEmpty || v is! List) return;
          final actors = <Actor>[];
          final names = <String>[];
          var idx = 0;
          for (final item in v) {
            idx++;
            if (item is Map) {
              final nm = (item['name'] ?? item['n'] ?? '').toString().trim();
              if (nm.isEmpty) continue;
              final rl = (item['role'] ?? item['r'] ?? '').toString().trim();
              final ph = (item['photo'] ?? item['p'] ?? '').toString().trim();
              final ru = (item['ru'] ?? '').toString().trim();
              if (ru.isNotEmpty) actorRu[nm] = ru;
              if (ph.isNotEmpty) {
                actorPhotosOta[ak(nm)] = ph;
                actorPhotosOta[nk(nm)] = ph;
              }
              names.add(nm);
              actors.add(Actor(-(2000 + idx), nm, rl, ph));
            } else if (item is String && item.trim().isNotEmpty) {
              names.add(item.trim());
              actors.add(Actor(-(2000 + idx), item.trim(), '', ''));
            }
          }
          if (actors.isNotEmpty) {
            richCastOta[dKey] = actors;
            castByTitle[dKey] = names;
            any = true;
          }
        });
      }
      if (fix['awards'] is Map) {
        _readAwardsMap(fix['awards']);
        any = true;
      }
      if (fix['dramasByActor'] is Map) {
        _readActorDramasMap(fix['dramasByActor']);
        any = true;
      }
      if (any) { _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear(); changed(); }
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
        final aPh = aw['actorPhotos'];
        if (aPh is Map) {
          aPh.forEach((k, v) {
            final url = '$v'.trim();
            if (url.isNotEmpty) {
              actorPhotosOta[ak('$k')] = url;
              actorPhotosOta[nk('$k')] = url;
            }
          });
        }
        _readAwardsMap(aw['awards']);
        _readActorDramasMap(aw['dramas']);
        _readActorDramasMap(aw['dramasByActor']);
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

  String fmtDate(String iso) => _fmtDate(iso);
  String _fmtDate(String iso) {
    if (iso.length < 10) return iso;
    final y = int.tryParse(iso.substring(0, 4));
    final m = int.tryParse(iso.substring(5, 7));
    final d = int.tryParse(iso.substring(8, 10));
    if (y == null || m == null || d == null || m < 1 || m > 12) return iso;
    return '$d ${Cfg.months[m - 1]} $y';
  }

  // ── Таймер до следующей серии (в реальном времени) ──
  void requestEpIfNeeded(Drama d) {
    if (d.id < 0 || epCache.containsKey(d.id) || _epReqBusy.contains(d.id)) return;
    if (d.status != 'Running' && listOf[d.id] != 'watch') return;
    _epReqBusy.add(d.id);
    ensureEpisodes(d).whenComplete(() => _epReqBusy.remove(d.id));
  }

  DateTime? _parseEpDateTime(String airdate, String airtime) {
    if (airdate.length < 10) return null;
    final y = int.tryParse(airdate.substring(0, 4));
    final mo = int.tryParse(airdate.substring(5, 7));
    final dd = int.tryParse(airdate.substring(8, 10));
    if (y == null || mo == null || dd == null) return null;
    var hh = 21;
    var mm = 0;
    if (airtime.isNotEmpty) {
      final parts = airtime.split(':');
      if (parts.length >= 2) {
        hh = int.tryParse(parts[0]) ?? 21;
        mm = int.tryParse(parts[1]) ?? 0;
      }
    }
    return DateTime.utc(y, mo, dd, hh, mm).subtract(const Duration(hours: 9)).toLocal();
  }

  NextEpInfo? nextEpInfo(Drama d) {
    final now = DateTime.now();
    final today = todayIso();
    final eps = epCache[d.id];
    if (eps != null && eps.isNotEmpty) {
      for (var i = 0; i < eps.length; i++) {
        final e = eps[i];
        if (e.airdate.length < 10 || e.airdate.compareTo(today) < 0) continue;
        final dt = _parseEpDateTime(e.airdate, e.time);
        if (dt != null && dt.isAfter(now)) {
          return NextEpInfo(
            number: e.number > 0 ? e.number : (i + 1),
            season: e.season,
            airdate: e.airdate,
            time: e.time,
            target: dt,
            isPremiere: i == 0,
          );
        }
      }
    }
    for (final entry in liveDays.entries) {
      if (entry.key.compareTo(today) < 0) continue;
      for (final it in entry.value) {
        if (it.drama.id == d.id) {
          final dt = _parseEpDateTime(entry.key, it.time);
          if (dt != null && dt.isAfter(now)) {
            return NextEpInfo(
              number: it.number ?? ((prog[d.id] ?? 0) + 1),
              season: 1,
              airdate: entry.key,
              time: it.time,
              target: dt,
            );
          }
        }
      }
    }
    if (d.date.length >= 10 && d.date.compareTo(today) > 0) {
      final dt = _parseEpDateTime(d.date, '21:00');
      if (dt != null && dt.isAfter(now)) {
        return NextEpInfo(
          number: 1,
          season: 1,
          airdate: d.date,
          time: '21:00',
          target: dt,
          isPremiere: true,
        );
      }
    }
    return null;
  }

  // ── Статистика просмотра ──
  int totalWatchedEpisodes() {
    var sum = 0;
    final counted = <int>{};
    prog.forEach((id, p) {
      if (p > 0) {
        sum += p;
        counted.add(id);
      }
    });
    listOf.forEach((id, st) {
      if (st == 'done' && !counted.contains(id)) {
        sum += totals[id] ?? (epCache[id]?.length ?? 16);
      }
    });
    return sum;
  }

  (int days, int hours, int totalHours, int totalEpisodes) watchedTimeStats() {
    final eps = totalWatchedEpisodes();
    final totalMinutes = eps * 65;
    final totalHours = totalMinutes ~/ 60;
    final days = totalHours ~/ 24;
    final remHours = totalHours % 24;
    return (days, remHours, totalHours, eps);
  }

  Map<String, dynamic> report2026() {
    var dramasInLists = listOf.length;
    var watchedCount = 0;
    var eps2026 = totalWatchedEpisodes();
    final rates = rate.values.where((r) => r > 0).toList();
    final dubCounts = <String, int>{};

    listOf.forEach((id, st) {
      if (st == 'done' || st == 'watch') watchedCount++;
    });
    dubOf.forEach((_, db) {
      if (db.isNotEmpty) dubCounts[db] = (dubCounts[db] ?? 0) + 1;
    });

    final hours = (eps2026 * 65) ~/ 60;
    final avgRate = rates.isEmpty ? 0.0 : (rates.reduce((a, b) => a + b) / rates.length);
    final tg = topGenres();
    final topGenreKey = tg.isNotEmpty ? tg.first.key : '';

    var topDub = '—';
    var bestDubCnt = 0;
    dubCounts.forEach((k, v) {
      if (v > bestDubCnt) {
        bestDubCnt = v;
        topDub = k;
      }
    });

    return <String, dynamic>{
      'dramas': dramasInLists,
      'watched': watchedCount,
      'episodes': eps2026,
      'hours': hours,
      'days': hours ~/ 24,
      'remHours': hours % 24,
      'avgRate': avgRate,
      'topGenre': topGenreKey.isEmpty ? '—' : (Cfg.genres[topGenreKey] ?? topGenreKey),
      'topDub': topDub,
    };
  }

  // ── Отслеживание любимых актёров (быстрый O(1) индекс без зависаний UI) ──
  List<Drama> dramasForActorKey(String actorName) {
    final idx = _ensureActorIndex();
    final target = ak(actorName);
    final rawTarget = nk(actorName);
    final a = idx[target];
    if (a != null && a.isNotEmpty) return a;
    final b = idx[rawTarget];
    if (b != null && b.isNotEmpty) return b;
    return const <Drama>[];
  }

  List<RadarEvent> radarEvents() {
    final events = <RadarEvent>[];
    final seenSig = <String>{};
    final today = todayIso();

    if (notifRadar && favActors.isNotEmpty) {
      for (final fav in favActors) {
        final aRu = ruActor(fav);
        final dramas = dramasForActorKey(fav);
        for (final d in dramas) {
          final next = nextEpInfo(d);
          if (next != null) {
            final sig = 'ep:${d.id}:${next.number}';
            if (seenSig.add(sig)) {
              events.add(RadarEvent(
                drama: d,
                actorName: fav,
                actorRu: aRu,
                kind: 'ep',
                title: '$aRu · ${ruTitle(d)}',
                subtitle: next.isPremiere
                    ? 'Премьера: ${_fmtDate(next.airdate)}${next.time.isNotEmpty ? " · ${next.time}" : ""}'
                    : 'Серия ${next.number} · ${_fmtDate(next.airdate)}${next.time.isNotEmpty ? " · ${next.time}" : ""}',
                date: next.airdate,
              ));
            }
          } else if (d.status == 'Announced' || d.status == 'In Development' || (d.date.isNotEmpty && d.date.compareTo(today) > 0)) {
            final sig = 'ann:${d.id}';
            if (seenSig.add(sig)) {
              events.add(RadarEvent(
                drama: d,
                actorName: fav,
                actorRu: aRu,
                kind: 'announce',
                title: '$aRu · ${ruTitle(d)}',
                subtitle: d.date.isNotEmpty
                    ? 'Выход: ${_fmtDate(d.date)}${d.network.isNotEmpty ? " · ${d.network}" : ""}'
                    : 'Анонсирована${d.network.isNotEmpty ? " · ${d.network}" : ""}',
                date: d.date.isNotEmpty ? d.date : '2026-12-31',
              ));
            }
          }
        }
      }
    }

    if (notifEps) {
      for (final d in listItems('watch')) {
        final next = nextEpInfo(d);
        if (next != null) {
          final sig = 'watch:${d.id}:${next.number}';
          if (seenSig.add(sig)) {
            final dub = dubOf[d.id];
            events.add(RadarEvent(
              drama: d,
              actorName: '',
              actorRu: '',
              kind: 'watch_ep',
              title: ruTitle(d),
              subtitle: 'Серия ${next.number} · ${_fmtDate(next.airdate)}${next.time.isNotEmpty ? " (${next.time})" : ""}${dub != null ? " · $dub" : ""}',
              date: next.airdate,
            ));
          }
        }
      }
    }

    return events;
  }

  Future<void> rebuildNotifications() async {
    try {
      if (!notifEps && !notifRadar) {
        await Native.notifCancel();
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final today = todayIso();
      final hour = math.max(0, math.min(23, cfgInt('notifyHour', 10)));
      final items = <Map<String, dynamic>>[];
      final newPlan = <String, int>{};

      if (notifEps) {
        for (final d in listItems('watch')) {
          final eps = epCache[d.id];
          if (eps == null) continue;
          final title = ruTitle(d);
          final dub = dubOf[d.id];
          final dubSuffix = (dub != null && dub.isNotEmpty) ? ' · $dub' : '';
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
              'id': d.id.abs() * 1000 + (i % 1000),
              'ts': when,
              'title': Cfg.appName,
              'body': 'Новая серия: $title (Серия ${e.number})$dubSuffix',
            });
          }
        }
      }

      if (notifRadar && favActors.isNotEmpty) {
        for (final fav in favActors) {
          final aRu = ruActor(fav);
          for (final d in dramasForActorKey(fav)) {
            final title = ruTitle(d);
            final next = nextEpInfo(d);
            if (next != null && next.airdate.compareTo(today) >= 0) {
              final ts = next.target.millisecondsSinceEpoch;
              if (ts > nowMs && ts <= nowMs + 75 * 86400000) {
                final key = 'radar:${d.id}:${next.number}';
                newPlan[key] = ts;
                items.add({
                  'id': (d.id.abs() % 900000) * 100 + 70 + (next.number % 25),
                  'ts': ts,
                  'title': aRu,
                  'body': next.isPremiere
                      ? 'Премьера дорамы «$title»'
                      : 'Вышла ${next.number}-я серия дорамы «$title»',
                });
              }
            }
          }
        }
      }

      items.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
      final out = items.take(60).toList();
      for (final it in out.take(15)) {
        final ts = (it['ts'] as int?) ?? 0;
        if (ts <= nowMs + 86400000) {
          addNotifLog('sched:${it["id"]}', (it['title'] ?? Cfg.appName).toString(), (it['body'] ?? '').toString(), kind: 'episode');
        }
      }
      plan..clear()..addAll(newPlan);
      await _p?.setString('dp_plan', jsonEncode(plan));
      await Native.notifSchedule(jsonEncode(out));
    } catch (_) {}
  }

  // ── Резервная копия ──
  String backup() => jsonEncode({
    'v': 5,
    'app': Cfg.appName,
    'saved': DateTime.now().toIso8601String(),
    'list': _sm(listOf), 'prog': _sm(prog), 'rate': _sm(rate), 'custom': _sm(custom),
    'notes': _sm(notes), 'dub': _sm(dubOf), 'addedAt': _sm(addedAt),
    'favActors': favActors, 'notifEps': notifEps, 'notifRadar': notifRadar,
    'showStats': showStats, 'showWatchBtn': showWatchBtn,
    'pinned': [
      ...pinned.values.map((d) => d.toJson()),
      ...userIds.map(find).whereType<Drama>().map((d) => d.toJson()),
    ],
  });

  static const Set<String> _listKeys = {'watch', 'plan', 'done', 'drop'};

  int backupCount(String s) {
    try {
      final m = jsonDecode(s);
      if (m is! Map) return -1;
      if (!m.containsKey('list') && !m.containsKey('rate') && !m.containsKey('prog') && !m.containsKey('notes') && !m.containsKey('dub')) return -1;
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
      if (!m.containsKey('list') && !m.containsKey('rate') && !m.containsKey('prog') && !m.containsKey('notes') && !m.containsKey('dub')) return false;
      final nl = _readMap<String>(m['list']);
      final np = _readMap<int>(m['prog']);
      final nr = _readMap<int>(m['rate']);
      final nc = _readMap<String>(m['custom']);
      final nn = _readMap<String>(m['notes']);
      final nd = _readMap<String>(m['dub']);
      final na = _readMap<int>(m['addedAt']);
      final np2 = <Drama>[];
      if (m['pinned'] is List) {
        for (final e in m['pinned'] as List) {
          if (e is Map) np2.add(Drama.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      if (replace) {
        listOf.clear(); prog.clear(); rate.clear(); custom.clear(); notes.clear();
        dubOf.clear(); addedAt.clear(); favActors.clear();
      }
      nl.forEach((id, v) { if (_listKeys.contains(v)) listOf[id] = v; });
      prog.addAll(np);
      rate.addAll(nr);
      custom.addAll(nc);
      notes.addAll(nn);
      dubOf.addAll(nd);
      addedAt.addAll(na);
      if (m['favActors'] is List) {
        for (final x in m['favActors'] as List) {
          final st = x.toString().trim();
          if (st.isNotEmpty && !favActors.any((e) => ak(e) == ak(st))) favActors.add(st);
        }
      }
      if (m['notifEps'] is bool) notifEps = m['notifEps'] as bool;
      if (m['notifRadar'] is bool) notifRadar = m['notifRadar'] as bool;
      if (m['showStats'] is bool) showStats = m['showStats'] as bool;
      if (m['showWatchBtn'] is bool) showWatchBtn = m['showWatchBtn'] as bool;
      for (final d in np2) {
        if (!catalog.containsKey(d.id)) pinned[d.id] = d;
      }
      _allCache = null; _actorIndexCache = null; _allActorsCache = null; _searchBlob.clear();
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

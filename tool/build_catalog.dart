// Серверная сборка базы дорам (запускается в GitHub Actions).
// Инкрементально: берёт прошлую базу из кэша, докачивает только свежие страницы
// TVmaze, переводит только новинки и записывает assets/seed_catalog.json.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../lib/data2026.dart';
import '../lib/dict.dart';
import '../lib/models.dart';
import '../lib/net.dart';
import '../lib/translator.dart';
import '../lib/tvmaze.dart';
import '../lib/wiki.dart';

class _Host implements TrHost {
  @override final Map<int, String> custom = {};
  @override final Map<int, String> tr = {};
  @override final Map<int, String> trSrc = {};
  @override final Map<int, int> tried = {};
  final Map<int, Drama> byId;
  _Host(this.byId);
  @override
  Iterable<Drama> get allDramas => byId.values;
  @override
  Set<int> get userIds => <int>{};
  @override
  void changed() {}
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

String _cut(String s, int n) {
  if (s.length <= n) return s;
  final h = s.substring(0, n);
  final i = math.max(h.lastIndexOf('. '), math.max(h.lastIndexOf('! '), h.lastIndexOf('? ')));
  return i > 200 ? h.substring(0, i + 1) : h;
}

Future<void> main() async {
  final sw = Stopwatch()..start();
  final file = File('assets/seed_catalog.json');
  final dramas = <int, Drama>{};
  final summaries = <int, String>{};
  final sumRu = <int, String>{};
  final host = _Host(dramas);
  var prevMax = 0;
  var fullAt = 0;
  var prevGen = 0;

  // 0. Прошлая база из кэша GitHub Actions.
  try {
    final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final l = m['dramas'];
    if (l is List && l.length > 200) {
      for (final e in l) {
        final d = Drama.fromJson(Map<String, dynamic>.from(e as Map));
        dramas[d.id] = d;
      }
      host.tr.addAll(_readMap<String>(m['tr']));
      host.trSrc.addAll(_readMap<String>(m['trSrc']));
      host.tried.addAll(_readMap<int>(m['tried']));
      sumRu.addAll(_readMap<String>(m['sum']));
      prevMax = (m['scanMax'] ?? 0) as int;
      fullAt = (m['fullAt'] ?? 0) as int;
      prevGen = (m['gen'] ?? 0) as int;
    }
  } catch (_) {}
  final hadPrev = dramas.isNotEmpty;
  stdout.writeln('0/5 Прошлая база: ${dramas.length} дорам, названий ${host.tr.length}, описаний ${sumRu.length}');

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final full = !hadPrev || prevMax <= 0 || prevGen < 2 || nowMs - fullAt > 10 * 86400000;

  // 1. Каталог TVmaze.
  stdout.writeln('1/5 Каталог TVmaze (${full ? "полный" : "только свежие страницы"})…');
  var maxPage = -1;
  var page = full ? 0 : math.max(0, prevMax - 4);
  var finished = false;
  var fails = 0;
  var scanned = 0;
  while (!finished && page < 1500) {
    final batch = [page, page + 1, page + 2];
    final res = await Future.wait(batch.map((p) =>
        Net.get(Uri.parse('${Tvmaze.base}/shows?page=$p'), retries: 3)));
    for (var i = 0; i < res.length; i++) {
      final r = res[i];
      if (r.code == 404) { finished = true; break; }
      if (r.code != 200 || r.data is! List) {
        fails++;
        if (fails > 6) { finished = true; break; }
        continue;
      }
      maxPage = batch[i];
      scanned++;
      for (final x in r.data as List) {
        final d = Tvmaze.parse(x, minYear: 0);
        if (d == null) continue;
        dramas[d.id] = d;
        if (!sumRu.containsKey(d.id) && x is Map && x['summary'] is String) {
          final t = Tvmaze.stripHtml(x['summary'] as String);
          if (t.isNotEmpty) summaries[d.id] = t;
        }
      }
    }
    page += 3;
    await Net.sleep(1200);
    if (sw.elapsed > const Duration(minutes: 12)) break;
  }
  if (maxPage < 0) maxPage = prevMax;
  stdout.writeln('   страниц загружено: $scanned, дорам в базе: ${dramas.length}');
  if (dramas.length < 200) {
    stdout.writeln('Каталог не загрузился — оставляем прежний seed.');
    exit(0);
  }

  // 2. Дорамы из Википедии, которых ещё нет в TVmaze.
  stdout.writeln('2/5 Новые и анонсированные дорамы из Wikidata…');
  try {
    final wAll = <Map<String, dynamic>>[];
    for (var pg = 0; pg < 8; pg++) {
      final part = await Wiki.announced(2000, limit: 1500, offset: pg * 1500)
          .timeout(const Duration(minutes: 2), onTimeout: () => null);
      if (part == null || part.isEmpty) break;
      wAll.addAll(part);
    }
    List<Map<String, dynamic>>? rows = wAll.isEmpty ? null : wAll;
    rows ??= await Wiki.announced(DateTime.now().year - 3, limit: 1500)
        .timeout(const Duration(minutes: 2), onTimeout: () => null);
    if (rows != null) {
      final byImdb = <String, int>{};
      final byName = <String, int>{};
      for (final d in dramas.values) {
        if (d.id < 0) continue;
        if (d.imdb.isNotEmpty) byImdb[d.imdb] = d.id;
        byName[nk(d.en)] = d.id;
      }
      // Заглушки, которые уже появились в TVmaze, убираем.
      for (final d in dramas.values.toList()) {
        if (d.id >= 0) continue;
        final real = (d.imdb.isNotEmpty ? byImdb[d.imdb] : null) ?? byName[nk(d.en)];
        if (real != null) {
          final ru = host.tr[d.id];
          if (ru != null && !host.tr.containsKey(real)) {
            host.tr[real] = ru;
            host.trSrc[real] = host.trSrc[d.id] ?? 'wiki';
          }
          dramas.remove(d.id);
          host.tr.remove(d.id);
          host.trSrc.remove(d.id);
        }
      }
      final today = DateTime.now().toIso8601String().substring(0, 10);
      var added = 0;
      for (final r in rows) {
        final en = (r['en'] ?? '').toString();
        if (en.isEmpty) continue;
        final im = (r['im'] ?? '').toString();
        final key = nk(en);
        if ((im.isNotEmpty && byImdb.containsKey(im)) || byName.containsKey(key)) continue;
        final id = -(r['q'] as int);
        final date = (r['date'] ?? '').toString();
        final year = date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;
        final ru = (r['ru'] ?? '').toString();
        final ex = dramas[id];
        if (ex == null) {
          if (added >= 6000) continue;
          dramas[id] = Drama(
            id: id, en: en, year: year, date: date, country: 'KR', imdb: im,
            status: date.isNotEmpty && date.compareTo(today) > 0 ? 'Announced' : 'Ended',
          );
          added++;
        }
        if (hasCyr(ru) && dictLookup(en) == null && !host.tr.containsKey(id)) {
          host.tr[id] = ru;
          host.trSrc[id] = 'wiki';
        }
      }
      stdout.writeln('   добавлено из Wikidata: $added');
    } else {
      stdout.writeln('   Wikidata не ответил — пропускаем');
    }
  } catch (e) {
    stdout.writeln('   Wikidata пропущена: $e');
  }

  // 2b. Для дорам из Википедии ищем постер, рейтинг и описание в TVmaze по IMDb.
  stdout.writeln('2b/5 Дополняем данные дорам из Википедии…');
  var upgraded = 0;
  var lookups = 0;
  for (final d in dramas.values.toList()) {
    if (d.id >= 0 || d.imdb.isEmpty) continue;
    if (((host.tried[d.id] ?? 0) & 64) != 0) continue;
    if (lookups >= 900 || sw.elapsed > const Duration(minutes: 20)) break;
    lookups++;
    host.tried[d.id] = (host.tried[d.id] ?? 0) | 64;
    final j = await Tvmaze.showByImdb(d.imdb);
    await Net.sleep(550);
    if (j == null) continue;
    final real = Tvmaze.parse(j, minYear: 0, forceKR: true);
    if (real == null) continue;
    if (!dramas.containsKey(real.id)) {
      dramas[real.id] = real;
      final ru = host.tr[d.id];
      if (ru != null) {
        host.tr[real.id] = ru;
        host.trSrc[real.id] = host.trSrc[d.id] ?? 'wiki';
      }
      final s = j['summary'];
      if (s is String && !sumRu.containsKey(real.id)) {
        final t = Tvmaze.stripHtml(s);
        if (t.isNotEmpty) summaries[real.id] = t;
      }
      upgraded++;
    }
    dramas.remove(d.id);
    host.tr.remove(d.id);
    host.trSrc.remove(d.id);
  }
  stdout.writeln('   дополнено через TVmaze: $upgraded (запросов: $lookups)');

  // 3. Названия: переводим только то, чего ещё нет.
  stdout.writeln('3/5 Переводим новые названия…');
  final translator = Translator(host);
  var prevLeft = -1;
  for (var r = 0; r < 3 && sw.elapsed < const Duration(minutes: 26); r++) {
    try {
      await translator.run().timeout(const Duration(minutes: 8));
    } catch (e) {
      stdout.writeln('   перевод прерван: $e');
    }
    stdout.writeln('   осталось без точного названия: ${translator.left}');
    if (translator.left == 0 || translator.left == prevLeft) break;
    prevLeft = translator.left;
  }

  // 4. Описания: только для тех, у кого ещё нет перевода.
  stdout.writeln('4/5 Переводим новые описания…');
  final todo = dramas.values.where((d) => summaries.containsKey(d.id) && !sumRu.containsKey(d.id)).toList();
  todo.sort((a, b) => b.date.compareTo(a.date));
  final limited = todo.take(1500).toList();
  var idx = 0;
  var gtxFails = 0;
  var okCount = 0;
  Future<void> worker() async {
    while (idx < limited.length && gtxFails < 12 && sw.elapsed < const Duration(minutes: 38)) {
      final d = limited[idx++];
      final text = _cut(summaries[d.id]!, 700);
      final t = await Translator.gtx(text);
      if (t == null) { gtxFails++; await Net.sleep(1500); continue; }
      gtxFails = 0;
      sumRu[d.id] = t;
      okCount++;
      await Net.sleep(200);
    }
  }
  await Future.wait([worker(), worker(), worker()]);
  stdout.writeln('   новых описаний переведено: $okCount из ${limited.length}');

  // 4b. Проверка данных: дубли, пустые названия, невозможные годы.
  final seenImdb = <String, int>{};
  final yearMax = DateTime.now().year + 4;
  var dropped = 0;
  for (final d in dramas.values.toList()) {
    if (d.en.trim().isEmpty || (d.year != null && d.year! > yearMax)) {
      dramas.remove(d.id);
      dropped++;
      continue;
    }
    if (d.imdb.isEmpty) continue;
    final o = seenImdb[d.imdb];
    if (o == null) {
      seenImdb[d.imdb] = d.id;
    } else if (o < 0 && d.id > 0) {
      dramas.remove(o);
      seenImdb[d.imdb] = d.id;
      dropped++;
    } else {
      dramas.remove(d.id);
      dropped++;
    }
  }
  final noPoster = dramas.values.where((d) => d.poster.isEmpty).length;
  final noRu = dramas.values.where((d) => !host.tr.containsKey(d.id) && dictLookup(d.en) == null).length;
  stdout.writeln('   проверка: убрано $dropped, без постера $noPoster, без русского названия $noRu');

  // 4c. Ежедневное обновление списка актёров и их наград (Wikidata + русский перевод).
  stdout.writeln('4c/5 Обновляем список актёров и их наград…');
  final actorRuOut = Map<String, String>.from(kActorsRu2026);
  final awardsOut = <String, List<Map<String, dynamic>>>{};
  kActorAwards.forEach((k, v) {
    awardsOut[k] = v.map((e) => e.toJson()).toList();
  });
  try {
    final actorNames = <String>{...kActorsRu2026.keys};
    for (final row in k2026) {
      final p = row.split('|');
      if (p.length > 4 && p[4].trim().isNotEmpty) {
        for (final n in p[4].split(',')) {
          if (n.trim().isNotEmpty) actorNames.add(n.trim());
        }
      }
    }
    final nameList = actorNames.toList();
    for (var i = 0; i < nameList.length; i += 25) {
      final b = nameList.sublist(i, math.min(i + 25, nameList.length));
      final ruMap = await Wiki.actorsRu(b);
      if (ruMap != null) {
        for (final n in b) {
          final ru = ruMap[n.toLowerCase()];
          if (ru != null && hasCyr(ru)) actorRuOut[n] = ru;
        }
      }
      final awMap = await Wiki.batchActorAwards(b);
      if (awMap != null) {
        for (final entry in awMap.entries) {
          final key = entry.key;
          final cur = awardsOut.putIfAbsent(key, () => <Map<String, dynamic>>[]);
          final seen = cur.map((e) => '${e['y']}|${nk((e['a'] ?? '').toString())}').toSet();
          for (final r in entry.value.take(10)) {
            final yr = (r['y'] ?? '').trim();
            var aw = (r['aRu'] ?? '').trim();
            final awEn = (r['aEn'] ?? '').trim();
            if (aw.isEmpty && awEn.isNotEmpty) {
              final t = await Translator.gtx(awEn);
              aw = (t != null && hasCyr(t)) ? t.trim() : awEn;
              await Net.sleep(120);
            }
            if (aw.isEmpty) continue;
            var wk = (r['wRu'] ?? '').trim();
            final wkEn = (r['wEn'] ?? '').trim();
            if (wk.isEmpty && wkEn.isNotEmpty) {
              wk = dictLookup(wkEn) ?? '';
              if (wk.isEmpty) {
                final t = await Translator.gtx(wkEn);
                wk = (t != null && hasCyr(t)) ? t.trim() : wkEn;
                await Net.sleep(120);
              }
            }
            final sig = '$yr|${nk(aw)}';
            if (!seen.add(sig)) continue;
            final why = wk.isNotEmpty
                ? 'За яркую роль и актёрское мастерство в проекте «$wk»'
                : 'За выдающееся актёрское мастерство и признание зрителей';
            cur.add({'y': yr.isEmpty ? 'Награда' : yr, 'a': aw, 'w': why});
          }
          cur.sort((a, b) => (b['y'] ?? '').toString().compareTo((a['y'] ?? '').toString()));
        }
      }
    }
    File('/tmp/actors_awards.json').writeAsStringSync(jsonEncode({
      'updated': DateTime.now().toUtc().toIso8601String().substring(0, 16),
      'actorRu': actorRuOut,
      'awards': awardsOut,
    }));
    stdout.writeln('   актёров с русскими именами: ${actorRuOut.length}, со списками наград: ${awardsOut.length}');
  } catch (e) {
    stdout.writeln('   обновление наград актёров пропущено: $e');
  }

  // 5. Запись.
  stdout.writeln('5/5 Пишем assets/seed_catalog.json…');
  final trOut = <String, String>{};
  final srcOut = <String, String>{};
  final triedOut = <String, int>{};
  for (final d in dramas.values) {
    final ru = host.tr[d.id];
    if (ru != null && dictLookup(d.en) == null) {
      trOut['${d.id}'] = ru;
      srcOut['${d.id}'] = host.trSrc[d.id] ?? 'wiki';
    }
    final t = host.tried[d.id];
    if (t != null) triedOut['${d.id}'] = t;
  }
  final sumOut = <String, String>{};
  sumRu.forEach((id, t) { if (dramas.containsKey(id)) sumOut['$id'] = t; });
  final list = dramas.values.toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  final out = <String, dynamic>{
    'v': 1,
    'gen': 2,
    'built': DateTime.now().toUtc().toIso8601String().substring(0, 16),
    'scanMax': maxPage,
    'fullAt': full ? nowMs : fullAt,
    'dramas': list.map((d) => d.toJson()).toList(),
    'tr': trOut,
    'trSrc': srcOut,
    'tried': triedOut,
    'sum': sumOut,
    'actorRu': actorRuOut,
    'awards': awardsOut,
  };
  file.writeAsStringSync(jsonEncode(out));
  stdout.writeln('Готово: дорам ${list.length}, названий ${trOut.length}, '
      'описаний ${sumOut.length}, ${(file.lengthSync() / 1024).round()} КБ, '
      '${sw.elapsed.inMinutes} мин');
  exit(0);
}

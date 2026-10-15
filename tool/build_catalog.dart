// Серверная сборка базы дорам (запускается в GitHub Actions).
// Скачивает каталог TVmaze, переводит названия и описания,
// пишет готовый assets/seed_catalog.json, который попадает внутрь APK.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import '../lib/dict.dart';
import '../lib/models.dart';
import '../lib/net.dart';
import '../lib/translator.dart';
import '../lib/tvmaze.dart';

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

String _cut(String s, int n) {
  if (s.length <= n) return s;
  final h = s.substring(0, n);
  final i = math.max(h.lastIndexOf('. '), math.max(h.lastIndexOf('! '), h.lastIndexOf('? ')));
  return i > 200 ? h.substring(0, i + 1) : h;
}

Future<void> main() async {
  final sw = Stopwatch()..start();
  final dramas = <int, Drama>{};
  final summaries = <int, String>{};
  var maxPage = -1;

  stdout.writeln('1/4 Скачиваем каталог TVmaze…');
  var page = 0;
  var finished = false;
  var fails = 0;
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
      for (final x in r.data as List) {
        final d = Tvmaze.parse(x, minYear: 0);
        if (d == null) continue;
        dramas[d.id] = d;
        if (x is Map && x['summary'] is String) {
          final t = Tvmaze.stripHtml(x['summary'] as String);
          if (t.isNotEmpty) summaries[d.id] = t;
        }
      }
    }
    page += 3;
    await Net.sleep(1200);
    if (sw.elapsed > const Duration(minutes: 12)) break;
  }
  stdout.writeln('   страниц: ${maxPage + 1}, корейских дорам: ${dramas.length}');
  if (dramas.length < 200) {
    stdout.writeln('Каталог не загрузился — оставляем прежний seed.');
    exit(0);
  }

  stdout.writeln('2/4 Переводим названия…');
  final host = _Host(dramas);
  final translator = Translator(host);
  var prevLeft = -1;
  for (var r = 0; r < 3 && sw.elapsed < const Duration(minutes: 22); r++) {
    try {
      await translator.run().timeout(const Duration(minutes: 8));
    } catch (e) {
      stdout.writeln('   перевод прерван: $e');
    }
    stdout.writeln('   осталось без точного названия: ${translator.left}');
    if (translator.left == 0 || translator.left == prevLeft) break;
    prevLeft = translator.left;
  }

  stdout.writeln('3/4 Переводим описания…');
  final todo = dramas.values.where((d) => summaries.containsKey(d.id)).toList();
  todo.sort((a, b) => b.date.compareTo(a.date));
  final limited = todo.take(900).toList();
  final sumRu = <int, String>{};
  var idx = 0;
  var gtxFails = 0;
  Future<void> worker() async {
    while (idx < limited.length && gtxFails < 12 && sw.elapsed < const Duration(minutes: 30)) {
      final d = limited[idx++];
      final text = _cut(summaries[d.id]!, 700);
      final t = await Translator.gtx(text);
      if (t == null) { gtxFails++; await Net.sleep(1500); continue; }
      gtxFails = 0;
      sumRu[d.id] = t;
      await Net.sleep(200);
    }
  }
  await Future.wait([worker(), worker(), worker()]);
  stdout.writeln('   описаний переведено: ${sumRu.length}');

  stdout.writeln('4/4 Пишем assets/seed_catalog.json…');
  final trOut = <String, String>{};
  final srcOut = <String, String>{};
  for (final d in dramas.values) {
    if (dictLookup(d.en) != null) continue;
    final ru = host.tr[d.id];
    if (ru == null) continue;
    trOut['${d.id}'] = ru;
    srcOut['${d.id}'] = host.trSrc[d.id] ?? 'wiki';
  }
  final sumOut = <String, String>{};
  sumRu.forEach((id, t) { sumOut['$id'] = t; });
  final list = dramas.values.toList();
  list.sort((a, b) => b.date.compareTo(a.date));
  final out = <String, dynamic>{
    'v': 1,
    'built': DateTime.now().toUtc().toIso8601String().substring(0, 16),
    'scanMax': maxPage,
    'dramas': list.map((d) => d.toJson()).toList(),
    'tr': trOut,
    'trSrc': srcOut,
    'sum': sumOut,
  };
  File('assets/seed_catalog.json').writeAsStringSync(jsonEncode(out));
  stdout.writeln('Готово: дорам ${list.length}, названий ${trOut.length}, '
      'описаний ${sumOut.length}, ${(File('assets/seed_catalog.json').lengthSync() / 1024).round()} КБ');
  exit(0);
}

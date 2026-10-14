import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'tvmaze.dart';
import 'ui_common.dart';

void openDrama(BuildContext c, Drama d) {
  Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetailPage(drama: d)));
}

class DetailPage extends StatefulWidget {
  final Drama drama;
  const DetailPage({super.key, required this.drama});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? info;
  int? epCount;
  bool loaded = false;
  bool sumBusy = false;
  late final TextEditingController nameCtl;
  Drama get d => widget.drama;

  @override
  void initState() {
    super.initState();
    nameCtl = TextEditingController(text: store.custom[d.id] ?? '');
    _load();
  }
  @override
  void dispose() { nameCtl.dispose(); super.dispose(); }

  Future<void> _load() async {
    store.translator.ensureOne(d);
    if (d.id < 0) { if (mounted) setState(() => loaded = true); return; }
    final res = await Future.wait<dynamic>([Tvmaze.detail(d.id), Tvmaze.episodeCount(d.id)]);
    if (!mounted) return;
    setState(() { info = res[0] as Map<String, dynamic>?; epCount = res[1] as int?; loaded = true; });
    final raw = info == null ? '' : Tvmaze.stripHtml((info!['summary'] ?? '').toString());
    if (raw.isNotEmpty && !store.sumRu.containsKey(d.id)) {
      setState(() => sumBusy = true);
      final r = await store.translator.summary(raw);
      if (r != null) store.setSummary(d, r.text, r.src);
      if (mounted) setState(() => sumBusy = false);
    }
  }

  String _next() {
    final e = info?['_embedded'];
    if (e is Map && e['nextepisode'] is Map) {
      final n = e['nextepisode'] as Map;
      final date = (n['airdate'] ?? '').toString();
      final time = (n['airtime'] ?? '').toString();
      return 'Следующая серия${n['number'] != null ? " №${n['number']}" : ""}: ${fmtDate(date)}${time.isNotEmpty ? ", $time" : ""}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, foregroundColor: C.tx),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final st = store.listOf[d.id];
          final r = store.rate[d.id];
          final title = store.ruTitle(d);
          final next = _next();
          final sum = store.sumRu[d.id];
          final soon = d.date.isNotEmpty && d.date.compareTo(todayIso()) > 0;
          final meta = <String>[
            if (d.year != null) '${d.year}',
            'Корея',
            if (d.status.isNotEmpty) ruStatus(d.status),
            if (d.rating != null) 'TVmaze ${d.rating!.toStringAsFixed(1)}',
          ].where((e) => e.isNotEmpty).join(' · ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: SizedBox(width: 120, height: 180, child: Poster(d))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.15))),
                      const SizedBox(width: 6),
                      SourceBadge(store.trSrc[d.id] ?? (store.custom.containsKey(d.id) ? 'user' : 'dict')),
                    ]),
                    const SizedBox(height: 6),
                    if (title != d.en) Text(d.en, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(meta, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    if (d.network.isNotEmpty) Text(d.network, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    if (soon) Text('Выход: ${fmtDate(d.date)}', style: const TextStyle(color: C.gd, fontWeight: FontWeight.w800)),
                    if (epCount != null && epCount! > 0) Text('Серий вышло: $epCount', style: const TextStyle(color: C.tx2, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(store.titleNote(d), style: const TextStyle(color: C.jd, fontSize: 11)),
                  ]),
                ),
              ]),
              if (d.genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in d.genres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: C.s2, borderRadius: BorderRadius.circular(100)),
                      child: Text(ruGenre(g), style: const TextStyle(fontSize: 12, color: C.tx2)),
                    ),
                ]),
              ],
              if (next.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(next, style: const TextStyle(color: C.jd, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _listBtn('Смотрю', Icons.visibility_rounded, st == 'watch', 'watch')),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('В планах', Icons.bookmark_rounded, st == 'plan', 'plan')),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('Готово', Icons.check_circle_rounded, st == 'done', 'done')),
              ]),
              if (st == 'watch') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Expanded(child: Text('Просмотрено серий', style: TextStyle(fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) - 1),
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: C.tx2)),
                    Text('${store.prog[d.id] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.jd)),
                    IconButton(onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) + 1),
                        icon: const Icon(Icons.add_circle_rounded, color: C.pk)),
                  ]),
                ),
              ],
              const SectionTitle('Ваша оценка'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 1; i <= 10; i++)
                  GestureDetector(
                    onTap: () => store.setRate(d, r == i ? null : i),
                    child: Container(
                      width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: r == i ? C.gd : C.s1,
                        border: Border.all(color: r == i ? C.gd : C.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$i', style: TextStyle(fontWeight: FontWeight.w800, color: r == i ? C.bg : C.tx2)),
                    ),
                  ),
              ]),
              const SectionTitle('Описание'),
              if (sum != null) Text(sum, style: const TextStyle(height: 1.45, fontSize: 14))
              else if (sumBusy || !loaded)
                const Row(children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                  SizedBox(width: 10),
                  Text('Переводим описание…', style: TextStyle(color: C.tx2)),
                ])
              else Text(d.id < 0 ? 'Описание появится ближе к выходу.' : 'Описание недоступно.',
                  style: const TextStyle(color: C.tx2)),
              if (sum != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(store.sumSrc[d.id] == 'ai' ? 'Перевод: ИИ' : 'Перевод: автоматический',
                      style: const TextStyle(color: C.tx2, fontSize: 11)),
                ),
              const SectionTitle('Название по-русски'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: nameCtl,
                    style: const TextStyle(color: C.tx),
                    decoration: InputDecoration(
                      hintText: title, hintStyle: const TextStyle(color: C.tx2),
                      filled: true, fillColor: C.s1,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () { store.setCustom(d, nameCtl.text); FocusScope.of(context).unfocus(); },
                  style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18)),
                  child: const Text('Сохранить'),
                ),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _listBtn(String t, IconData i, bool on, String key) {
    return GestureDetector(
      onTap: () => store.setList(d, on ? null : key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? C.pk : C.s1,
          border: Border.all(color: on ? C.pk : C.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(i, color: on ? C.onPk : C.tx2),
          const SizedBox(height: 4),
          Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? C.onPk : C.tx2)),
        ]),
      ),
    );
  }
}

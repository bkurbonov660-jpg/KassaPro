import 'package:flutter/material.dart';
import 'detail_page.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';

class DramaCard extends StatelessWidget {
  final Drama d;
  const DramaCard(this.d, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = store.listOf[d.id];
    final r = store.rate[d.id];
    final dub = store.dubOf[d.id];
    final isNew = d.seen > 0 && DateTime.now().millisecondsSinceEpoch - d.seen < 3 * 86400000;
    final soon = d.date.isNotEmpty && d.date.compareTo(todayIso()) > 0;
    final sub = (dub != null && dub.isNotEmpty)
        ? '🎙 $dub · ${d.year ?? "скоро"}'
        : (soon ? 'Выход: ${fmtDate(d.date)}' : '${d.year ?? "скоро"} · Корея');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openDrama(context, d),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(fit: StackFit.expand, children: [
              Poster(d),
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: EpisodeCountdownBadge(d, compact: true),
                ),
              ),
              Positioned(left: 8, bottom: 8, right: 8,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  if (r != null) Pill(Icons.star_rounded, '$r', C.gd),
                  if (st == 'watch') Pill(Icons.visibility_rounded, '${store.prog[d.id] ?? 0}', C.jd),
                  if (st == 'plan') const Pill(Icons.bookmark_rounded, '', C.pk),
                  if (st == 'done') const Pill(Icons.check_circle_rounded, '', C.jd),
                  if (st == 'drop') const Pill(Icons.block_rounded, '', C.rd),
                  if (dub != null && dub.isNotEmpty) Pill(Icons.mic_rounded, dub, C.pk),
                  if (isNew) const Pill(Icons.fiber_new_rounded, 'НОВАЯ', C.pk),
                  if (soon && !isNew) const Pill(Icons.schedule_rounded, 'СКОРО', C.gd),
                ])),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(store.ruTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: C.tx, height: 1.2)),
        const SizedBox(height: 2),
        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: (dub != null && dub.isNotEmpty) ? C.pk : C.tx2, fontSize: 12,
              fontWeight: (dub != null && dub.isNotEmpty) ? FontWeight.w700 : FontWeight.normal)),
      ]),
    );
  }
}

class PosterRail extends StatelessWidget {
  final List<Drama> list;
  const PosterRail(this.list, {super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120 * 1.5 + 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 120, child: DramaCard(list[i])),
      ),
    );
  }
}

class LiveCard extends StatelessWidget {
  final LiveItem it;
  final double width;
  const LiveCard(this.it, {this.width = 300, super.key});
  @override
  Widget build(BuildContext context) {
    final d = it.drama;
    final mine = store.listOf.containsKey(d.id);
    final dub = store.dubOf[d.id];
    return GestureDetector(
      onTap: () => openDrama(context, d),
      child: Container(
        width: width, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 64, height: 92, child: Poster(d))),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store.ruTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.wifi_tethering_rounded, size: 15, color: C.jd),
              const SizedBox(width: 5),
              Expanded(child: Text(
                '${it.number != null ? "Серия ${it.number}" : "Новая серия"}${it.time.isNotEmpty ? " · ${it.time}" : ""}',
                style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
            if (dub != null && dub.isNotEmpty)
              Text('Озвучка: $dub', style: const TextStyle(color: C.pk, fontSize: 11, fontWeight: FontWeight.w700))
            else if (mine)
              const Text('из вашего списка', style: TextStyle(color: C.tx2, fontSize: 11)),
          ])),
        ]),
      ),
    );
  }
}

class WatchCard extends StatelessWidget {
  final Drama d;
  const WatchCard(this.d, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = store.prog[d.id] ?? 0;
    final t = store.totals[d.id];
    final fresh = store.newEps(d);
    final dub = store.dubOf[d.id];
    final canAdd = t == null || p < t;
    return GestureDetector(
      onTap: () => openDrama(context, d),
      child: Container(
        width: 310, padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 64, height: 92, child: Poster(d))),
          const SizedBox(width: 12),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(store.ruTitle(d), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(t != null ? 'Просмотрено: $p из $t' : 'Просмотрено: $p',
              style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700)),
            if (dub != null && dub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('🎙 Озвучка: $dub', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.pk, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            if (fresh > 0)
              Text('Новых серий: $fresh', style: const TextStyle(color: C.gd, fontSize: 11.5, fontWeight: FontWeight.w800))
            else
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: EpisodeCountdownBadge(d, compact: true),
              ),
          ])),
          IconButton(
            onPressed: canAdd ? () => store.setProg(d, p + 1) : null,
            icon: const Icon(Icons.add_circle_rounded, color: C.pk, size: 30)),
        ]),
      ),
    );
  }
}

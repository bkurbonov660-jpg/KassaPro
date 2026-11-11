import 'package:flutter/material.dart';
import 'actor_page.dart';
import 'detail_page.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';

// ── Карточка дорамы точь-в-точь как на фото №1 (73563.jpg):
// • Скруглённый постер 2:3
// • В правом верхнем углу квадратная кнопка-галочка (быстрое добавление/отметка просмотра)
// • Внизу слева тёмная капсула оценки (★ 10) + круглая бирюзовая галочка статуса
// • Под ней капсула студии озвучки с розовой иконкой микрофона (🎙 SoftBox)
// • Снизу название дорамы
class DramaCard extends StatelessWidget {
  final Drama d;
  final String? roleBadge;
  const DramaCard(this.d, {this.roleBadge, super.key});

  void _quickToggleList(BuildContext context) {
    final cur = store.listOf[d.id];
    if (cur == 'done') {
      store.setList(d, 'watch');
    } else if (cur == 'watch') {
      store.setList(d, 'done');
    } else if (cur == 'plan') {
      store.setList(d, 'watch');
    } else {
      store.setList(d, 'done');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = store.listOf[d.id];
    final r = store.rate[d.id];
    final dispRate = r != null ? '$r' : (d.rating != null ? d.rating!.toStringAsFixed(1) : null);
    final dub = store.dubOf[d.id] ?? ((st == 'watch' || st == 'done') ? 'SoftBox' : null);
    final soon = d.date.isNotEmpty && d.date.compareTo(todayIso()) > 0;
    final epTot = store.totals[d.id];
    final epPart = (epTot != null && epTot > 0 && epTot <= 120) ? ' · $epTot сер.' : '';
    final baseSub = soon ? 'Премьера: ${fmtDate(d.date)}' : '${d.year ?? 2026} · ${d.network.isNotEmpty ? d.network : "Корея"}$epPart';
    final sub = (roleBadge != null && roleBadge!.trim().isNotEmpty) ? 'Роль: ${roleBadge!.trim()}' : baseSub;
    final inList = st != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openDrama(context, d),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              Poster(d),
              // Мягкое затемнение снизу постера для идеальной читаемости плашек
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    ),
                  ),
                ),
              ),
              // Таймер серии в левом верхнем углу (если сериал онгоинг)
              Positioned(
                top: 8,
                left: 8,
                right: 44,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: EpisodeCountdownBadge(d, compact: true),
                ),
              ),
              // Правый верхний угол: квадратная кнопка-галочка (как на фото 73563.jpg)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _quickToggleList(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xD9191424),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: inList ? C.gd : const Color(0x45FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      inList ? Icons.check_rounded : Icons.add_rounded,
                      size: 17,
                      color: inList ? C.gd : C.tx,
                    ),
                  ),
                ),
              ),
              // Нижний левый блок плашек (оценка ★ + круглая бирюзовая галочка + капсула озвучки SoftBox)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dispRate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xE6151020),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0x33FFFFFF), width: 0.6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star_rounded, size: 13, color: C.gd),
                              const SizedBox(width: 3),
                              Text(
                                dispRate,
                                style: const TextStyle(color: C.tx, fontSize: 11.5, fontWeight: FontWeight.w900),
                              ),
                            ]),
                          ),
                        if (st != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xE6151020),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: const Color(0x33FFFFFF), width: 0.6),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(
                                st == 'done'
                                    ? Icons.check_circle_rounded
                                    : (st == 'watch'
                                        ? Icons.play_circle_fill_rounded
                                        : (st == 'plan' ? Icons.bookmark_rounded : Icons.block_rounded)),
                                size: 13.5,
                                color: st == 'drop' ? C.rd : (st == 'plan' ? C.pk : C.jd),
                              ),
                              if (st == 'watch' && (store.prog[d.id] ?? 0) > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${store.prog[d.id]}',
                                  style: const TextStyle(color: C.jd, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ]),
                          ),
                        ],
                      ],
                    ),
                    if (dub != null && dub.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xE6151020),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0x4DFF6B96), width: 0.7),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.mic_none_rounded, size: 12, color: C.pk),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              dub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.pk, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          store.ruTitle(d),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx, height: 1.18),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: (roleBadge != null && roleBadge!.trim().isNotEmpty) ? C.gd : C.tx2,
            fontWeight: (roleBadge != null && roleBadge!.trim().isNotEmpty) ? FontWeight.w700 : FontWeight.w500,
            fontSize: 11.5,
          ),
        ),
      ]),
    );
  }
}

class ActorGridCard extends StatelessWidget {
  final Actor actor;
  const ActorGridCard(this.actor, {super.key});

  @override
  Widget build(BuildContext context) {
    final photo = store.actorPhotoOf(actor.name, actor.photo);
    final ru = store.ruActor(actor.name);
    final fav = store.isFavActor(actor.name);
    final bio = store.actorBioOf(actor.name);
    final drCount = store.dramasForActorKey(actor.name).length;
    final sub = bio != null
        ? '${bio.roleLabel} · ${bio.totalDramas} дорам'
        : (drCount > 0 ? 'Дорам в базе: $drCount' : (actor.role.isNotEmpty ? actor.role : 'Актёр K-Drama'));
    final ph = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.s2, C.s1], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, size: 42, color: C.tx2),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: actor))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              photo.isEmpty ? ph : CachedPic(photo, placeholder: ph, fit: BoxFit.cover),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => store.toggleFavActor(actor.name),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xD9191424),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: fav ? C.pk : const Color(0x45FFFFFF)),
                    ),
                    child: Icon(
                      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 16,
                      color: fav ? C.pk : C.tx,
                    ),
                  ),
                ),
              ),
              if (bio != null && bio.nativeName.isNotEmpty)
                Positioned(
                  left: 8,
                  bottom: 8,
                  right: 8,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xE6151020),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        bio.nativeName.split('·').first.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: C.gd, fontSize: 10.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          ru,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: C.tx2, fontSize: 11.5),
        ),
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
      height: 126 * 1.5 + 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 126, child: DramaCard(list[i])),
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
    final st = store.listOf[d.id];
    final dub = store.dubOf[d.id] ?? 'SoftBox';
    final tot = store.totals[d.id];
    final epNum = it.number ?? 1;
    final isPremiere = epNum == 1;
    final isFinale = tot != null && tot > 1 && epNum == tot;
    final castPreview = store.castOf(d).take(2).map(store.ruActor).join(', ');

    return GestureDetector(
      onTap: () => openDrama(context, d),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.s1,
          border: Border.all(color: isPremiere ? const Color(0x66FF6B96) : (st == 'watch' ? const Color(0x6642E2B8) : C.line)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 68, height: 98, child: Poster(d))),
              if (isPremiere || isFinale)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPremiere ? C.pk : C.gd,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isPremiere ? 'ПРЕМЬЕРА' : 'ФИНАЛ',
                      style: const TextStyle(color: C.bg, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (d.network.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: C.line),
                        ),
                        child: Text(
                          d.network,
                          style: const TextStyle(color: C.tx2, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    if (d.rating != null) ...[
                      const Icon(Icons.star_rounded, size: 12.5, color: C.gd),
                      const SizedBox(width: 2),
                      Text(
                        d.rating!.toStringAsFixed(1),
                        style: const TextStyle(color: C.tx, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                    const Spacer(),
                    if (it.time.isNotEmpty)
                      Text(
                        '${it.time} KST',
                        style: const TextStyle(color: C.tx2, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  store.ruTitle(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.tx),
                ),
                if (castPreview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    castPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.tx2, fontSize: 11.5),
                  ),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 15, color: C.jd),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Серия $epNum${tot != null && tot > 0 ? " из $tot" : ""} · $dub',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          if (store.showWatchBtn)
            IconButton(
              tooltip: 'Смотреть серию $epNum',
              onPressed: () => showWatchOptionsSheet(context, d, epNum: epNum),
              icon: const Icon(Icons.play_arrow_rounded, color: C.tx, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: C.bg,
                side: const BorderSide(color: C.line),
                visualDensity: VisualDensity.compact,
              ),
            ),
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
        width: 300,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 64, height: 92, child: Poster(d))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.ruTitle(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  t != null ? 'Серия $p из $t' : 'Серия $p',
                  style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                if (dub != null && dub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Озвучка: $dub',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.pk, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (fresh > 0)
                  Text('Новых серий: $fresh', style: const TextStyle(color: C.gd, fontSize: 11.5, fontWeight: FontWeight.w800))
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: EpisodeCountdownBadge(d, compact: true),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: canAdd ? () => store.setProg(d, p + 1) : null,
            icon: const Icon(Icons.add_circle_rounded, color: C.pk, size: 30),
          ),
        ]),
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';
import 'tvmaze.dart';
import 'ui_common.dart';
import 'widgets.dart';

class ActorPage extends StatefulWidget {
  final Actor actor;
  const ActorPage({super.key, required this.actor});
  @override
  State<ActorPage> createState() => _ActorPageState();
}

class _ActorPageState extends State<ActorPage> {
  List<Drama>? shows;
  List<AwardItem> awards = const <AwardItem>[];
  bool awardsBusy = true;
  String photo = '';

  @override
  void initState() {
    super.initState();
    photo = store.actorPhotoOf(widget.actor.name, widget.actor.photo);
    awards = store.awardsOf(widget.actor.name);
    _load();
  }

  Future<void> _load() async {
    store.ensureActorNames([widget.actor.name]);
    if (photo.isEmpty) {
      store.ensureActorPhoto(widget.actor.name).then((ph) {
        if (ph.isNotEmpty && mounted) setState(() => photo = ph);
      });
    }
    store.ensureActorAwards(widget.actor.name).then((list) {
      if (mounted) {
        setState(() {
          awards = list;
          awardsBusy = false;
        });
      }
    });
    final out = await store.actorDramasFor(widget.actor);
    if (mounted) setState(() => shows = out);
  }

  Widget _awardCard(AwardItem aw) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.s1,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.s2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x80FFC857)),
          ),
          child: const Icon(Icons.emoji_events_rounded, color: C.gd, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: C.gd,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  aw.year.isEmpty ? 'Награда' : aw.year,
                  style: const TextStyle(color: C.bg, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  aw.award,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx, height: 1.2),
                ),
              ),
            ]),
            if (aw.why.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                aw.why,
                style: const TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actor;
    final ph = Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 40));
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        foregroundColor: C.tx,
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final fav = store.isFavActor(a.name);
              return IconButton(
                tooltip: fav ? 'Убрать из любимых актёров' : 'Добавить в любимые актёры',
                onPressed: () => store.toggleFavActor(a.name),
                icon: Icon(
                  fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? C.pk : C.tx,
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = shows;
          final awList = store.awardsOf(a.name).isNotEmpty ? store.awardsOf(a.name) : awards;
          return LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 150).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 80;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ClipOval(child: SizedBox(width: 84, height: 84,
                        child: photo.isEmpty ? ph
                          : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.ruActor(a.name), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                        if (store.ruActor(a.name) != a.name)
                          Text(a.name, style: const TextStyle(color: C.tx2, fontSize: 13)),
                        if (a.role.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('Роль: ${a.role}', style: const TextStyle(color: C.pk, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${list == null ? "Загружаем дорамы…" : "Дорам: ${list.length}"} · Наград: ${awList.length}',
                          style: const TextStyle(color: C.jd, fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Builder(builder: (_) {
                          final fav = store.isFavActor(a.name);
                          return OutlinedButton.icon(
                            onPressed: () => store.toggleFavActor(a.name),
                            icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 16, color: fav ? C.pk : C.tx2),
                            label: Text(
                              fav ? 'В любимых актёрах' : 'В любимые актёры',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fav ? C.pk : C.tx),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: C.s1,
                              side: BorderSide(color: fav ? C.pk : C.line),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 34),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            ),
                          );
                        }),
                      ])),
                    ]),
                    const SectionTitle('Награды и достижения'),
                    if (awList.isEmpty && awardsBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                          SizedBox(width: 10),
                          Text('Ищем награды актёра…', style: TextStyle(color: C.tx2)),
                        ]),
                      )
                    else if (awList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                          'Подтверждённые награды обновляются автоматически при ежедневной синхронизации базы.',
                          style: TextStyle(color: C.tx2, fontSize: 13),
                        ),
                      )
                    else
                      Column(children: [for (final aw in awList) _awardCard(aw)]),
                    const SectionTitle('Дорамы и сериалы с участием актёра'),
                  ]),
                ),
              ),
              if (list == null)
                const SliverToBoxAdapter(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: C.pk))))
              else if (list.isEmpty)
                const SliverToBoxAdapter(child: EmptyBox(Icons.tv_off_rounded, 'Дорам не найдено',
                  'Пока не удалось найти дорамы с участием этого актёра.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => DramaCard(list[i], key: ValueKey(list[i].id)),
                      childCount: list.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, mainAxisSpacing: 16, crossAxisSpacing: gap,
                      childAspectRatio: cw / ch),
                  ),
                ),
            ]);
          });
        },
      ),
    );
  }
}

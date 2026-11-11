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
      Tvmaze.findPerson(widget.actor.name).then((res) {
        final ph = res.$2;
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
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: C.s2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x66FFB84D)),
          ),
          child: const Icon(Icons.emoji_events_rounded, color: C.gd, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx, height: 1.2),
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
    final ph = Container(
      color: C.s2,
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: C.tx2, size: 48),
    );
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
                tooltip: fav ? 'Убрать из любимых актёров' : 'В любимые актёры',
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
          final bio = store.actorBioOf(a.name);
          final ruName = bio?.ruName ?? store.ruActor(a.name);
          final enName = bio?.enName ?? a.name;
          final roleType = bio?.roleLabel ?? 'Актёр';
          final drCount = list?.length ?? (bio?.totalDramas ?? store.dramasForActorKey(a.name).length);
          final mainCount = bio?.mainRoles ?? math.max(1, (drCount * 0.6).round());
          final yearsRange = bio?.yearsActive ?? '2018–2026';
          final nameLine = <String>[
            ruName,
            if (enName != ruName) enName,
            if (bio != null && bio.nativeName.isNotEmpty) bio.nativeName,
            if (bio != null && bio.altNames.isNotEmpty) bio.altNames,
          ].join(' · ');

          return LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 160).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 78;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // 1. Портрет 155x205 со скруглением 20px (точь-в-точь как на фото 73563.jpg)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 155,
                        height: 205,
                        child: photo.isEmpty ? ph : CachedPic(photo, placeholder: ph, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 2. Хлебные крошки: Главная / Каталог / Актриса (или Актёр)
                    Text(
                      'Главная  /  Каталог  /  $roleType',
                      style: const TextStyle(color: C.tx2, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    // 3. Крупный заголовок КАПСОМ
                    Text(
                      ruName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: C.tx,
                        letterSpacing: 0.4,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 4. Мультиязычная строка имён (RU · EN · Hangul · Hanja)
                    Text(
                      nameLine,
                      style: const TextStyle(color: C.tx2, fontSize: 13.5, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    // 5. Строка статистики с оранжево-золотым акцентом (как на фото 73563.jpg)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14, height: 1.45, fontFamily: 'Roboto'),
                        children: [
                          TextSpan(
                            text: roleType,
                            style: const TextStyle(color: C.gd, fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '  /  ', style: TextStyle(color: C.tx2)),
                          TextSpan(
                            text: '$drCount дорам',
                            style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '  /  ', style: TextStyle(color: C.tx2)),
                          TextSpan(
                            text: '$mainCount главных ролей',
                            style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '  /  ', style: TextStyle(color: C.tx2)),
                          TextSpan(
                            text: yearsRange,
                            style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    if (bio != null && bio.birthDate.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${bio.birthDate}${bio.height.isNotEmpty ? " · Рост ${bio.height}" : ""}',
                        style: const TextStyle(color: C.tx2, fontSize: 13.5),
                      ),
                    ],
                    if (bio != null && bio.birthPlace.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Место: ${bio.birthPlace}',
                        style: const TextStyle(color: C.tx2, fontSize: 12.5),
                      ),
                    ],
                    if (bio != null && bio.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: C.s1,
                          border: Border.all(color: C.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          bio.bio,
                          style: const TextStyle(color: C.tx, fontSize: 13.5, height: 1.45),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    // 6. Заголовок ФИЛЬМОГРАФИЯ + число проектов (как на фото 73563.jpg)
                    Row(children: [
                      const Text(
                        'ФИЛЬМОГРАФИЯ',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: C.tx,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${list?.length ?? drCount}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: C.tx2,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              if (list == null)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: C.pk)),
                  ),
                )
              else if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyBox(
                    Icons.tv_off_rounded,
                    'Дорам не найдено',
                    'Пока не удалось загрузить проекты с участием этого актёра.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => DramaCard(list[i], key: ValueKey(list[i].id)),
                      childCount: list.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: gap,
                      childAspectRatio: cw / ch,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Builder(builder: (context) {
                    final coStars = store.coStarsOf(a.name);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (coStars.isNotEmpty) ...[
                        SectionTitle('СВЯЗИ АКТЁРОВ · СНИМАЛИСЬ ВМЕСТЕ (${coStars.length})'),
                        const Text(
                          'Коллеги и партнёры по съёмочной площадке, с которыми актёр играл в одних дорамах:',
                          style: TextStyle(color: C.tx2, fontSize: 12.5),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 146,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: coStars.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, idx) {
                              final peer = coStars[idx].$1;
                              final shared = coStars[idx].$2;
                              final peerPh = store.actorPhotoOf(peer.name, peer.photo);
                              final sharedNames = shared.map(store.ruTitle).join(' • ');
                              return GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => ActorPage(actor: peer)),
                                ),
                                child: Container(
                                  width: 230,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: C.s1,
                                    border: Border.all(color: shared.length >= 2 ? const Color(0x66FF6B96) : C.line),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 58,
                                          height: 80,
                                          child: peerPh.isEmpty
                                              ? Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))
                                              : CachedPic(peerPh,
                                                  placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: shared.length >= 2 ? const Color(0x28FF6B96) : C.bg,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(color: shared.length >= 2 ? const Color(0x66FF6B96) : C.line),
                                              ),
                                              child: Text(
                                                'ОБЩИХ ДОРАМ: ${shared.length}',
                                                style: TextStyle(
                                                  color: shared.length >= 2 ? C.pk : C.jd,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              store.ruActor(peer.name),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              sharedNames,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: C.tx2, fontSize: 11.2, height: 1.2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SectionTitle('НАГРАДЫ И ДОСТИЖЕНИЯ'),
                    if (awList.isEmpty && awardsBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                          SizedBox(width: 10),
                          Text('Загружаем награды…', style: TextStyle(color: C.tx2)),
                        ]),
                      )
                    else if (awList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: C.s1,
                          border: Border.all(color: C.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Подтверждённые награды обновляются автоматически при синхронизации базы.',
                          style: TextStyle(color: C.tx2, fontSize: 13),
                        ),
                      )
                    else
                      Column(children: [for (final aw in awList) _awardCard(aw)]),
                    ]);
                  }),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }
}

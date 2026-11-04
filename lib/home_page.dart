import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'actor_page.dart';
import 'config.dart';
import 'data2026.dart';
import 'detail_page.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'store.dart';
import 'taste.dart';
import 'ui_common.dart';
import 'widgets.dart';

const List<(String, List<String>)> kMoods = [
  ('Посмеяться', ['Comedy']),
  ('Поплакать', ['Drama', 'Family']),
  ('Нервы на пределе', ['Thriller', 'Crime', 'Mystery']),
  ('Мистика и фэнтези', ['Fantasy', 'Supernatural', 'Horror', 'Science-Fiction']),
  ('Романтика', ['Romance']),
  ('Экшен', ['Action', 'Adventure', 'War']),
  ('История', ['History']),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int day = 0;
  int mood = -1;
  int trope = -1;
  int shuffle = 1;
  static const List<String> _wd = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  String _label(int i) {
    if (i == 0) return 'Сегодня';
    if (i == 1) return 'Завтра';
    final dt = DateTime.now().add(Duration(days: i));
    return '${_wd[dt.weekday - 1]}, ${dt.day}';
  }

  void _pickDay(int i) {
    setState(() => day = i);
    store.loadDay(isoPlus(i));
  }

  Widget _featuredSpotlight(BuildContext context, List<Drama> top) {
    Drama? hero;
    for (final d in store.allDramas) {
      final k = d.en.toLowerCase();
      if (k.contains('perfect crown') || k.contains('love in disguise') || k.contains('can this love')) {
        hero = d;
        if (d.poster.isNotEmpty) break;
      }
    }
    hero ??= top.isNotEmpty ? top.first : null;
    if (hero == null) return const SizedBox.shrink();
    final d = hero;
    final title = store.ruTitle(d);
    final genres = d.genres.isEmpty ? 'Драма, Романтика' : d.genres.take(3).map(ruGenre).join(', ');

    return GestureDetector(
      onTap: () => openDrama(context, d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: C.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Poster(d),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 1.0],
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.45),
                      C.bg.withOpacity(0.96),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: C.pk,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ПРЕМЬЕРА 2026',
                            style: TextStyle(color: C.onPk, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xCC1E182B),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('16+ · HD · SoftBox',
                              style: TextStyle(color: C.tx, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title.toUpperCase(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: C.tx,
                        letterSpacing: 0.8,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d.year ?? 2026} • 1 сезон • $genres',
                      style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    if (store.showWatchBtn)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: () => showWatchOptionsSheet(context, d),
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 21),
                                label: const Text(
                                  'СМОТРЕТЬ СЕЙЧАС',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.7),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: () => openDrama(context, d),
                                icon: const Icon(Icons.info_outline_rounded, color: C.tx, size: 17),
                                label: const Text(
                                  'О ДОРАМЕ',
                                  style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 11.5),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xCC171221),
                                  side: const BorderSide(color: C.line),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        height: 40,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => openDrama(context, d),
                          icon: const Icon(Icons.bookmark_add_rounded, color: C.onPk, size: 19),
                          label: const Text(
                            'ПОДРОБНЕЕ · В МОЙ СПИСОК',
                            style: TextStyle(color: C.onPk, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.8),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: C.pk,
                            foregroundColor: C.onPk,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actorsStrip(BuildContext context) {
    final actors = kPopularCrushes.take(14).toList();
    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final a = actors[i];
          final ph = store.actorPhotoOf(a.name, a.photo);
          final ru = store.ruActor(a.name);
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: a))),
            child: SizedBox(
              width: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 86,
                      height: 102,
                      child: ph.isEmpty
                          ? Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 32))
                          : CachedPic(
                              ph,
                              placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 32)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ru,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.tx, height: 1.12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final soon = store.upcoming();
        final fresh = store.fresh();
        final top = store.topYear();
        final lu = store.lastUpdate;
        final status = store.refreshing
            ? 'Обновляем…'
            : lu == null
                ? 'Загрузка…'
                : 'Обновлено в ${two(lu.hour)}:${two(lu.minute)}';
        final iso = isoPlus(day);
        final items = store.liveDays[iso];
        final busy = store.dayBusy.contains(iso);
        final watching = store.listItems('watch').take(10).toList();
        final List<Drama> picks = mood >= 0
            ? store.pickByMood(kMoods[mood].$2, shuffle)
            : (trope >= 0 ? Taste.byTrope(kTropes[trope], seed: shuffle) : <Drama>[]);

        return SafeArea(
          child: RefreshIndicator(
            color: C.pk,
            backgroundColor: C.s1,
            onRefresh: () => store.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 42,
                      height: 42,
                      errorBuilder: (_, __, ___) => Container(
                        width: 42,
                        height: 42,
                        color: C.s2,
                        child: const Icon(Icons.favorite_rounded, color: C.pk, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(Cfg.appName,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                        const SizedBox(height: 2),
                        Text('В базе: ${fmtNum(store.krCount)} дорам · $status',
                            style: const TextStyle(color: C.tx2, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: store.refreshing ? null : () => store.refresh(),
                    icon: store.refreshing
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk))
                        : const Icon(Icons.refresh_rounded, color: C.tx2),
                    style: IconButton.styleFrom(backgroundColor: C.s1, side: const BorderSide(color: C.line)),
                  ),
                ]),
                const SizedBox(height: 14),
                _featuredSpotlight(context, top),
                if (store.noticeVisible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                        color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SvgPicture.string(kTgSvg, width: 32, height: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              store.noticeTitle.isEmpty ? 'Дорама Пульс 4.0' : store.noticeTitle,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              store.noticeText,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, color: C.tx2, height: 1.38),
                            ),
                          ]),
                        ),
                        IconButton(
                          onPressed: store.closeNotice,
                          icon: const Icon(Icons.close_rounded, color: C.tx2, size: 19),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => openTelegram(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                              decoration: BoxDecoration(color: C.pk, borderRadius: BorderRadius.circular(12)),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                SvgPicture.string(kTgSvg, width: 18, height: 18),
                                const SizedBox(width: 8),
                                const Text('Канал проекта · Обновить',
                                    style: TextStyle(color: C.onPk, fontWeight: FontWeight.w800, fontSize: 12.5)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => showAppUpdateDialog(context, markDismissed: false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: C.line),
                            backgroundColor: C.bg,
                            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child:
                              const Text('Подробнее', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ]),
                    ]),
                  ),
                const SectionTitle('Популярные актёры и звёзды дорам'),
                _actorsStrip(context),
                if (watching.isNotEmpty) const SectionTitle('Продолжить просмотр'),
                if (watching.isNotEmpty)
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: watching.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => WatchCard(watching[i]),
                    ),
                  ),
                const SectionTitle('Расписание серий', live: true),
                ChipRow([
                  for (var i = 0; i < 7; i++) FilterPill(_label(i), day == i, () => _pickDay(i)),
                ]),
                const SizedBox(height: 10),
                if (items == null)
                  (busy
                      ? const Row(children: [
                          SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                          SizedBox(width: 10),
                          Text('Загружаем расписание…', style: TextStyle(color: C.tx2)),
                        ])
                      : const Text('Расписание пока недоступно. Потяните вниз для обновления.',
                          style: TextStyle(color: C.tx2)))
                else if (items.isEmpty)
                  Text(day == 0 ? 'Сегодня новых серий не нашли.' : 'На этот день серий пока не анонсировано.',
                      style: const TextStyle(color: C.tx2))
                else
                  Column(children: [
                    for (final it in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(height: 116, child: LiveCard(it, width: double.infinity)),
                      ),
                  ]),
                const RecSections(),
                const SectionTitle('Подбор по настроению и темам'),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showRoulette(context),
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Случайная дорама'),
                    style: FilledButton.styleFrom(
                      backgroundColor: C.pk,
                      foregroundColor: C.onPk,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ChipRow([
                  for (var i = 0; i < kMoods.length; i++)
                    FilterPill(
                      kMoods[i].$1,
                      mood == i,
                      () => setState(() {
                        mood = mood == i ? -1 : i;
                        trope = -1;
                        shuffle++;
                      }),
                    ),
                ]),
                const SizedBox(height: 8),
                ChipRow([
                  for (var i = 0; i < kTropes.length; i++)
                    FilterPill(
                      kTropes[i].label,
                      trope == i,
                      () => setState(() {
                        trope = trope == i ? -1 : i;
                        mood = -1;
                        shuffle++;
                      }),
                    ),
                ]),
                const SizedBox(height: 10),
                if (mood >= 0 || trope >= 0) ...[
                  if (picks.isEmpty)
                    const Text('Пока нет подходящих дорам.', style: TextStyle(color: C.tx2))
                  else ...[
                    PosterRail(picks),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => shuffle++),
                        icon: const Icon(Icons.shuffle_rounded, color: C.pk),
                        label: const Text('Другие варианты',
                            style: TextStyle(color: C.pk, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
                if (top.isNotEmpty) SectionTitle('Хиты ${DateTime.now().year} года'),
                if (top.isNotEmpty) PosterRail(top),
                if (soon.isNotEmpty) const SectionTitle('Скоро выходят и анонсы'),
                if (soon.isNotEmpty) PosterRail(soon),
                if (fresh.isNotEmpty) const SectionTitle('Новые находки'),
                if (fresh.isNotEmpty) PosterRail(fresh),
              ],
            ),
          ),
        );
      },
    );
  }
}

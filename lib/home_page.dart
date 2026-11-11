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
  int schedFilter = 0; // 0: Все, 1: В моих списках, 2: Премьеры и финалы
  int mood = -1;
  int trope = -1;
  int shuffle = 1;
  static const List<String> _wd = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  String _label(int i) {
    if (i == -1) return 'Вчера';
    if (i == 0) return 'Сегодня';
    if (i == 1) return 'Завтра';
    final dt = DateTime.now().add(Duration(days: i));
    return '${_wd[dt.weekday - 1]}, ${dt.day} ${Cfg.months[dt.month - 1]}';
  }

  void _pickDay(int i) {
    setState(() => day = i);
    store.loadDay(isoPlus(i));
  }

  // ── Минималистичный классический блок «Топ недели» (вместо привязанной одной дорамы) ──
  Widget _topOfWeekSection(BuildContext context, List<Drama> weekTop) {
    if (weekTop.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(
            children: [
              const Text(
                'Топ недели',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.tx, letterSpacing: -0.2),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ТОП-${weekTop.length}',
                  style: const TextStyle(color: C.tx2, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
              ),
              const Spacer(),
              const Text(
                'Листайте →',
                style: TextStyle(color: C.tx2, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: weekTop.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final d = weekTop[i];
              final rank = (i + 1).toString().padLeft(2, '0');
              final title = store.ruTitle(d);
              final genres = d.genres.isEmpty ? 'Драма' : d.genres.take(2).map(ruGenre).join(' · ');
              final rateVal = store.rate[d.id] != null
                  ? '${store.rate[d.id]}'
                  : (d.rating != null ? d.rating!.toStringAsFixed(1) : '8.6');
              final dub = store.dubOf[d.id] ?? 'SoftBox';

              return GestureDetector(
                onTap: () => openDrama(context, d),
                child: Container(
                  width: 304,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SizedBox(width: 88, height: 130, child: Poster(d)),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xE60E0B14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x38FFFFFF), width: 0.6),
                              ),
                              child: Text(
                                '#$rank',
                                style: TextStyle(
                                  color: i < 3 ? C.gd : C.tx,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 13.5, color: C.gd),
                                const SizedBox(width: 3),
                                Text(
                                  rateVal,
                                  style: const TextStyle(color: C.tx, fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${d.year ?? 2026} · ${d.network.isNotEmpty ? d.network : "Корея"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: C.tx2, fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: C.tx,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$genres · $dub',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.tx2, fontSize: 11.5),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                if (store.showWatchBtn) ...[
                                  Expanded(
                                    child: SizedBox(
                                      height: 32,
                                      child: OutlinedButton.icon(
                                        onPressed: () => showWatchOptionsSheet(context, d),
                                        icon: const Icon(Icons.play_arrow_rounded, size: 16, color: C.tx),
                                        label: const Text(
                                          'Смотреть',
                                          style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 11.5),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: C.bg,
                                          side: const BorderSide(color: C.line),
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                SizedBox(
                                  height: 32,
                                  child: OutlinedButton(
                                    onPressed: () => openDrama(context, d),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: C.bg,
                                      side: const BorderSide(color: C.line),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      store.showWatchBtn ? 'О дораме' : 'Открыть карточку',
                                      style: const TextStyle(color: C.tx2, fontWeight: FontWeight.w700, fontSize: 11.5),
                                    ),
                                  ),
                                ),
                              ],
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
      ],
    );
  }

  Widget _actorsStrip(BuildContext context) {
    final actors = kPopularCrushes.take(14).toList();
    return SizedBox(
      height: 154,
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
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 84,
                      height: 104,
                      child: ph.isEmpty
                          ? Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 30))
                          : CachedPic(
                              ph,
                              placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 30)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ru,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.tx, height: 1.15),
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
        final weekTop = store.topOfWeek();
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
            color: C.tx,
            backgroundColor: C.s1,
            onRefresh: () => store.refresh(force: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 38,
                      height: 38,
                      errorBuilder: (_, __, ___) => Container(
                        width: 38,
                        height: 38,
                        color: C.s2,
                        child: const Icon(Icons.favorite_rounded, color: C.pk, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(Cfg.appName,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                        const SizedBox(height: 1),
                        Text('В базе: ${fmtNum(store.krCount)} · $status',
                            style: const TextStyle(color: C.tx2, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: store.refreshing ? null : () => store.refresh(force: true),
                    icon: store.refreshing
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.tx2))
                        : const Icon(Icons.refresh_rounded, color: C.tx2, size: 20),
                    style: IconButton.styleFrom(backgroundColor: C.s1, side: const BorderSide(color: C.line)),
                  ),
                ]),
                const SizedBox(height: 10),
                if (store.noticeVisible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: C.s1,
                      border: Border.all(color: C.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.string(kTgSvg, width: 24, height: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => openTelegram(context),
                            child: Text(
                              store.noticeTitle.isEmpty ? 'Канал проекта в Telegram · Обновления' : store.noticeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: C.tx),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => openTelegram(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Telegram', style: TextStyle(color: C.pk, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        IconButton(
                          onPressed: store.closeNotice,
                          icon: const Icon(Icons.close_rounded, color: C.tx2, size: 17),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                _topOfWeekSection(context, weekTop),
                const SectionTitle('Популярные актёры'),
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
                SectionTitle(
                  'Расписание выхода серий',
                  live: true,
                  trailing: items != null && items.isNotEmpty ? 'Серий: ${items.length}' : null,
                ),
                ChipRow([
                  for (var i = -1; i < 13; i++) FilterPill(_label(i), day == i, () => _pickDay(i)),
                ]),
                const SizedBox(height: 8),
                ChipRow([
                  FilterPill('Все серии', schedFilter == 0, () => setState(() => schedFilter = 0)),
                  FilterPill('В моих списках', schedFilter == 1, () => setState(() => schedFilter = 1)),
                  FilterPill('Премьеры / Финалы', schedFilter == 2, () => setState(() => schedFilter = 2)),
                ]),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final rawItems = items ?? store.liveDays[iso];
                  if (rawItems == null) {
                    return busy
                        ? const Row(children: [
                            SizedBox(
                                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.tx2)),
                            SizedBox(width: 10),
                            Text('Загружаем расписание…', style: TextStyle(color: C.tx2)),
                          ])
                        : const Text('Расписание загружается…', style: TextStyle(color: C.tx2));
                  }
                  final filteredItems = rawItems.where((it) {
                    if (schedFilter == 1) return store.listOf.containsKey(it.drama.id);
                    if (schedFilter == 2) {
                      final tot = store.totals[it.drama.id];
                      final ep = it.number ?? 1;
                      return ep == 1 || (tot != null && tot > 1 && ep == tot);
                    }
                    return true;
                  }).toList();
                  if (filteredItems.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.s1,
                        border: Border.all(color: C.line),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        schedFilter == 1
                            ? 'В этот день нет новых серий из ваших списков. Переключите фильтр на «Все серии».'
                            : (day == 0 ? 'Сегодня новых серий не запланировано.' : 'На этот день серий пока не анонсировано.'),
                        style: const TextStyle(color: C.tx2, fontSize: 13),
                      ),
                    );
                  }
                  return Column(children: [
                    for (final it in filteredItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(height: 120, child: LiveCard(it, width: double.infinity)),
                      ),
                  ]);
                }),
                const RecSections(),
                const SectionTitle('Интерактив и подбор по настроению'),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showDramaBattle(context),
                        icon: const Icon(Icons.emoji_events_rounded, size: 17, color: C.gd),
                        label: const Text('Битва дорам', style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: C.s1,
                          side: const BorderSide(color: C.line),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showKdramaBingo(context),
                        icon: const Icon(Icons.grid_on_rounded, size: 17, color: C.pk),
                        label: const Text('Дорамное Бинго', style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: C.s1,
                          side: const BorderSide(color: C.line),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => showRoulette(context),
                        icon: const Icon(Icons.casino_outlined, size: 17, color: C.jd),
                        label: const Text('Рулетка', style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: C.s1,
                          side: const BorderSide(color: C.line),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
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
                        icon: const Icon(Icons.shuffle_rounded, color: C.tx2, size: 18),
                        label: const Text('Другие варианты',
                            style: TextStyle(color: C.tx, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
                if (top.isNotEmpty) SectionTitle('Лучшие дорамы ${DateTime.now().year}'),
                if (top.isNotEmpty) PosterRail(top),
                if (soon.isNotEmpty) const SectionTitle('Скоро выходят'),
                if (soon.isNotEmpty) PosterRail(soon),
                if (fresh.isNotEmpty) const SectionTitle('Новые в базе'),
                if (fresh.isNotEmpty) PosterRail(fresh),
              ],
            ),
          ),
        );
      },
    );
  }
}

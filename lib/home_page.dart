import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'config.dart';
import 'detail_page.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'player_page.dart';
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
  int _heroIdx = 0;
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

  List<Drama> _heroCandidates(List<Drama> top) {
    final preferredKeys = [
      'doctorx',
      'whenlifegivesyoutangerines',
      'takechargeofmyheart',
      'loveindisguise',
      'canthislovebetranslated',
      'thetraumacodeheroesoncall',
      'perfectcrown',
      'lovescout',
    ];
    final out = <Drama>[];
    final seen = <int>{};
    for (final k in preferredKeys) {
      for (final d in store.allDramas) {
        if (d.en.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '') == k && seen.add(d.id)) {
          out.add(d);
          break;
        }
      }
    }
    for (final d in top) {
      if (out.length >= 8) break;
      if (seen.add(d.id)) out.add(d);
    }
    return out;
  }

  Widget _buildHeroShowcase(List<Drama> heroList) {
    if (heroList.isEmpty) return const SizedBox.shrink();
    final idx = _heroIdx.clamp(0, heroList.length - 1);
    final hd = heroList[idx];
    final title = store.ruTitle(hd);
    final tot = store.totals[hd.id] ?? (store.epCache[hd.id]?.length ?? 12);
    final aired = store.airedCount(hd);
    final watched = store.prog[hd.id] ?? 0;
    final st = store.listOf[hd.id];
    final isRunning = hd.status == 'Running';
    final maxEp = tot > 0 ? tot : 12;
    final int watchEp = (watched <= 0 || st == 'done' || watched >= maxEp)
        ? (isRunning && aired > 0 ? aired.clamp(1, maxEp) : 1)
        : (watched + 1).clamp(1, maxEp);
    final String watchLabel = (watched <= 0 && !isRunning) || st == 'done' || watched >= maxEp
        ? 'Смотреть с 1 серии'
        : 'Смотреть $watchEp серию';
    final String epTxt = isRunning
        ? '${aired > 0 ? aired : watchEp} из $maxEp серий'
        : '$maxEp серий';
    final String gTxt = hd.genres.isNotEmpty ? hd.genres.take(2).map(ruGenre).join(', ') : 'Драма, Триллер';
    final String desc = store.sumRu[hd.id] ??
        'Захватывающая южнокорейская дорама ${hd.year ?? 2026} года с яркими героями и непредсказуемым сюжетом.';

    final listLabels = <String, String>{
      'watch': 'Смотрю',
      'plan': 'В планах',
      'done': 'Просмотрено',
      'drop': 'Брошено',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: C.s1,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (hd.poster.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.28,
                    child: CachedPic(hd.poster, placeholder: const SizedBox.shrink(), fit: BoxFit.cover),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xB316111D), Color(0xF216111D), Color(0xFF16111D)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFFE59A43), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isRunning ? 'НОВАЯ СЕРИЯ СЕГОДНЯ' : 'МОЖНО СМОТРЕТЬ ЗАЛПОМ',
                          style: const TextStyle(
                            color: Color(0xFFE59A43),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ЮЖНАЯ КОРЕЯ · ${(hd.network.isEmpty ? "SBS" : hd.network).toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: C.tx2,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFE59A43), size: 17),
                        Text(
                          (hd.rating ?? 8.7).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFE59A43),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        const Text(' / ', style: TextStyle(color: C.tx2)),
                        Text('${hd.year ?? 2026}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const Text(' / ', style: TextStyle(color: C.tx2)),
                        Text(epTxt, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const Text(' / ', style: TextStyle(color: C.tx2)),
                        Text(gTxt, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const Text(' / ', style: TextStyle(color: C.tx2)),
                        const Text('15+', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.tx2, fontSize: 13.5, height: 1.38),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoPlayerPage(
                                drama: hd,
                                initialEpisode: watchEp,
                                activeDub: store.dubOf[hd.id],
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          watchLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE59A43),
                          foregroundColor: const Color(0xFF16111D),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => showListPickerSheet(context, hd),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: C.s2,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: C.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  st != null ? Icons.check_rounded : Icons.add_rounded,
                                  size: 18,
                                  color: st != null ? const Color(0xFFE59A43) : C.tx,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  st != null ? (listLabels[st] ?? 'В списке') : 'В список',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: C.tx2),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () => openDrama(context, hd),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Подробнее',
                                style: TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 17, color: C.tx),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Горизонтальная лента карточек-превью под баннером (как на скриншотах DoramaOn)
          SizedBox(
            height: 146,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
              scrollDirection: Axis.horizontal,
              itemCount: heroList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final item = heroList[i];
                final active = i == idx;
                final itemTot = store.totals[item.id] ?? 12;
                return GestureDetector(
                  onTap: () => setState(() => _heroIdx = i),
                  child: SizedBox(
                    width: 148,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active ? const Color(0xFFE59A43) : C.line,
                                width: active ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(width: double.infinity, child: Poster(item)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          store.ruTitle(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            color: active ? const Color(0xFFE59A43) : C.tx,
                          ),
                        ),
                        Text(
                          item.status == 'Running' ? 'Новые серии · в эфире' : 'Все $itemTot серий',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: C.tx2, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
        final top = store.top50();
        final heroList = _heroCandidates(top);
        final lu = store.lastUpdate;
        final status = store.refreshing
            ? 'Обновляем данные…'
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
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: C.s2,
                        child: const Icon(Icons.favorite_rounded, color: C.pk, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Text(
                          'DORAMA ',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 0.4),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE59A43),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PULSE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF16111D),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text('Корейские дорамы · $status', style: const TextStyle(color: C.tx2, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    onPressed: store.refreshing ? null : () => store.refresh(),
                    icon: store.refreshing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk))
                        : const Icon(Icons.refresh_rounded, color: C.tx2),
                    style: IconButton.styleFrom(backgroundColor: C.s1, side: const BorderSide(color: C.line)),
                  ),
                ]),
                const SizedBox(height: 12),
                _buildHeroShowcase(heroList),
                if (store.noticeVisible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SvgPicture.string(kTgSvg, width: 32, height: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              store.noticeTitle.isEmpty ? 'Вышло новое обновление 3.2' : store.noticeTitle,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.tx),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              store.noticeText,
                              maxLines: 4,
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
                                const Text(
                                  'Канал проекта · Обновить',
                                  style: TextStyle(color: C.onPk, fontWeight: FontWeight.w800, fontSize: 12.5),
                                ),
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
                          child: const Text('Подробнее', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ]),
                    ]),
                  ),
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
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                          SizedBox(width: 10),
                          Text('Загружаем расписание…', style: TextStyle(color: C.tx2)),
                        ])
                      : const Text(
                          'Расписание пока недоступно. Потяните вниз для обновления.',
                          style: TextStyle(color: C.tx2),
                        ))
                else if (items.isEmpty)
                  Text(
                    day == 0 ? 'Сегодня новых серий не нашли.' : 'На этот день серий пока не анонсировано.',
                    style: const TextStyle(color: C.tx2),
                  )
                else
                  Column(children: [
                    for (final it in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(height: 116, child: LiveCard(it, width: double.infinity)),
                      ),
                  ]),
                if (top.isNotEmpty) const SectionTitle('Топ-50 дорам'),
                if (top.isNotEmpty) PosterRail(top),
                const RecSections(),
                const SectionTitle('Что посмотреть?'),
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
                if (mood < 0 && trope < 0)
                  const Text('Выберите настроение или тему — подберём дораму.', style: TextStyle(color: C.tx2))
                else if (picks.isEmpty)
                  const Text('Пока нет подходящих дорам. Загляните позже.', style: TextStyle(color: C.tx2))
                else ...[
                  PosterRail(picks),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => shuffle++),
                      icon: const Icon(Icons.shuffle_rounded, color: C.pk),
                      label: const Text('Другие варианты', style: TextStyle(color: C.pk, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
                if (fresh.isNotEmpty) const SectionTitle('Новые находки'),
                if (fresh.isNotEmpty) PosterRail(fresh),
                if (soon.isNotEmpty) const SectionTitle('Скоро выходят и анонсы'),
                if (soon.isNotEmpty) PosterRail(soon),
              ],
            ),
          ),
        );
      },
    );
  }
}

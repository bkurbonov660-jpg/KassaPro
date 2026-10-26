import 'package:flutter/material.dart';
import 'config.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final soon = store.upcoming();
        final fresh = store.fresh();
        final top = store.topYear();
        final lu = store.lastUpdate;
        final status = store.refreshing ? 'Обновляем данные…'
          : lu == null ? 'Загрузка…' : 'Обновлено в ${two(lu.hour)}:${two(lu.minute)}';
        final iso = isoPlus(day);
        final items = store.liveDays[iso];
        final busy = store.dayBusy.contains(iso);
        final watching = store.listItems('watch').take(10).toList();
        final List<Drama> picks = mood >= 0
            ? store.pickByMood(kMoods[mood].$2, shuffle)
            : (trope >= 0 ? Taste.byTrope(kTropes[trope], seed: shuffle) : <Drama>[]);
        return SafeArea(
          child: RefreshIndicator(
            color: C.pk, backgroundColor: C.s1,
            onRefresh: () => store.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/icon/logo.png', width: 42, height: 42,
                      errorBuilder: (_, __, ___) => Container(
                        width: 42, height: 42, color: C.s2,
                        child: const Icon(Icons.favorite_rounded, color: C.pk, size: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text(Cfg.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('Корейские дорамы · $status', style: const TextStyle(color: C.tx2, fontSize: 13)),
                    Text('В базе: ${fmtNum(store.krCount)} дорам · на русском: ${fmtNum(store.krRuCount)}',
                      style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700)),
                  ])),
                  IconButton(
                    onPressed: store.refreshing ? null : () => store.refresh(),
                    icon: store.refreshing
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk))
                      : const Icon(Icons.refresh_rounded, color: C.tx2),
                    style: IconButton.styleFrom(backgroundColor: C.s1, side: const BorderSide(color: C.line)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (store.noticeVisible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.gd), borderRadius: BorderRadius.circular(18)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.campaign_rounded, color: C.gd)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.noticeTitle.isEmpty ? 'Сообщение от разработчика' : store.noticeTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: C.gd)),
                        const SizedBox(height: 4),
                        Text(store.noticeText, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ])),
                      IconButton(
                        onPressed: store.closeNotice,
                        icon: const Icon(Icons.close_rounded, color: C.tx2)),
                    ])),
                if (store.scanning)
                  Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ищем новинки: ${(store.scanProgress * 100).round()}%',
                        style: const TextStyle(color: C.tx2, fontSize: 12)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: store.scanProgress, color: C.pk, backgroundColor: C.s2, minHeight: 3),
                    ])),
                if (store.lastError.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(bottom: 6),
                    child: Text(store.lastError, style: const TextStyle(color: C.gd, fontSize: 12))),
                if (store.newFinds.isNotEmpty)
                  Container(margin: const EdgeInsets.only(top: 4, bottom: 4), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.pk), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome_rounded, color: C.pk),
                      const SizedBox(width: 12),
                      Expanded(child: Text(
                        'Новые дорамы: ${store.newFinds.take(3).map(store.ruTitle).join(", ")}'
                        '${store.newFinds.length > 3 ? " и ещё ${store.newFinds.length - 3}" : ""}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      IconButton(onPressed: () { store.newFinds.clear(); store.changed(); },
                        icon: const Icon(Icons.close_rounded, color: C.tx2)),
                    ])),
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
                const SectionTitle('Что посмотреть?'),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showRoulette(context),
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Случайная дорама'),
                    style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                ChipRow([
                  for (var i = 0; i < kMoods.length; i++)
                    FilterPill(kMoods[i].$1, mood == i, () => setState(() {
                      mood = mood == i ? -1 : i;
                      trope = -1;
                      shuffle++;
                    })),
                ]),
                const SizedBox(height: 10),
                const SizedBox(height: 8),
                ChipRow([
                  for (var i = 0; i < kTropes.length; i++)
                    FilterPill(kTropes[i].label, trope == i, () => setState(() {
                      trope = trope == i ? -1 : i;
                      mood = -1;
                      shuffle++;
                    })),
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
                if (top.isNotEmpty) SectionTitle('Лучшее ${DateTime.now().year} года'),
                if (top.isNotEmpty) PosterRail(top),
                if (soon.isEmpty && top.isEmpty && fresh.isEmpty && items != null && items.isEmpty)
                  const EmptyBox(Icons.tv_rounded, 'Каталог загружается',
                    'Потяните вниз для обновления.'),
              ],
            ),
          ),
        );
      },
    );
  }
}

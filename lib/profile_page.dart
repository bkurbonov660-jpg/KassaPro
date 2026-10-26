import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'actor_page.dart';
import 'data2026.dart';
import 'detail_page.dart';
import 'extras_ui.dart';
import 'feedback_page.dart';
import 'models.dart';
import 'native.dart';
import 'privacy_page.dart';
import 'store.dart';
import 'ui_common.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bk = TextEditingController();
  bool _showEvents = false;

  @override
  void dispose() {
    _bk.dispose();
    super.dispose();
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

Future<void> _openNotifHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          final items = store.notifHistory;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.78),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.notifications_none_rounded, color: C.pk, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'История уведомлений (${items.length})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.tx),
                        ),
                      ),
                      if (items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            store.clearNotifHistory();
                            _snack('Список уведомлений очищен');
                          },
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: C.rd),
                          label: const Text('Очистить', style: TextStyle(color: C.rd, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'Список уведомлений пуст.\nЗдесь сохраняются все уведомления об обновлениях базы, новых сериях и релизах с любимыми актёрами.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: C.tx2, fontSize: 13, height: 1.4),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final it = items[i];
                            final dt = DateTime.fromMillisecondsSinceEpoch(it.ts);
                            final dateStr = '${two(dt.day)}.${two(dt.month)}.${dt.year} · ${two(dt.hour)}:${two(dt.minute)}';
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: C.bg,
                                border: Border.all(color: C.line),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(
                                      it.kind == 'episode'
                                          ? Icons.live_tv_rounded
                                          : (it.kind == 'radar' ? Icons.person_pin_circle_rounded : Icons.system_update_alt_rounded),
                                      size: 16,
                                      color: it.kind == 'episode' ? C.jd : C.pk,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        it.title,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
                                      ),
                                    ),
                                    Text(dateStr, style: const TextStyle(color: C.tx2, fontSize: 11)),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => store.removeNotifLog(it.id),
                                      child: const Icon(Icons.close_rounded, size: 16, color: C.tx2),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(
                                    it.body,
                                    style: const TextStyle(color: C.tx2, fontSize: 12.5, height: 1.38),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveFile() async {
    final ok = await Native.saveFile('dorama_pulse_backup.json', store.backup());
    if (!mounted) return;
    _snack(ok ? 'Бэкап сохранён в файл' : 'Бэкап не сохранён');
  }

  Future<void> _loadFile() async {
    final txt = await Native.pickFile();
    if (!mounted) return;
    if (txt == null || txt.trim().isEmpty) { _snack('Файл не выбран'); return; }
    final n = store.backupCount(txt);
    if (n < 0) { _snack('Это не файл бэкапа Дорама Пульс'); return; }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.s1,
        title: const Text('Восстановить из файла?'),
        content: Text('В файле дорам в списках: $n. Текущие списки, серии, оценки, озвучки и заметки будут заменены данными из файла.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk),
            child: const Text('Восстановить')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = store.restore(txt);
    _snack(ok ? 'Данные восстановлены' : 'Не удалось прочитать файл');
  }

  Future<void> _showAddActorDialog() async {
    final ctl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final q = ctl.text.trim().toLowerCase().replaceAll('ё', 'е');
        final allCandidates = <Actor>[...kPopularCrushes];
        final seenNames = allCandidates.map((a) => a.name.toLowerCase()).toSet();
        store.actorRu.forEach((en, ru) {
          if (seenNames.add(en.toLowerCase())) {
            allCandidates.add(Actor(-500, en, ru, ''));
          }
        });
        final filtered = allCandidates.where((a) {
          if (q.isEmpty) return true;
          final ru = store.ruActor(a.name).toLowerCase().replaceAll('ё', 'е');
          return ru.contains(q) || a.name.toLowerCase().contains(q) || a.role.toLowerCase().replaceAll('ё', 'е').contains(q);
        }).take(30).toList();

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Добавить любимого актёра', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Приложение уведомит вас, когда с выбранным актёром или актрисой выйдет новая дорама.',
                  style: TextStyle(color: C.tx2, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: ctl,
                      onChanged: (_) => setS(() {}),
                      style: const TextStyle(color: C.tx, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Имя на русском или английском…',
                        hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.tx2, size: 20),
                        filled: true,
                        fillColor: C.s2,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  if (ctl.text.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        store.toggleFavActor(ctl.text.trim());
                        ctl.clear();
                        setS(() {});
                      },
                      style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk),
                      child: const Text('Добавить'),
                    ),
                  ],
                ]),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final a = filtered[i];
                      final fav = store.isFavActor(a.name);
                      final dramasCnt = store.dramasForActorKey(a.name).length;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: a.photo.isNotEmpty
                                ? CachedPic(a.photo, placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 20)))
                                : Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2, size: 20)),
                          ),
                        ),
                        title: Text(store.ruActor(a.name), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(
                          '${a.name}${dramasCnt > 0 ? " · дорам: $dramasCnt" : ""}',
                          style: const TextStyle(color: C.tx2, fontSize: 12),
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            store.toggleFavActor(a.name);
                            setS(() {});
                          },
                          icon: Icon(
                            fav ? Icons.favorite_rounded : Icons.add_circle_outline_rounded,
                            color: fav ? C.pk : C.tx2,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: a)));
                        },
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _stat(String v, String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.tx2, fontSize: 12)),
    ]));

  Widget _btn(String t, IconData i, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: f, icon: Icon(i, color: C.pk, size: 18),
      label: Text(t, style: const TextStyle(color: C.tx)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))));

  Widget _kvRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Text(label, style: const TextStyle(color: C.tx2, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  String _plural(int n, String one, String few, String many) {
    final m100 = n.abs() % 100;
    final m10 = n.abs() % 10;
    if (m100 >= 11 && m100 <= 19) return many;
    if (m10 == 1) return one;
    if (m10 >= 2 && m10 <= 4) return few;
    return many;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rated = store.rate.values.toList();
        final avg = rated.isEmpty ? '—' : (rated.reduce((a, b) => a + b) / rated.length).toStringAsFixed(1);
        final genres = store.topGenres();
        final (days, remHours, totalHours, totalEps) = store.watchedTimeStats();
        final rep = store.report2026();
        final radarList = store.radarEvents();
        final totalDramas = store.listOf.length;
        final timeStr = days > 0
            ? '$days ${_plural(days, "день", "дня", "дней")} $remHours ${_plural(remHours, "час", "часа", "часов")}'
            : '$totalHours ${_plural(totalHours, "час", "часа", "часов")}';

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Профиль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),

              // 1. Скрываемая / раскрываемая секция общей статистики и времени просмотра
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: store.toggleShowStats,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, color: C.pk, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text(
                          'Просмотр дорам и время',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.tx),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalDramas в списках · $totalEps серий · $timeStr',
                          style: const TextStyle(color: C.tx2, fontSize: 12),
                        ),
                      ]),
                    ),
                    Text(
                      store.showStats ? 'Скрыть' : 'Показать',
                      style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      store.showStats ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: C.tx2,
                      size: 20,
                    ),
                  ]),
                ),
              ),

              if (store.showStats) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      const Expanded(
                        child: Text('Общее время просмотра', style: TextStyle(color: C.tx2, fontSize: 13)),
                      ),
                      Text(timeStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.tx)),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Всего: $totalHours ч · отмечено серий: $totalEps (по ≈65 мин)',
                      style: const TextStyle(color: C.tx2, fontSize: 12),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: C.line, height: 1),
                    ),
                    const Text('Сводка за 2026 год', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx)),
                    _kvRow('Дорам в коллекции', '${rep['dramas']}'),
                    _kvRow('Средняя оценка', avg),
                    _kvRow('Частый жанр', '${rep['topGenre']}'),
                    if (rep['topDub'] != '—') _kvRow('Выбранная озвучка', '${rep['topDub']}'),
                    if (store.favActors.isNotEmpty)
                      _kvRow('Любимые актёры', store.favActors.map(store.ruActor).join(', ')),
                  ]),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.05,
                  children: [
                    _stat('${store.listItems('watch').length}', 'Смотрю'),
                    _stat('${store.listItems('plan').length}', 'В планах'),
                    _stat('${store.listItems('done').length}', 'Просмотрено'),
                    _stat('${store.listItems('drop').length}', 'Брошено'),
                    _stat('${store.rate.length}', 'Оценено'),
                    _stat(avg, 'Средняя оценка'),
                    _stat('$totalEps', 'Серий отмечено'),
                    _stat('${store.dubOf.length}', 'С выбранной озвучкой'),
                  ],
                ),
              ],

              // 2. Любимые актёры (только те, кого пользователь сам добавил)
              Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 10),
                child: Row(children: [
                  const Expanded(
                    child: Text('Любимые актёры', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.tx)),
                  ),
                  TextButton.icon(
                    onPressed: _showAddActorDialog,
                    icon: const Icon(Icons.add_rounded, size: 18, color: C.pk),
                    label: const Text('Добавить', style: TextStyle(color: C.pk, fontWeight: FontWeight.w700, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ]),
              ),
              if (store.favActors.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: C.s1,
                    border: Border.all(color: C.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Список пуст. Добавьте любимых актёров или актрис, чтобы получать уведомления о выходе новых дорам с их участием.',
                    style: TextStyle(color: C.tx2, fontSize: 13, height: 1.35),
                  ),
                )
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final fav in store.favActors)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ActorPage(actor: Actor(-400, fav, '', ''))),
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: C.s1,
                          border: Border.all(color: C.line),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.person_outline_rounded, size: 15, color: C.pk),
                          const SizedBox(width: 6),
                          Text(store.ruActor(fav), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: C.tx)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => store.toggleFavActor(fav),
                            child: const Icon(Icons.close_rounded, size: 16, color: C.tx2),
                          ),
                        ]),
                      ),
                    ),
                ]),

              // 3. Уведомления
              const SectionTitle('Уведомления'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.pk,
                    title: const Text('Новые серии («Смотрю»)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Оповещать в день выхода новой серии', style: TextStyle(color: C.tx2, fontSize: 12)),
                    value: store.notifEps,
                    onChanged: (v) => store.setNotifEps(v),
                  ),
                  const Divider(color: C.line, height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.pk,
                    title: const Text('Дорамы с любимыми актёрами', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Оповещать о премьерах и новых сериях с выбранными актёрами',
                        style: TextStyle(color: C.tx2, fontSize: 12)),
                    value: store.notifRadar,
                    onChanged: (v) => store.setNotifRadar(v),
                  ),
                  const Divider(color: C.line, height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.pk,
                    title: const Text('Обновления базы и новинки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text('Присылать уведомление в телефон при обновлении базы данных и добавлении дорам',
                        style: TextStyle(color: C.tx2, fontSize: 12)),
                    value: store.notifUpdates,
                    onChanged: (v) => store.setNotifUpdates(v),
                  ),
                  const Divider(color: C.line, height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: _openNotifHistorySheet,
                    leading: const Icon(Icons.history_rounded, color: C.pk, size: 20),
                    title: Text(
                      'Список уведомлений (${store.notifHistory.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: C.tx),
                    ),
                    subtitle: Text(
                      store.notifHistory.isEmpty
                          ? 'Нажмите, чтобы посмотреть историю уведомлений'
                          : store.notifHistory.first.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.tx2, fontSize: 12),
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (store.notifHistory.isNotEmpty)
                        IconButton(
                          tooltip: 'Очистить уведомления',
                          onPressed: () {
                            store.clearNotifHistory();
                            _snack('Список уведомлений очищен');
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: C.tx2, size: 19),
                        ),
                      const Icon(Icons.chevron_right_rounded, color: C.tx2, size: 20),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(spacing: 8, runSpacing: 4, children: [
                      TextButton.icon(
                        onPressed: () {
                          store.pushUpdateNotification(
                            'test:${DateTime.now().millisecondsSinceEpoch}',
                            store.noticeTitle.isNotEmpty ? store.noticeTitle : 'Обновление базы Дорама Пульс',
                            store.noticeText.isNotEmpty
                                ? store.noticeText.replaceAll('\n', ' ').replaceAll('• ', '')
                                : 'База данных 2026 обновлена: добавлены все новинки, актёры, премии и оффлайн-кэш.',
                            force: true,
                          );
                          _snack('Уведомление отправлено и сохранено в списке');
                        },
                        icon: const Icon(Icons.notifications_active_outlined, size: 16, color: C.pk),
                        label: const Text('Проверить уведомление',
                            style: TextStyle(color: C.pk, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                    ]),
                  ),
                  if (radarList.isNotEmpty) ...[
                    const Divider(color: C.line, height: 1),
                    InkWell(
                      onTap: () => setState(() => _showEvents = !_showEvents),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              'Ближайшие релизы и серии (${radarList.length})',
                              style: const TextStyle(color: C.tx2, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _showEvents ? 'Скрыть' : 'Показать',
                            style: const TextStyle(color: C.tx2, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showEvents ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: C.tx2,
                            size: 18,
                          ),
                        ]),
                      ),
                    ),
                    if (_showEvents)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(children: [
                          for (final ev in radarList.take(12))
                            InkWell(
                              onTap: () => openDrama(context, ev.drama),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: C.s2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: C.line),
                                ),
                                child: Row(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(width: 36, height: 52, child: Poster(ev.drama)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(ev.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Text(ev.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: C.tx2, fontSize: 12)),
                                    ]),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: C.tx2, size: 18),
                                ]),
                              ),
                            ),
                        ]),
                      ),
                  ],
                ]),
              ),


              // 3b. Виджеты для рабочего стола (Android AppWidget)
              const SectionTitle('Виджеты для рабочего стола'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: C.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'Добавьте минималистичные виджеты на главный экран телефона: таймер до следующей серии из «Смотрю», расписание эфира на сегодня или сводку времени и радар актёров.',
                    style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.38),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.syncWidgetsNow();
                          final ok = await Native.pinWidget('countdown');
                          if (!ok) _snack('Зажмите пустое место на рабочем столе → Виджеты → Дорама Пульс');
                        },
                        icon: const Icon(Icons.timer_outlined, size: 17, color: C.pk),
                        label: const Text('Таймер «Смотрю»', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.syncWidgetsNow();
                          final ok = await Native.pinWidget('schedule');
                          if (!ok) _snack('Зажмите пустое место на рабочем столе → Виджеты → Дорама Пульс');
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16, color: C.jd),
                        label: const Text('Эфир сегодня', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.syncWidgetsNow();
                          final ok = await Native.pinWidget('stats');
                          if (!ok) _snack('Зажмите пустое место на рабочем столе → Виджеты → Дорама Пульс');
                        },
                        icon: const Icon(Icons.insights_rounded, size: 17, color: C.gd),
                        label: const Text('Сводка и Радар', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await store.syncWidgetsNow();
                          _snack('Данные на всех виджетах рабочего стола обновлены');
                        },
                        icon: const Icon(Icons.sync_rounded, size: 17, color: C.tx2),
                        label: const Text('Обновить виджеты', style: TextStyle(color: C.tx2, fontWeight: FontWeight.w700, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: C.line),
                          backgroundColor: C.bg,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),

              const SectionTitle('Любимые жанры'),
              if (genres.isEmpty)
                const Text('Добавьте дорамы в списки и ставьте оценки — здесь появятся ваши жанры.',
                    style: TextStyle(color: C.tx2))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in genres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(100)),
                      child: Text('${ruGenre(g.key)} · ${g.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                ]),
              const SectionTitle('Резервная копия'),
              _btn('Сохранить бэкап в файл', Icons.save_alt_rounded, _saveFile),
              _btn('Восстановить из файла', Icons.folder_open_rounded, _loadFile),
              const SizedBox(height: 2),
              const Text('Или через буфер обмена', style: TextStyle(color: C.tx2, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _btn('Скопировать', Icons.copy_rounded, () async {
                  await Clipboard.setData(ClipboardData(text: store.backup()));
                  _snack('Копия в буфере обмена');
                })),
                const SizedBox(width: 10),
                Expanded(child: _btn('Восстановить', Icons.restore_rounded, () {
                  final ok = store.restore(_bk.text);
                  _snack(ok ? 'Восстановлено' : 'Не удалось прочитать копию');
                })),
              ]),
              TextField(
                controller: _bk, maxLines: 4,
                style: const TextStyle(color: C.tx, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Вставьте сюда копию для восстановления',
                  hintStyle: const TextStyle(color: C.tx2),
                  filled: true, fillColor: C.s1,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)))),
              const SizedBox(height: 24),
              const TgCard(),
              const SizedBox(height: 10),
              _btn('Идеи и ошибки: написать разработчику', Icons.forum_rounded,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackPage()))),
              _btn('Политика конфиденциальности', Icons.privacy_tip_rounded,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPage()))),
            ],
          ),
        );
      },
    );
  }
}

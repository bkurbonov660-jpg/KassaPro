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
  @override
  void dispose() { _bk.dispose(); super.dispose(); }
  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
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
        content: Text('В файле дорам в списках: $n. Текущие списки, серии, оценки, озвучки, любимые актёры и заметки будут заменены данными из файла.'),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Радар любимых актёров ❤️', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text(
                  'Выберите своих крашей (например, Сон Кан, Ча Ын У, Го Юн Чжон) — приложение пришлёт уведомление при анонсе нового проекта или выходе серии с ними.',
                  style: TextStyle(color: C.tx2, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: ctl,
                      onChanged: (_) => setS(() {}),
                      style: const TextStyle(color: C.tx),
                      decoration: InputDecoration(
                        hintText: 'Имя актёра или актрисы (Сон Кан, Song Kang…)',
                        hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.pk),
                        filled: true,
                        fillColor: C.s2,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                        leading: CircleAvatar(
                          backgroundColor: C.s2,
                          backgroundImage: a.photo.isNotEmpty ? NetworkImage(a.photo) : null,
                          child: a.photo.isEmpty ? const Icon(Icons.person_rounded, color: C.pk) : null,
                        ),
                        title: Text(store.ruActor(a.name), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${a.name}${dramasCnt > 0 ? " · дорам в базе: $dramasCnt" : ""}',
                          style: const TextStyle(color: C.tx2, fontSize: 12),
                        ),
                        trailing: IconButton(
                          onPressed: () {
                            store.toggleFavActor(a.name);
                            setS(() {});
                          },
                          icon: Icon(
                            fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(t, style: const TextStyle(color: C.tx2, fontSize: 12)),
    ]));

  Widget _btn(String t, IconData i, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: f, icon: Icon(i, color: C.pk),
      label: Text(t, style: const TextStyle(color: C.tx)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))));

  Widget _timeInfographicCard(int days, int remHours, int totalHours, int totalEps) {
    final rank = totalHours >= 500
        ? 'Легенда дорамного мира 👑'
        : (totalHours >= 200
            ? 'Мастер корейских дорам 🔥'
            : (totalHours >= 60 ? 'Опытный дорамщик ✨' : 'Начинающий зритель 🌸'));
    final progress = (totalHours / 500.0).clamp(0.05, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B1C3D), Color(0xFF1F1829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: C.pk),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0x33FF7A9C), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.auto_graph_rounded, color: C.pk, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Общее время за дорамами', style: TextStyle(color: C.tx2, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(rank, style: const TextStyle(color: C.gd, fontSize: 13.5, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(
          'Вы посмотрели дорам на $days ${_plural(days, "день", "дня", "дней")} и $remHours ${_plural(remHours, "час", "часа", "часов")}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.tx, height: 1.2),
        ),
        const SizedBox(height: 6),
        Text(
          'Всего: $totalHours ч ($totalEps серий по ≈65 мин)',
          style: const TextStyle(color: C.jd, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: C.pk,
            backgroundColor: C.s2,
          ),
        ),
      ]),
    );
  }

  Widget _annualReport2026Card(Map<String, dynamic> rep) {
    final dramas = rep['dramas'] as int;
    final eps = rep['episodes'] as int;
    final days = rep['days'] as int;
    final remHours = rep['remHours'] as int;
    final avgRate = rep['avgRate'] as double;
    final topGenre = rep['topGenre'] as String;
    final topActor = rep['topActor'] as String;
    final topDub = rep['topDub'] as String;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D2C3A), Color(0xFF1F1829)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: C.jd),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.celebration_rounded, color: C.gd, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ваш 2026 год в дорамах',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.tx),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Персональная инфографика вашей активности и предпочтений:',
          style: TextStyle(color: C.tx2, fontSize: 12.5),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.s1, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$dramas', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.pk)),
                const Text('Дорам в коллекции', style: TextStyle(fontSize: 11.5, color: C.tx2)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.s1, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$eps', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.jd)),
                const Text('Серий просмотрено', style: TextStyle(fontSize: 11.5, color: C.tx2)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.s1, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(avgRate > 0 ? avgRate.toStringAsFixed(1) : '—',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.gd)),
                const Text('Средний балл ★', style: TextStyle(fontSize: 11.5, color: C.tx2)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _reportRow(Icons.timer_rounded, 'Время в 2026 году', '$days дн. $remHours ч.'),
        _reportRow(Icons.auto_awesome_rounded, 'Любимый жанр', topGenre),
        _reportRow(Icons.person_pin_rounded, 'Фаворит на экране', topActor),
        _reportRow(Icons.mic_rounded, 'Любимая озвучка', topDub),
      ]),
    );
  }

  Widget _reportRow(IconData ic, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(children: [
        Icon(ic, size: 16, color: C.jd),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: C.tx2, fontSize: 13)),
        Expanded(
          child: Text(val, textAlign: TextAlign.right,
              style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 13)),
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
        final autoActors = store.autoFavoriteActors();
        final rep2026 = store.report2026();
        final radarList = store.radarEvents();

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Профиль и Статистика', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              // 1. Инфографика потраченного времени
              _timeInfographicCard(days, remHours, totalHours, totalEps),
              // 2. Годовой отчёт 2026
              _annualReport2026Card(rep2026),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 1.85,
                children: [
                  _stat('${store.rate.length}', 'Оценено'),
                  _stat(avg, 'Средняя оценка'),
                  _stat('${store.listItems('watch').length}', 'Смотрю'),
                  _stat('${store.listItems('plan').length}', 'В планах'),
                  _stat('${store.listItems('done').length}', 'Просмотрено'),
                  _stat('${store.listItems('drop').length}', 'Брошено'),
                  _stat('${store.dubOf.length}', 'Выбрана озвучка'),
                  _stat('$totalEps', 'Серий отмечено'),
                ]),

              // 3. Автоматический любимый актёр/актриса по частоте просмотров
              const SectionTitle('Любимый актёр / актриса (по вашим просмотрам)'),
              if (autoActors.isEmpty)
                const Text(
                  'Добавляйте дорамы в «Смотрю» или «Просмотрено» — мы автоматически посчитаем, с кем вы смотрите сериалы чаще всего.',
                  style: TextStyle(color: C.tx2, fontSize: 13),
                )
              else
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: autoActors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final it = autoActors[i];
                      final act = Actor(-300 - i, it.$1, '', it.$4);
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: act))),
                        child: Container(
                          width: 210,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: C.s1,
                            border: Border.all(color: i == 0 ? C.gd : C.line),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: C.s2,
                              backgroundImage: it.$4.isNotEmpty ? NetworkImage(it.$4) : null,
                              child: it.$4.isEmpty ? const Icon(Icons.person_rounded, color: C.pk) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                if (i == 0)
                                  const Text('🏆 №1 по просмотрам', style: TextStyle(color: C.gd, fontSize: 10.5, fontWeight: FontWeight.w800)),
                                Text(store.ruActor(it.$1), maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text(
                                  'Дорам у вас: ${it.$2}${it.$3 > 0 ? " · ★ ${it.$3.toStringAsFixed(1)}" : ""}',
                                  style: const TextStyle(color: C.jd, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                              ]),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),

              // 4. Любимые актёры («Краши») и Радар любимых актёров
              const SectionTitle('Радар любимых актёров («Мои краши» ❤️)'),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.radar_rounded, color: C.pk),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Выбирайте любимых актёров и актрис — мы покажем их здесь и пришлём уведомление при анонсе новой дорамы или выходе серии!',
                        style: TextStyle(color: C.tx2, fontSize: 12.5, height: 1.35),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (store.favActors.isNotEmpty) ...[
                    const Text('Ваши выбранные актёры и актрисы:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final fav in store.favActors)
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ActorPage(actor: Actor(-400, fav, '', ''))),
                          ),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                            decoration: BoxDecoration(
                              color: const Color(0x26FF7A9C),
                              border: Border.all(color: C.pk),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.favorite_rounded, size: 15, color: C.pk),
                              const SizedBox(width: 6),
                              Text(store.ruActor(fav), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: C.tx)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => store.toggleFavActor(fav),
                                child: const Icon(Icons.close_rounded, size: 16, color: C.tx2),
                              ),
                            ]),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                  ],
                  const Text('Быстрое добавление популярных крашей:', style: TextStyle(color: C.tx2, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in kPopularCrushes.take(12))
                       Builder(builder: (_) {
                        final on = store.isFavActor(c.name);
                        return GestureDetector(
                          onTap: () => store.toggleFavActor(c.name),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: on ? C.pk : C.s2,
                              border: Border.all(color: on ? C.pk : C.line),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${on ? "❤️ " : "+ "}${store.ruActor(c.name)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: on ? C.onPk : C.tx,
                              ),
                            ),
                          ),
                        );
                      }),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showAddActorDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: C.pk),
                      label: const Text('Найти и добавить любого актёра / актрису', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.pk),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ]),
              ),

              // 5. Раздел «Уведомления» в профиле
              const SectionTitle('Уведомления и Радар', live: true),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.pk,
                    title: const Text('Радар любимых актёров ❤️', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('Уведомлять, когда анонсируют проект или выходит серия с выбранными крашами',
                        style: TextStyle(color: C.tx2, fontSize: 12)),
                    value: store.notifRadar,
                    onChanged: (v) => store.setNotifRadar(v),
                  ),
                  const Divider(color: C.line, height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: C.jd,
                    title: const Text('Новые серии из списка «Смотрю» 🎬', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: const Text('Локальные push-уведомления Android в день выхода новой серии',
                        style: TextStyle(color: C.tx2, fontSize: 12)),
                    value: store.notifEps,
                    onChanged: (v) => store.setNotifEps(v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Native.notifPermission();
                        await store.rebuildNotifications();
                        _snack('Разрешение проверено · Уведомления обновлены (${store.plan.length})');
                      },
                      icon: const Icon(Icons.notifications_active_rounded, color: C.jd, size: 18),
                      label: Text('Обновить расписание уведомлений (активно: ${store.plan.length})',
                          style: const TextStyle(color: C.tx, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: C.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Лента уведомлений и событий Радара:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  const SizedBox(height: 8),
                  if (radarList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Пока нет активных событий. Добавьте любимых актёров в Радар выше или добавьте онгоинги в список «Смотрю»!',
                        style: TextStyle(color: C.tx2, fontSize: 12.5),
                      ),
                    )
                  else
                    for (final ev in radarList.take(15))
                      InkWell(
                        onTap: () => openDrama(context, ev.drama),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: C.s2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ev.kind == 'ep' ? C.pk : (ev.kind == 'watch_ep' ? C.jd : C.line)),
                          ),
                          child: Row(children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(width: 42, height: 60, child: Poster(ev.drama)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(ev.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(ev.subtitle, style: const TextStyle(color: C.tx2, fontSize: 12)),
                                const SizedBox(height: 4),
                                EpisodeCountdownBadge(ev.drama, compact: true),
                              ]),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: C.tx2),
                          ]),
                        ),
                      ),
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

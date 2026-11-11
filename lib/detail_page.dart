import 'package:flutter/material.dart';
import 'actor_page.dart';
import 'data2026.dart';
import 'dict.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'native.dart';
import 'store.dart';
import 'taste.dart';
import 'tvmaze.dart';
import 'ui_common.dart';
import 'widgets.dart';

void openDrama(BuildContext c, Drama d) {
  Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetailPage(drama: d)));
}

// ── Минималистичное классическое окно выбора площадки для просмотра ──
Future<void> showWatchOptionsSheet(BuildContext context, Drama d, {int? epNum}) async {
  var currentEp = epNum ?? ((store.prog[d.id] ?? 0) + 1);
  final maxEp = store.totals[d.id] ?? 16;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.s1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: C.line, width: 0.8),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final title = store.ruTitle(d);
        final activeDub = store.dubOf[d.id];
        final dubLabel = (activeDub != null && activeDub.isNotEmpty) ? activeDub : 'SoftBox';
        final dubQuery = ' $dubLabel';

        final qVk = Uri.encodeComponent('$title дорама$dubQuery $currentEp серия');
        final qYandex = Uri.encodeComponent('$title дорама$dubQuery $currentEp серия смотреть онлайн');
        final qDoramyClub = Uri.encodeComponent(title);
        final qGoogle = Uri.encodeComponent('$title дорама $currentEp серия смотреть онлайн$dubQuery');
        final qOk = Uri.encodeComponent('$title дорама$dubQuery $currentEp серия');
        final qRutube = Uri.encodeComponent('$title дорама$dubQuery $currentEp серия');
        final qKp = Uri.encodeComponent(title);
        final qIvi = Uri.encodeComponent(title);

        final platforms = <(String, String, IconData, String)>[
          ('VK Видео', 'm.vk.com · $dubLabel', Icons.play_circle_outline_rounded, 'https://m.vk.com/video?q=$qVk'),
          ('Яндекс Видео · Kodik', 'Плееры без VPN', Icons.ondemand_video_rounded, 'https://yandex.ru/video/touch/search?text=$qYandex'),
          ('Doramy.club', 'doramy.club', Icons.language_rounded, 'https://doramy.club/?s=$qDoramyClub'),
          ('Dorama.land · Google', 'Все сайты онлайн', Icons.search_rounded, 'https://www.google.com/search?q=$qGoogle'),
          ('OK Видео', 'm.ok.ru · $dubLabel', Icons.slideshow_rounded, 'https://m.ok.ru/video/search?st.query=$qOk'),
          ('Rutube', 'rutube.ru · HD', Icons.smart_display_outlined, 'https://rutube.ru/search/?query=$qRutube'),
          ('Кинопоиск', 'kinopoisk.ru', Icons.movie_outlined, 'https://www.kinopoisk.ru/index.php?kp_query=$qKp'),
          ('Иви', 'ivi.ru', Icons.tv_rounded, 'https://www.ivi.ru/search/?q=$qIvi'),
        ];

        Future<void> launchSite(String url, String name) async {
          if (store.listOf[d.id] == null) store.setList(d, 'watch');
          if ((store.prog[d.id] ?? 0) < currentEp) store.setProg(d, currentEp);
          Navigator.of(ctx).pop();
          final ok = await Native.openUrl(url);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось открыть $name')),
            );
          }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 3.5,
                    decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 12),
                // Минималистичная шапка: название + переключатель серии
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: C.tx),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Выберите площадку · Озвучка $dubLabel',
                            style: const TextStyle(fontSize: 12, color: C.tx2),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: C.bg,
                        border: Border.all(color: C.line),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: currentEp > 1 ? () => setS(() => currentEp--) : null,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(Icons.remove_rounded, size: 16, color: C.tx2),
                            ),
                          ),
                          Text(
                            'С.$currentEp',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: C.tx),
                          ),
                          InkWell(
                            onTap: currentEp < (maxEp > 0 ? maxEp : 99) ? () => setS(() => currentEp++) : null,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Icon(Icons.add_rounded, size: 16, color: C.tx2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Лаконичный выбор студии озвучки
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final stStudio in const ['SoftBox', 'DubLik TV', 'FSG Мания', 'STEPonee', 'АниМаунт', 'Субтитры'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              store.setDub(d, stStudio);
                              setS(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                              decoration: BoxDecoration(
                                color: dubLabel == stStudio ? C.tx : C.bg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: dubLabel == stStudio ? C.tx : C.line),
                              ),
                              child: Text(
                                stStudio,
                                style: TextStyle(
                                  color: dubLabel == stStudio ? C.bg : C.tx2,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Чистый минималистичный список площадок в единой рамке
                Container(
                  decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.line),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < platforms.length; i++) ...[
                        if (i > 0) const Divider(color: C.line, height: 1, thickness: 0.7),
                        InkWell(
                          borderRadius: BorderRadius.vertical(
                            top: i == 0 ? const Radius.circular(14) : Radius.zero,
                            bottom: i == platforms.length - 1 ? const Radius.circular(14) : Radius.zero,
                          ),
                          onTap: () => launchSite(platforms[i].$4, platforms[i].$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(
                              children: [
                                Icon(platforms[i].$3, size: 18, color: i == 0 ? C.tx : C.tx2),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    platforms[i].$1,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: C.tx),
                                  ),
                                ),
                                Text(
                                  platforms[i].$2,
                                  style: const TextStyle(color: C.tx2, fontSize: 11.5),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.north_east_rounded, size: 15, color: C.tx2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Минималистичная нижняя панель: просто отметить серию или скрыть кнопку
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        if (store.listOf[d.id] == null) store.setList(d, 'watch');
                        store.setProg(d, currentEp);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Отмечена Серия $currentEp')),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 16, color: C.jd),
                      label: Text(
                        'Только отметить С.$currentEp',
                        style: const TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        store.setShowWatchBtn(false);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Кнопка «Смотреть» скрыта (вернуть можно в Профиле)')),
                        );
                      },
                      child: const Text(
                        'Скрыть кнопку',
                        style: TextStyle(color: C.tx2, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class DetailPage extends StatefulWidget {
  final Drama drama;
  const DetailPage({super.key, required this.drama});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<Ep>? eps;
  List<Actor>? cast;
  bool loaded = false;
  bool sumBusy = false;
  bool allEps = false;
  int _activeTab = 0; // 0: СЕРИИ, 1: АКТЁРЫ, 2: ПОХОЖИЕ, 3: ОЗВУЧКА И ОЦЕНКА
  late final TextEditingController nameCtl;
  late final TextEditingController noteCtl;
  late final TextEditingController dubCtl;
  late final List<Drama> sim;
  Drama get d => widget.drama;

  @override
  void initState() {
    super.initState();
    nameCtl = TextEditingController(text: store.custom[d.id] ?? '');
    noteCtl = TextEditingController(text: store.notes[d.id] ?? '');
    dubCtl = TextEditingController(text: store.dubOf[d.id] ?? '');
    sim = store.similar(d);
    eps = store.epCache[d.id];
    _load();
  }

  @override
  void dispose() {
    nameCtl.dispose();
    noteCtl.dispose();
    dubCtl.dispose();
    super.dispose();
  }

  Future<void> _openExternal(String url, String label) async {
    final ok = await Native.openUrl(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть $label')),
      );
    }
  }

  Future<void> _enrichLocalCast(List<Actor> base) async {
    if (base.isEmpty) return;
    final updated = List<Actor>.from(base);
    var changedAny = false;
    for (var i = 0; i < updated.length; i++) {
      final a = updated[i];
      final presetPh = store.actorPhotoOf(a.name, a.photo);
      if (presetPh.isNotEmpty) {
        if (a.photo != presetPh) {
          updated[i] = Actor(a.id, a.name, a.role, presetPh);
          changedAny = true;
        }
        continue;
      }
      final (pid, ph) = await Tvmaze.findPerson(a.name);
      final bestPh = presetPh.isNotEmpty ? presetPh : ph;
      if ((pid != null && pid > 0) || bestPh.isNotEmpty) {
        updated[i] = Actor(
          pid ?? a.id,
          a.name,
          a.role,
          bestPh,
        );
        changedAny = true;
        if (mounted) setState(() => cast = List<Actor>.from(updated));
      }
    }
    if (changedAny && mounted) setState(() => cast = updated);
  }

  Future<void> _load() async {
    store.translator.ensureOne(d);
    final cf = store.castOf(d);
    if (cf.isNotEmpty) store.ensureActorNames(cf);
    final localCast = store.richCastOf(d);
    if (localCast.isNotEmpty) {
      cast = localCast;
      store.ensureActorNames(localCast.map((a) => a.name).toList());
    }
    if (d.id < 0) {
      if (mounted) setState(() => loaded = true);
      if (localCast.isNotEmpty) _enrichLocalCast(localCast);
      return;
    }
    store.ensureEpisodes(d, force: true).then((l) {
      if (mounted && l != null && l.isNotEmpty) setState(() => eps = l);
    });
    Tvmaze.cast(d.id).then((l) {
      final hasCurated = store.hasCuratedCast(d);
      if (hasCurated && localCast.isNotEmpty) {
        final merged = List<Actor>.from(localCast);
        final seenKeys = merged.map((a) => ak(a.name)).toSet();
        for (final tvA in l) {
          if (seenKeys.add(ak(tvA.name))) {
            final rl = tvA.role.isNotEmpty ? tvA.role : store.roleInDrama(tvA.name, d);
            merged.add(Actor(tvA.id, tvA.name, rl, store.actorPhotoOf(tvA.name, tvA.photo)));
          }
        }
        if (mounted) setState(() => cast = merged);
        store.ensureActorNames(merged.map((a) => a.name).toList());
        _enrichLocalCast(merged);
      } else if (l.isNotEmpty) {
        // Объединяем каст TVmaze с локальными ролями, чтобы ни у кого не пропала роль
        final localRoleByKey = <String, String>{
          for (final la in localCast)
            if (la.role.isNotEmpty) ak(la.name): la.role,
        };
        final enriched = <Actor>[];
        final seenKeys = <String>{};
        for (var i = 0; i < l.length; i++) {
          final tvA = l[i];
          final k = ak(tvA.name);
          seenKeys.add(k);
          final bestRole = localRoleByKey[k] ??
              (tvA.role.isNotEmpty ? tvA.role : (i < 2 ? 'Главная роль' : 'Второстепенная роль'));
          enriched.add(Actor(
            (k == 'kimjunghyun' || k == 'yeonwoo') ? -300 : tvA.id,
            tvA.name,
            bestRole,
            store.actorPhotoOf(tvA.name, '').isNotEmpty ? store.actorPhotoOf(tvA.name, '') : tvA.photo,
          ));
        }
        for (final la in localCast) {
          if (seenKeys.add(ak(la.name))) enriched.add(la);
        }
        if (mounted) setState(() => cast = enriched);
        store.ensureActorNames(enriched.map((a) => a.name).toList());
        _enrichLocalCast(enriched);
      } else if (localCast.isNotEmpty) {
        _enrichLocalCast(localCast);
      }
    });
    final info = await Tvmaze.detail(d.id);
    if (!mounted) return;
    setState(() => loaded = true);
    final raw = info == null ? '' : Tvmaze.stripHtml((info['summary'] ?? '').toString());
    if (raw.isNotEmpty && !store.sumRu.containsKey(d.id)) {
      setState(() => sumBusy = true);
      final r = await store.translator.summary(raw);
      if (r != null) store.setSummary(d, r.text, r.src);
      if (mounted) setState(() => sumBusy = false);
    }
  }

  int get total {
    final t = store.totals[d.id];
    if (t != null && t > 0 && t <= 200) return t;
    if (eps != null && eps!.isNotEmpty) return eps!.length;
    return 12;
  }

  void _showStatusPickerSheet(BuildContext context, String? curSt) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
              const SizedBox(height: 14),
              Text('Мой список · ${store.ruTitle(d)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.tx)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _listBtn('Смотрю', Icons.play_circle_fill_rounded, curSt == 'watch', 'watch', ctx)),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('В планах', Icons.bookmark_rounded, curSt == 'plan', 'plan', ctx)),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('Просмотрено', Icons.check_circle_rounded, curSt == 'done', 'done', ctx)),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('Брошено', Icons.block_rounded, curSt == 'drop', 'drop', ctx)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaTag(String text, {Color? textColor, Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFF282236),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x38FFFFFF), width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor ?? C.tx,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? C.jd : C.tx),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? C.jd : C.tx2,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String title, int index) {
    final on = _activeTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 22),
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: on ? C.tx : Colors.transparent,
              width: 2.8,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: on ? C.tx : C.tx2,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final st = store.listOf[d.id];
          final r = store.rate[d.id];
          final activeDub = store.dubOf[d.id];
          final title = store.ruTitle(d);
          final sum = store.sumRu[d.id];
          final soon = d.date.isNotEmpty && d.date.compareTo(todayIso()) > 0;
          final cs = (cast != null && cast!.isNotEmpty) ? cast! : store.richCastOf(d);
          final el = (eps != null && eps!.isNotEmpty)
              ? eps!
              : List<Ep>.generate(
                  total > 0 ? total : 12,
                  (i) => Ep(1, i + 1, 'Серия ${i + 1}', d.date, '21:00'),
                );
          final nextEpNum = ((store.prog[d.id] ?? 0) + 1).clamp(1, el.isNotEmpty ? el.length : 999);
          final trailerUrl = 'https://m.youtube.com/results?search_query=${Uri.encodeComponent("$title ${d.en} ${d.year ?? ""} дорама трейлер")}';
          final genreLine = d.genres.isEmpty ? 'Драма, Мелодрама' : d.genres.take(3).map(ruGenre).join(', ');
          final netColor = d.network.toLowerCase().contains('netflix')
              ? const Color(0xFFE50914)
              : (d.network.toLowerCase().contains('disney') || d.network.toLowerCase().contains('hulu')
                  ? const Color(0xFF1CE783)
                  : C.pk);

          return CustomScrollView(
            slivers: [
              // ── 1. КИНЕМАТОГРАФИЧНЫЙ ПОСТЕР И БЛОК УПРАВЛЕНИЯ ──
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          height: 440,
                          width: double.infinity,
                          child: Poster(d),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.25, 0.58, 0.88, 1.0],
                                colors: [
                                  C.bg.withOpacity(0.72),
                                  Colors.transparent,
                                  C.bg.withOpacity(0.25),
                                  C.bg.withOpacity(0.92),
                                  C.bg,
                                ],
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back_rounded, color: C.tx, size: 24),
                                  style: IconButton.styleFrom(backgroundColor: const Color(0x880E0B14)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.date.isNotEmpty ? fmtDate(d.date) : '${d.year ?? 2026} · Южная Корея',
                                        style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      Text(
                                        soon ? 'Ожидается премьера' : ruStatus(d.status.isEmpty ? 'Ended' : d.status),
                                        style: const TextStyle(color: C.tx2, fontSize: 11.5),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showStatusPickerSheet(context, st),
                                  icon: Icon(
                                    st != null ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                    color: st != null ? C.jd : C.tx,
                                    size: 22,
                                  ),
                                  style: IconButton.styleFrom(backgroundColor: const Color(0x880E0B14)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 14,
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (d.network.isNotEmpty)
                                    Text(
                                      d.network.toLowerCase(),
                                      style: TextStyle(
                                        color: netColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                title.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: C.tx,
                                  letterSpacing: 1.1,
                                  height: 1.12,
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 3)),
                                  ],
                                ),
                              ),
                              if (title != d.en) ...[
                                const SizedBox(height: 4),
                                Text(
                                  d.en.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: C.tx2,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _metaTag('16+'),
                            _metaTag('HD'),
                            _metaTag('RU / SUB'),
                            if (d.rating != null || r != null)
                              _metaTag('★ ${r ?? d.rating!.toStringAsFixed(1)}', textColor: C.gd),
                            if (activeDub != null && activeDub.isNotEmpty)
                              _metaTag(activeDub, textColor: C.pk),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '${d.year ?? 2026} • 1 сезон ($total сер.) • $genreLine',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: C.tx2, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Главная кнопка:
                    // Вариант 1 (store.showWatchBtn == true): «► СМОТРЕТЬ СЕЙЧАС» — открывает окно выбора площадки (ВК Видео, Яндекс Видео, Doramy.club, OK, Rutube, Кинопоиск, Иви)
                    // Вариант 2 (store.showWatchBtn == false): чистый режим списка «В МОЙ СПИСОК / ОТМЕТИТЬ СЕРИЮ»
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: store.showWatchBtn
                          ? SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => showWatchOptionsSheet(context, d, epNum: nextEpNum),
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                                label: Text(
                                  st == 'watch' && (store.prog[d.id] ?? 0) > 0
                                      ? 'СМОТРЕТЬ · СЕРИЯ $nextEpNum'
                                      : 'СМОТРЕТЬ',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton.icon(
                                onPressed: () {
                                  if (st == 'watch') {
                                    store.setProg(d, nextEpNum);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Отмечена Серия $nextEpNum из $total')),
                                    );
                                  } else {
                                    _showStatusPickerSheet(context, st);
                                  }
                                },
                                icon: Icon(
                                  st == 'watch' ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                                  size: 21,
                                ),
                                label: Text(
                                  st == 'watch'
                                      ? 'ОТМЕТИТЬ СЕРИЮ $nextEpNum ПРОСМОТРЕННОЙ (+1)'
                                      : (st != null ? 'ИЗМЕНИТЬ СТАТУС В МОЁМ СПИСКЕ' : 'ДОБАВИТЬ В МОЙ СПИСОК'),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: C.pk,
                                  foregroundColor: C.onPk,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _actionIcon(
                          Icons.ondemand_video_rounded,
                          'ТРЕЙЛЕР',
                          () => _openExternal(trailerUrl, 'YouTube'),
                        ),
                        _actionIcon(
                          st != null ? Icons.check_rounded : Icons.add_rounded,
                          st == 'watch'
                              ? 'СМОТРЮ'
                              : (st == 'plan'
                                  ? 'В ПЛАНАХ'
                                  : (st == 'done' ? 'ПРОСМОТРЕНО' : 'МОЙ СПИСОК')),
                          () => _showStatusPickerSheet(context, st),
                          active: st != null,
                        ),
                        _actionIcon(
                          Icons.mic_none_rounded,
                          activeDub != null && activeDub.isNotEmpty ? activeDub.toUpperCase() : 'ОЗВУЧКА',
                          () => setState(() => _activeTab = 3),
                          active: activeDub != null && activeDub.isNotEmpty,
                        ),
                        _actionIcon(
                          Icons.public_rounded,
                          'ГДЕ СМОТРЕТЬ',
                          () => showWatchOptionsSheet(context, d, epNum: nextEpNum),
                        ),
                      ],
                    ),

                    // Синопсис (описание дорамы)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                      child: sum != null
                          ? Text(
                              sum,
                              style: const TextStyle(color: C.tx, fontSize: 14.5, height: 1.45),
                            )
                          : (sumBusy || !loaded
                              ? const Row(children: [
                                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                                  SizedBox(width: 10),
                                  Text('Переводим описание…', style: TextStyle(color: C.tx2)),
                                ])
                              : Text(
                                  d.id < 0 ? 'Описание появится ближе к премьере.' : 'Захватывающая корейская дорама ${d.year ?? 2026} года ($genreLine).',
                                  style: const TextStyle(color: C.tx2, fontSize: 14, height: 1.45),
                                )),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: EpisodeCountdownBadge(d, banner: true),
                    ),

                    if (cs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Актёры и кого они играют',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.tx),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(() => _activeTab = 1),
                                  child: Text(
                                    'Весь каст (${cs.length}) →',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: C.pk),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 142,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: cs.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (_, idx) {
                                  final a = cs[idx];
                                  final isMain = idx < 2 || a.role.toLowerCase().contains('главная');
                                  final roleTxt = a.role.isNotEmpty
                                      ? a.role
                                      : (isMain ? 'Главная роль' : 'Второстепенная роль');
                                  final ph = store.actorPhotoOf(a.name, a.photo);
                                  return GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ActorPage(actor: a)),
                                    ),
                                    child: Container(
                                      width: 215,
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: C.s1,
                                        border: Border.all(color: isMain ? const Color(0x66FFB84D) : C.line),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: SizedBox(
                                              width: 62,
                                              height: 86,
                                              child: ph.isEmpty
                                                  ? Container(
                                                      color: C.s2,
                                                      child: const Icon(Icons.person_rounded, color: C.tx2),
                                                    )
                                                  : CachedPic(
                                                      ph,
                                                      placeholder: Container(
                                                        color: C.s2,
                                                        child: const Icon(Icons.person_rounded, color: C.tx2),
                                                      ),
                                                    ),
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
                                                    color: isMain ? const Color(0x28FFB84D) : C.bg,
                                                    borderRadius: BorderRadius.circular(5),
                                                    border: Border.all(
                                                      color: isMain ? const Color(0x66FFB84D) : C.line,
                                                      width: 0.7,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    isMain ? 'ГЛАВНАЯ РОЛЬ' : 'В РОЛЯХ',
                                                    style: TextStyle(
                                                      color: isMain ? C.gd : C.tx2,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  store.ruActor(a.name),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13.5,
                                                    color: C.tx,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  roleTxt,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: C.gd,
                                                    fontSize: 11.2,
                                                    fontWeight: FontWeight.w700,
                                                    height: 1.2,
                                                  ),
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
                        ),
                      ),

                    if (st == 'watch')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: _progressBox(),
                      ),

                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: C.line, width: 1)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _tabItem('СЕРИИ', 0),
                            _tabItem('АКТЁРЫ (${cs.length})', 1),
                            _tabItem('ПОХОЖИЕ', 2),
                            _tabItem('ОЗВУЧКА И ОЦЕНКА', 3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 2. КОНТЕНТ ВЫБРАННОЙ ВКЛАДКИ ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
                  child: _buildActiveTabContent(el, cs, title, activeDub, r),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveTabContent(List<Ep> el, List<Actor> cs, String title, String? activeDub, int? r) {
    if (_activeTab == 0) {
      return _episodesTab(el, title, activeDub);
    } else if (_activeTab == 1) {
      return _actorsTab(cs);
    } else if (_activeTab == 2) {
      return _similarTab();
    } else {
      return _detailsTab(title, activeDub, r);
    }
  }

  Widget _episodesTab(List<Ep> l, String title, String? activeDub) {
    final t = todayIso();
    final p = store.prog[d.id] ?? 0;
    final showCount = allEps ? l.length : (l.length > 12 ? 12 : l.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Сезон 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.tx)),
            const Spacer(),
            Text(
              'Просмотрено: $p из ${l.length}',
              style: const TextStyle(color: C.tx2, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < showCount; i++)
          _episodeCardRow(i, l[i], t, p),
        if (l.length > 12)
          Center(
            child: TextButton(
              onPressed: () => setState(() => allEps = !allEps),
              child: Text(
                allEps ? 'Свернуть серии' : 'Показать все серии (${l.length})',
                style: const TextStyle(color: C.pk, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _watchPlatformsSection(title, activeDub),
      ],
    );
  }

  Widget _episodeCardRow(int i, Ep e, String today, int p) {
    final epNum = e.number > 0 ? e.number : (i + 1);
    final seen = i < p;
    final out = e.airdate.isEmpty || e.airdate.compareTo(today) <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (store.showWatchBtn) {
                showWatchOptionsSheet(context, d, epNum: epNum);
              } else {
                if (store.listOf[d.id] == null) store.setList(d, 'watch');
                store.setProg(d, (seen && i + 1 == p) ? i : i + 1);
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 132,
                height: 76,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Poster(d),
                    Container(color: Colors.black.withOpacity(seen ? 0.55 : 0.32)),
                    Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: seen ? C.jd : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          seen
                              ? Icons.check_rounded
                              : (store.showWatchBtn ? Icons.play_arrow_rounded : Icons.add_rounded),
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                    if (seen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(height: 3.5, color: C.jd),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showWatchOptionsSheet(context, d, epNum: epNum),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$epNum. Серия $epNum',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: C.tx),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 ч 05 мин${e.airdate.isNotEmpty ? " · ${fmtDate(e.airdate)}" : ""}',
                      style: TextStyle(color: out ? C.tx2 : C.gd, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: seen ? 'Снять отметку' : 'Отметить просмотренной',
            onPressed: () {
              if (store.listOf[d.id] == null) store.setList(d, 'watch');
              store.setProg(d, (seen && i + 1 == p) ? i : i + 1);
            },
            icon: Icon(
              seen ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: seen ? C.jd : C.tx2,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actorsTab(List<Actor> cs) {
    if (cs.isEmpty) {
      return const EmptyBox(Icons.people_outline_rounded, 'Актёрский состав уточняется',
          'Список актёров появится после синхронизации с базой.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Актёрский состав и роли в дораме',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: C.tx)),
        const SizedBox(height: 4),
        const Text('Указано имя каждого актёра, его персонаж в сюжете и другие известные дорамы.',
            style: TextStyle(fontSize: 12, color: C.tx2)),
        const SizedBox(height: 12),
        for (var idx = 0; idx < cs.length; idx++)
          Builder(builder: (context) {
            final a = cs[idx];
            final isMain = idx < 2 || a.role.toLowerCase().contains('главная');
            final roleText = a.role.isNotEmpty
                ? a.role
                : (isMain ? 'Главная роль (ведущий герой дорамы)' : 'Второстепенная роль в дораме');
            final ph = store.actorPhotoOf(a.name, a.photo);
            final otherDramas = store
                .dramasForActorKey(a.name)
                .where((x) => x.id != d.id)
                .take(3)
                .map(store.ruTitle)
                .join(', ');
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: a))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: C.s1,
                  border: Border.all(color: isMain ? const Color(0x66FFB84D) : C.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 62,
                        height: 82,
                        child: ph.isEmpty
                            ? Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))
                            : CachedPic(ph,
                                placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isMain ? const Color(0x28FFB84D) : C.bg,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: isMain ? const Color(0x66FFB84D) : C.line, width: 0.7),
                                ),
                                child: Text(
                                  isMain ? 'ГЛАВНАЯ РОЛЬ' : 'ВТОРОСТЕПЕННАЯ РОЛЬ',
                                  style: TextStyle(
                                    color: isMain ? C.gd : C.tx2,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(store.ruActor(a.name),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: C.tx)),
                          if (store.ruActor(a.name) != a.name)
                            Text(a.name, style: const TextStyle(color: C.tx2, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            'Кого играет: $roleText',
                            style: const TextStyle(color: C.gd, fontSize: 12.8, fontWeight: FontWeight.w700, height: 1.25),
                          ),
                          if (otherDramas.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Другие дорамы: $otherDramas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.tx2, fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => store.toggleFavActor(a.name),
                      icon: Icon(
                        store.isFavActor(a.name) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: store.isFavActor(a.name) ? C.pk : C.tx2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _similarTab() {
    final m = store.rate[d.id] == null ? Taste.match(d) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (m != null) ...[
          MatchCard(d, m),
          const SizedBox(height: 16),
        ],
        if (sim.isEmpty)
          const EmptyBox(Icons.movie_filter_rounded, 'Похожие дорамы загружаются',
              'Мы подбираем сериалы со схожими жанрами и атмосферой.')
        else
          PosterRail(sim),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: extraBtn('Сравнить с другими дорамами', Icons.compare_arrows_rounded,
              () => openCompare(context, first: d)),
        ),
      ],
    );
  }

  Widget _detailsTab(String title, String? activeDub, int? r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dubPickerSection(activeDub),
        const SectionTitle('Настройка кнопки просмотра'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: C.s1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.line),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: C.pk,
            title: const Text('Кнопка «Смотреть сейчас»', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            subtitle: const Text(
              'Если включено — при нажатии открывается выбор сайта (ВК Видео, Яндекс, Doramy.club и др.). Если выключено — в приложении только список.',
              style: TextStyle(color: C.tx2, fontSize: 12),
            ),
            value: store.showWatchBtn,
            onChanged: (v) => store.setShowWatchBtn(v),
          ),
        ),
        const SectionTitle('Ваша оценка'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 1; i <= 10; i++)
            GestureDetector(
              onTap: () => store.setRate(d, r == i ? null : i),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r == i ? C.gd : C.s1,
                  border: Border.all(color: r == i ? C.gd : C.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$i', style: TextStyle(fontWeight: FontWeight.w900, color: r == i ? C.bg : C.tx2)),
              ),
            ),
        ]),
        const SectionTitle('Личные заметки'),
        TextField(
          controller: noteCtl,
          minLines: 2,
          maxLines: 5,
          onChanged: (v) => store.setNote(d, v),
          style: const TextStyle(color: C.tx),
          decoration: InputDecoration(
            hintText: 'Что понравилось, на какой минуте остановились…',
            hintStyle: const TextStyle(color: C.tx2),
            filled: true,
            fillColor: C.s1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: C.line),
            ),
          ),
        ),
        const SectionTitle('Своё русское название'),
        Row(children: [
          Expanded(
            child: TextField(
              controller: nameCtl,
              style: const TextStyle(color: C.tx),
              decoration: InputDecoration(
                hintText: title,
                hintStyle: const TextStyle(color: C.tx2),
                filled: true,
                fillColor: C.s1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: C.line),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () {
              store.setCustom(d, nameCtl.text);
              FocusScope.of(context).unfocus();
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.pk,
              foregroundColor: C.onPk,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            ),
            child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ],
    );
  }

  Widget _watchPlatformsSection(String title, String? activeDub) {
    final nextEpNum = (store.prog[d.id] ?? 0) + 1;
    final dubQuery = (activeDub != null && activeDub.isNotEmpty) ? ' $activeDub' : ' SoftBox';
    final qVk = Uri.encodeComponent('$title дорама$dubQuery $nextEpNum серия');
    final qYandex = Uri.encodeComponent('$title дорама$dubQuery $nextEpNum серия смотреть онлайн');
    final qDoramyClub = Uri.encodeComponent(title);
    final qGoogle = Uri.encodeComponent('$title дорама $nextEpNum серия смотреть онлайн$dubQuery');
    final qOk = Uri.encodeComponent('$title дорама$dubQuery $nextEpNum серия');
    final qRutube = Uri.encodeComponent('$title дорама$dubQuery $nextEpNum серия');
    final qKp = Uri.encodeComponent(title);
    final qIvi = Uri.encodeComponent(title);
    final qSoftBox = Uri.encodeComponent('$title дорама SoftBox $nextEpNum серия');
    final qDubLik = Uri.encodeComponent('$title дорама DubLik $nextEpNum серия');

    final platforms = <(String, IconData, String)>[
      ('VK Видео', Icons.play_circle_outline_rounded, 'https://m.vk.com/video?q=$qVk'),
      ('Яндекс Видео / Kodik', Icons.ondemand_video_rounded, 'https://yandex.ru/video/touch/search?text=$qYandex'),
      ('Doramy.club', Icons.public_rounded, 'https://doramy.club/?s=$qDoramyClub'),
      ('Dorama.land (Google)', Icons.travel_explore_rounded, 'https://www.google.com/search?q=$qGoogle'),
      ('SoftBox (ВК)', Icons.mic_none_rounded, 'https://m.vk.com/video?q=$qSoftBox'),
      ('DubLik TV (ВК)', Icons.record_voice_over_outlined, 'https://m.vk.com/video?q=$qDubLik'),
      ('OK Видео', Icons.video_library_outlined, 'https://m.ok.ru/video/search?st.query=$qOk'),
      ('Rutube', Icons.smart_display_outlined, 'https://rutube.ru/search/?query=$qRutube'),
      ('Кинопоиск', Icons.movie_outlined, 'https://www.kinopoisk.ru/index.php?kp_query=$qKp'),
      ('Иви', Icons.tv_rounded, 'https://www.ivi.ru/search/?q=$qIvi'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Где смотреть онлайн (сайты и озвучки)'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in platforms)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openExternal(p.$3, p.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: C.s1,
                border: Border.all(color: C.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(p.$2, size: 15, color: C.pk),
                const SizedBox(width: 6),
                Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: C.tx)),
              ]),
            ),
          ),
      ]),
    ]);
  }

  Widget _dubPickerSection(String? activeDub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Студия озвучки (отображается на карточке)'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final studio in kDubStudios)
          GestureDetector(
            onTap: () {
              final nextVal = activeDub == studio ? null : studio;
              store.setDub(d, nextVal);
              dubCtl.text = nextVal ?? '';
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: activeDub == studio ? C.pk : C.s1,
                border: Border.all(color: activeDub == studio ? C.pk : C.line),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                studio,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: activeDub == studio ? C.onPk : C.tx2,
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: TextField(
            controller: dubCtl,
            style: const TextStyle(color: C.tx, fontSize: 13.5),
            onSubmitted: (v) => store.setDub(d, v),
            decoration: InputDecoration(
              hintText: 'Или введите свою студию озвучки…',
              hintStyle: const TextStyle(color: C.tx2, fontSize: 12.5),
              filled: true,
              fillColor: C.s1,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: C.line),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            store.setDub(d, dubCtl.text);
            FocusScope.of(context).unfocus();
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: C.s1,
            foregroundColor: C.tx,
            side: const BorderSide(color: C.line),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('ОК', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    ]);
  }

  Widget _progressBox() {
    final p = store.prog[d.id] ?? 0;
    final t = total;
    final dub = store.dubOf[d.id];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.s1,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t > 0 ? 'Просмотрено серий: $p из $t' : 'Просмотрено серий: $p',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (dub != null && dub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Озвучка: $dub', style: const TextStyle(color: C.pk, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
          IconButton(
            onPressed: p > 0 ? () => store.setProg(d, p - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          IconButton(
            onPressed: (t == 0 || p < t) ? () => store.setProg(d, p + 1) : null,
            icon: const Icon(Icons.add_circle_rounded, color: C.pk),
          ),
        ]),
        if (t > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (p / t).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: C.jd,
              backgroundColor: C.s2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => store.finishWatching(d),
              icon: const Icon(Icons.check_circle_rounded, size: 18, color: C.jd),
              label: const Text('Отметить полностью просмотренной',
                  style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 12.5)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: C.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _listBtn(String t, IconData i, bool on, String key, BuildContext sheetCtx) {
    return GestureDetector(
      onTap: () {
        store.setList(d, on ? null : key);
        Navigator.of(sheetCtx).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? C.pk : C.s2,
          border: Border.all(color: on ? C.pk : C.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(i, color: on ? C.onPk : C.tx, size: 20),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: on ? C.onPk : C.tx2),
            ),
          ),
        ]),
      ),
    );
  }
}

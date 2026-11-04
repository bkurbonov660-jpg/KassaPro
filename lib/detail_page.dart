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
  int _activeTab = 0; // 0: СЕРИИ, 1: ПОХОЖИЕ, 2: АКТЁРЫ, 3: ДЕТАЛИ
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
      if (mounted && l != null) setState(() => eps = l);
    });
    Tvmaze.cast(d.id).then((l) {
      final hasCurated = store.hasCuratedCast(d);
      if (hasCurated && localCast.isNotEmpty) {
        final merged = List<Actor>.from(localCast);
        final seenKeys = merged.map((a) => ak(a.name)).toSet();
        for (final tvA in l) {
          if (seenKeys.add(ak(tvA.name))) {
            merged.add(Actor(tvA.id, tvA.name, tvA.role, store.actorPhotoOf(tvA.name, tvA.photo)));
          }
        }
        if (mounted) setState(() => cast = merged);
        store.ensureActorNames(merged.map((a) => a.name).toList());
        _enrichLocalCast(merged);
      } else if (l.isNotEmpty && localCast.length <= l.length) {
        final enriched = [
          for (final tvA in l)
            Actor(
              (ak(tvA.name) == 'kimjunghyun' || ak(tvA.name) == 'yeonwoo') ? -300 : tvA.id,
              tvA.name,
              tvA.role,
              store.actorPhotoOf(tvA.name, '').isNotEmpty ? store.actorPhotoOf(tvA.name, '') : tvA.photo,
            ),
        ];
        if (mounted) setState(() => cast = enriched);
        store.ensureActorNames(enriched.map((a) => a.name).toList());
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

  int get total => store.totals[d.id] ?? (eps?.length ?? 12);

  int get aired {
    final l = eps;
    if (l == null) return 0;
    final t = todayIso();
    return l.where((e) => e.airdate.isNotEmpty && e.airdate.compareTo(t) <= 0).length;
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
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? C.jd : C.tx),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? C.jd : C.tx2,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
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
          final el = eps ??
              List<Ep>.generate(
                total > 0 ? total : 12,
                (i) => Ep(1, i + 1, 'Серия ${i + 1}', d.date, '21:00'),
              );
          final nextEpNum = (store.prog[d.id] ?? 0) + 1;
          final dubQuery = (activeDub != null && activeDub.isNotEmpty) ? ' $activeDub' : ' SoftBox';
          final watchUrl = 'https://vkvideo.ru/?q=${Uri.encodeComponent("$title дорама$dubQuery серия $nextEpNum")}';
          final trailerUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent("${d.en} ${d.year ?? ""} official trailer korean drama")}';
          final genreLine = d.genres.isEmpty ? 'Драма, Мелодрама' : d.genres.take(3).map(ruGenre).join(', ');
          final netColor = d.network.toLowerCase().contains('netflix')
              ? const Color(0xFFE50914)
              : (d.network.toLowerCase().contains('disney') || d.network.toLowerCase().contains('hulu')
                  ? const Color(0xFF1CE783)
                  : C.pk);

          return CustomScrollView(
            slivers: [
              // ── 1. КИНЕМАТОГРАФИЧНЫЙ ПОСТЕР И БЛОК УПРАВЛЕНИЯ В СТИЛЕ ФОТО №2 (73559.jpg) ──
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
                        // Плавный градиент сверху и снизу постера
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
                        // Верхний бар: кнопка Назад + дата/статус + кнопка-галочка в список
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
                        // Крупный кинематографичный заголовок с засечками и логотип канала справа (как на фото 73559.jpg)
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
                    // Ряд бейджей: [16+] [HD] [CC] [★ Рейтинг] [SoftBox] (как на фото 73559.jpg)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 10),
                    // Строка: 2026 • 1 сезон (12 серий) • Драма, Комедия
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

                    // Широкая белая капсульная кнопка ► СМОТРЕТЬ СЕЙЧАС (точь-в-точь как VER AHORA на фото 73559.jpg)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (st == null) store.setList(d, 'watch');
                            _openExternal(watchUrl, 'VK Видео');
                          },
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                          label: Text(
                            st == 'watch' && (store.prog[d.id] ?? 0) > 0
                                ? 'СМОТРЕТЬ СЕРИЮ $nextEpNum'
                                : 'СМОТРЕТЬ СЕЙЧАС',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    // Иконки под кнопкой: ТРЕЙЛЕР | МОЙ СПИСОК | ОЗВУЧКА | СРАВНИТЬ (как на фото 73559.jpg)
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

                    // Баннер обратного отсчёта до следующей серии
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: EpisodeCountdownBadge(d, banner: true),
                    ),

                    // Быстрый блок прогресса, если сериал в списке «Смотрю»
                    if (st == 'watch')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                        child: _progressBox(),
                      ),

                    const SizedBox(height: 18),
                    // Панель вкладок с белым подчёркиванием (как EPISODIOS | SUGERENCIAS | EXTRAS на фото 73559.jpg)
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

  // Вкладка СЕРИИ — точно как на фото 73559.jpg:
  // Заголовок «Сезон 1», список серий с горизонтальным превью-кадром 16:9, круглой белой кнопкой Play,
  // названием «1. Серия 1», длительностью «1 ч 05 мин» и отметкой просмотра
  Widget _episodesTab(List<Ep> l, String title, String? activeDub) {
    final t = todayIso();
    final p = store.prog[d.id] ?? 0;
    final showCount = allEps ? l.length : (l.length > 12 ? 12 : l.length);
    final dubQuery = (activeDub != null && activeDub.isNotEmpty) ? ' $activeDub' : '';

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
          _episodeCardRow(i, l[i], t, p, title, dubQuery),
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

  Widget _episodeCardRow(int i, Ep e, String today, int p, String title, String dubQuery) {
    final epNum = e.number > 0 ? e.number : (i + 1);
    final seen = i < p;
    final out = e.airdate.isEmpty || e.airdate.compareTo(today) <= 0;
    final epUrl = 'https://vkvideo.ru/?q=${Uri.encodeComponent("$title дорама$dubQuery серия $epNum")}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Миниатюра кадра серии 16:9 с белой круглой кнопкой Play по центру (как на фото 73559.jpg)
          GestureDetector(
            onTap: () {
              if (store.listOf[d.id] == null) store.setList(d, 'watch');
              if (p < epNum) store.setProg(d, epNum);
              _openExternal(epUrl, 'Серия $epNum');
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
                          seen ? Icons.check_rounded : Icons.play_arrow_rounded,
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
        const Text('В главных ролях и каст дорамы',
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: C.tx)),
        const SizedBox(height: 12),
        for (final a in cs)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: a))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: C.s1,
                border: Border.all(color: C.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 56,
                      height: 72,
                      child: a.photo.isEmpty
                          ? Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))
                          : CachedPic(a.photo,
                              placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.ruActor(a.name),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: C.tx)),
                        if (store.ruActor(a.name) != a.name)
                          Text(a.name, style: const TextStyle(color: C.tx2, fontSize: 12.5)),
                        if (a.role.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(a.role, style: const TextStyle(color: C.gd, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
          ),
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
    final dubQuery = (activeDub != null && activeDub.isNotEmpty) ? ' $activeDub' : '';
    final qVk = Uri.encodeComponent('$title дорама$dubQuery');
    final qKp = Uri.encodeComponent(title);
    final qIvi = Uri.encodeComponent(title);
    final qSoftBox = Uri.encodeComponent('$title дорама SoftBox');
    final qDubLik = Uri.encodeComponent('$title дорама DubLik');
    final qMania = Uri.encodeComponent('$title дорама FSG Мания');
    final qKodik = Uri.encodeComponent('$title дорама смотреть онлайн$dubQuery серия $nextEpNum');

    final platforms = <(String, IconData, String)>[
      ('VK Видео', Icons.play_circle_outline_rounded, 'https://vkvideo.ru/?q=$qVk'),
      ('SoftBox', Icons.mic_none_rounded, 'https://vkvideo.ru/?q=$qSoftBox'),
      ('DubLik TV', Icons.record_voice_over_outlined, 'https://vkvideo.ru/?q=$qDubLik'),
      ('Кинопоиск', Icons.movie_outlined, 'https://www.kinopoisk.ru/index.php?kp_query=$qKp'),
      ('Иви', Icons.tv_rounded, 'https://www.ivi.ru/search/?q=$qIvi'),
      ('Kodik', Icons.ondemand_video_rounded, 'https://yandex.ru/video/search?text=$qKodik'),
      ('FSG Мания', Icons.subtitles_outlined, 'https://vkvideo.ru/?q=$qMania'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Площадки и озвучки'),
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

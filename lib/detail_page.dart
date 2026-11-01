import 'package:flutter/material.dart';
import 'actor_page.dart';
import 'data2026.dart';
import 'dict.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'player_page.dart';
import 'store.dart';
import 'streams_loader.dart';
import 'taste.dart';
import 'tvmaze.dart';
import 'ui_common.dart';
import 'widgets.dart';

void openDrama(BuildContext c, Drama d) {
  Navigator.of(c).push(MaterialPageRoute(builder: (_) => DetailPage(drama: d)));
}

void showListPickerSheet(BuildContext context, Drama d) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.s1,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      final st = store.listOf[d.id];
      final items = <(String, String, IconData)>[
        ('watch', 'Смотрю', Icons.visibility_rounded),
        ('plan', 'В планах', Icons.bookmark_rounded),
        ('done', 'Просмотрено', Icons.check_circle_rounded),
        ('drop', 'Брошено', Icons.block_rounded),
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
              Text(
                store.ruTitle(d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.tx),
              ),
              const SizedBox(height: 8),
              for (final it in items)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  leading: Icon(it.$3, color: st == it.$1 ? Colors.white : C.tx2),
                  title: Text(
                    it.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: st == it.$1 ? Colors.white : C.tx,
                    ),
                  ),
                  trailing: st == it.$1 ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                  onTap: () {
                    store.setList(d, st == it.$1 ? null : it.$1);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        ),
      );
    },
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
  int _tabIdx = 0; // 0: ЭПИЗОДЫ, 1: ПОХОЖИЕ, 2: АКТЁРЫ, 3: ДЕТАЛИ
  late final TextEditingController nameCtl;
  late final TextEditingController noteCtl;
  late final TextEditingController dubCtl;
  late final List<Drama> sim;

  List<Map<String, dynamic>> _kodikStreams = <Map<String, dynamic>>[];
  Future<List<Map<String, dynamic>>>? _kodikFuture;

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
    _preloadKodik();
  }

  void _preloadKodik() {
    final ru = store.ruTitle(d);
    _kodikFuture = StreamsLoader.searchKodik(
      ruTitle: ru,
      enTitle: d.en,
      imdb: d.imdb,
      dramaId: d.id,
    ).then((list) {
      if (mounted) {
        setState(() => _kodikStreams = list);
      }
      return list;
    });
  }

  @override
  void dispose() {
    nameCtl.dispose();
    noteCtl.dispose();
    dubCtl.dispose();
    super.dispose();
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
        updated[i] = Actor(pid ?? a.id, a.name, a.role, bestPh);
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

  int get total => store.totals[d.id] ?? (eps?.length ?? 0);

  int get aired {
    final l = eps;
    if (l == null) return 0;
    final t = todayIso();
    return l.where((e) => e.airdate.isNotEmpty && e.airdate.compareTo(t) <= 0).length;
  }

  int get _watchEpNum {
    final maxEp = total > 0 ? total : (aired > 0 ? aired : 16);
    final watched = store.prog[d.id] ?? 0;
    final st = store.listOf[d.id];
    if (watched <= 0 || st == 'done' || watched >= maxEp) {
      return 1;
    }
    return (watched + 1).clamp(1, maxEp);
  }

  String get _watchBtnLabel {
    final maxEp = total > 0 ? total : (aired > 0 ? aired : 16);
    final watched = store.prog[d.id] ?? 0;
    final st = store.listOf[d.id];
    if (watched <= 0 || st == 'done' || watched >= maxEp) {
      return 'СМОТРЕТЬ';
    }
    return 'СМОТРЕТЬ $_watchEpNum СЕРИЮ';
  }

  Future<void> _launchPlayer({int? episode, String? dubOverride}) async {
    final epToWatch = episode ?? _watchEpNum;
    final activeDub = dubOverride ?? store.dubOf[d.id];

    var streams = _kodikStreams;
    if (streams.isEmpty) {
      final ru = store.ruTitle(d);
      streams = await (_kodikFuture ??
          StreamsLoader.searchKodik(
            ruTitle: ru,
            enTitle: d.en,
            imdb: d.imdb,
            dramaId: d.id,
          ));
    }

    if (!mounted) return;

    if (streams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Потоки для этой дорамы пока не найдены'),
          backgroundColor: C.rd,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          drama: d,
          streams: streams,
          initialEpisode: epToWatch,
          initialDub: activeDub,
        ),
      ),
    );
  }

  void _showDubSheet(String? activeDub) {
    final dubs = StreamsLoader.getAvailableDubs(_kodikStreams);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.s1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                const Text('Выбор озвучки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.tx)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final studio in dubs)
                      GestureDetector(
                        onTap: () {
                          store.setDub(d, studio);
                          dubCtl.text = studio;
                          Navigator.of(ctx).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: activeDub == studio ? Colors.white : C.s2,
                            border: Border.all(color: activeDub == studio ? Colors.white : C.line),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            studio,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: activeDub == studio ? Colors.black : C.tx,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0xFF25232E),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _tabHeader(int idx, String label) {
    final on = _tabIdx == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIdx = idx),
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: on ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : C.tx2,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0B14),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final st = store.listOf[d.id];
          final r = store.rate[d.id];
          final activeDub = store.dubOf[d.id];
          final title = store.ruTitle(d);
          final sum = store.sumRu[d.id];
          final cs = (cast != null && cast!.isNotEmpty) ? cast! : store.richCastOf(d);
          final el = eps;
          final effTotal = total > 0 ? total : (aired > 0 ? aired : 16);
          final gTxt = d.genres.isNotEmpty ? d.genres.take(2).map(ruGenre).join(', ') : 'Драма, Комедия';
          final metaLine = '${d.year ?? 2026} • 1 сезон • $gTxt';

          return CustomScrollView(
            slivers: [
              // Верхний полноэкранный постер с плавным переходом в тёмный фон (как на фото 73313.jpg)
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: 430,
                      width: double.infinity,
                      child: Poster(d),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x330E0B14),
                              Color(0x000E0B14),
                              Color(0xCC0E0B14),
                              Color(0xFF0E0B14),
                            ],
                            stops: [0.0, 0.35, 0.78, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 6,
                      left: 10,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 12,
                      child: Column(
                        children: [
                          Text(
                            title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.08,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (d.network.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                d.network.toLowerCase(),
                                style: const TextStyle(
                                  color: C.jd,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Бейджи [14+] [HD] [CC] по центру
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _badgeChip('14+'),
                          const SizedBox(width: 8),
                          _badgeChip('HD'),
                          const SizedBox(width: 8),
                          _badgeChip('CC'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Строка: 2026 • 1 сезон • Драма, Комедия
                      Center(
                        child: Text(
                          metaLine,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC8C2D6),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Большая белая кнопка «▶ СМОТРЕТЬ» (точно как ▶ VER AHORA на фото)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: () => _launchPlayer(),
                          icon: const Icon(Icons.play_arrow_rounded, size: 26, color: Colors.black),
                          label: Text(
                            _watchBtnLabel,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              letterSpacing: 1.4,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      // Две иконки по центру под кнопкой: ОЗВУЧКА и МОЙ СПИСОК
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showDubSheet(activeDub),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              child: Column(
                                children: [
                                  const Icon(Icons.subtitles_outlined, color: Colors.white, size: 24),
                                  const SizedBox(height: 6),
                                  Text(
                                    (activeDub != null && activeDub.isNotEmpty) ? activeDub.toUpperCase() : 'ОЗВУЧКА',
                                    style: const TextStyle(
                                      color: Color(0xFFB5AFC2),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => showListPickerSheet(context, d),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              child: Column(
                                children: [
                                  Icon(
                                    st != null ? Icons.check_rounded : Icons.add_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    st != null ? 'В СПИСКЕ' : 'МОЙ СПИСОК',
                                    style: const TextStyle(
                                      color: Color(0xFFB5AFC2),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // Описание дорамы
                      if (sum != null)
                        Text(
                          sum,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEAE4F2),
                            height: 1.42,
                            fontSize: 14.5,
                          ),
                        )
                      else if (sumBusy || !loaded)
                        const Text('Загружаем описание…', style: TextStyle(color: C.tx2))
                      else
                        Text(
                          'История разворачивается в Южной Корее (${d.year ?? 2026}) и объединяет жанры: $gTxt.',
                          style: const TextStyle(color: Color(0xFFEAE4F2), height: 1.42, fontSize: 14.5),
                        ),

                      const SizedBox(height: 24),
                      // Вкладки: ЭПИЗОДЫ | ПОХОЖИЕ | АКТЁРЫ | ДЕТАЛИ
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _tabHeader(0, 'ЭПИЗОДЫ'),
                            _tabHeader(1, 'ПОХОЖИЕ'),
                            _tabHeader(2, 'АКТЁРЫ'),
                            _tabHeader(3, 'ДЕТАЛИ'),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF282235), height: 1),
                      const SizedBox(height: 18),

                      // Содержимое выбранной вкладки
                      if (_tabIdx == 0) ...[
                        Row(
                          children: [
                            const Text(
                              'Сезон 1',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            if (_kodikStreams.isNotEmpty)
                              Text(
                                StreamsLoader.getAvailableDubs(_kodikStreams).take(3).join(' · '),
                                style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        for (var i = 1; i <= effTotal; i++)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _launchPlayer(episode: i),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 138,
                                      height: 80,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Poster(d),
                                          Container(color: Colors.black38),
                                          Center(
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.black,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          if ((store.prog[d.id] ?? 0) >= i)
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
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$i. Серия $i',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          (el != null && i <= el.length && el[i - 1].airdate.isNotEmpty)
                                              ? '1 ч 05 мин · ${fmtDate(el[i - 1].airdate)}'
                                              : '1 ч 05 мин',
                                          style: const TextStyle(
                                            color: Color(0xFFA99FB8),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else if (_tabIdx == 1) ...[
                        if (sim.isEmpty)
                          const Text('Похожие дорамы скоро появятся.', style: TextStyle(color: C.tx2))
                        else
                          PosterRail(sim),
                      ] else if (_tabIdx == 2) ...[
                        if (cs.isEmpty)
                          const Text('Список актёров загружается…', style: TextStyle(color: C.tx2))
                        else
                          SizedBox(
                            height: 158,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: cs.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => _actorTile(cs[i]),
                            ),
                          ),
                      ] else ...[
                        const SectionTitle('Озвучка'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
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
                                    color: activeDub == studio ? Colors.white : C.s1,
                                    border: Border.all(color: activeDub == studio ? Colors.white : C.line),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    studio,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: activeDub == studio ? Colors.black : C.tx2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SectionTitle('Ваша оценка'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 1; i <= 10; i++)
                              GestureDetector(
                                onTap: () => store.setRate(d, r == i ? null : i),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: r == i ? Colors.white : C.s1,
                                    border: Border.all(color: r == i ? Colors.white : C.line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$i',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: r == i ? Colors.black : C.tx2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SectionTitle('Личные заметки'),
                        TextField(
                          controller: noteCtl,
                          minLines: 2,
                          maxLines: 5,
                          onChanged: (v) => store.setNote(d, v),
                          style: const TextStyle(color: C.tx),
                          decoration: InputDecoration(
                            hintText: 'Что понравилось, на чём остановились…',
                            hintStyle: const TextStyle(color: C.tx2),
                            filled: true,
                            fillColor: C.s1,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: C.line),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _actorTile(Actor a) {
    final ph = Container(color: C.s2, child: const Icon(Icons.person_rounded, color: C.tx2));
    final fav = store.isFavActor(a.name);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActorPage(actor: a))),
      child: SizedBox(
        width: 86,
        child: Column(children: [
          Stack(children: [
            ClipOval(
              child: SizedBox(
                width: 72,
                height: 72,
                child: a.photo.isEmpty ? ph : CachedPic(a.photo, placeholder: ph, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => store.toggleFavActor(a.name),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: fav ? C.pk : C.s2,
                    shape: BoxShape.circle,
                    border: Border.all(color: C.bg, width: 1.5),
                  ),
                  child: Icon(
                    fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 12,
                    color: fav ? C.onPk : C.tx2,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            store.ruActor(a.name),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.15),
          ),
          if (a.role.isNotEmpty)
            Text(
              a.role,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: C.tx2),
            ),
        ]),
      ),
    );
  }
}

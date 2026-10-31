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
                  leading: Icon(it.$3, color: st == it.$1 ? C.gd : C.tx2),
                  title: Text(
                    it.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: st == it.$1 ? C.gd : C.tx,
                    ),
                  ),
                  trailing: st == it.$1 ? const Icon(Icons.check_rounded, color: C.gd) : null,
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
  bool allEps = false;
  late final TextEditingController nameCtl;
  late final TextEditingController noteCtl;
  late final TextEditingController dubCtl;
  late final List<Drama> sim;

  Map<String, List<Map<String, dynamic>>> _allStreams = {};
  bool _streamsLoaded = false;

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
    _loadStreams();
  }

  Future<void> _loadStreams() async {
    _allStreams = await StreamsLoader.load();
    if (mounted) setState(() => _streamsLoaded = true);
    final remote = await StreamsLoader.syncRemote();
    if (remote.isNotEmpty && mounted) {
      setState(() => _allStreams = remote);
    }
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

  // Точный номер серии для просмотра: никогда не превышает total (не покажет 11 при 10 сериях)
  int get _watchEpNum {
    final maxEp = total > 0 ? total : (aired > 0 ? aired : 16);
    final watched = store.prog[d.id] ?? 0;
    final st = store.listOf[d.id];
    if (watched <= 0 || st == 'done' || watched >= maxEp) {
      if (d.status == 'Running' && aired > 0 && watched == 0) {
        return aired.clamp(1, maxEp);
      }
      return 1;
    }
    return (watched + 1).clamp(1, maxEp);
  }

  String get _watchBtnLabel {
    final maxEp = total > 0 ? total : (aired > 0 ? aired : 16);
    final watched = store.prog[d.id] ?? 0;
    final st = store.listOf[d.id];
    if (st == 'done' || watched >= maxEp || (watched == 0 && d.status != 'Running')) {
      return 'Смотреть с 1 серии';
    }
    return 'Смотреть $_watchEpNum серию';
  }

  String _next() {
    final l = eps;
    if (l == null) return '';
    final t = todayIso();
    for (var i = 0; i < l.length; i++) {
      final e = l[i];
      if (e.airdate.isNotEmpty && e.airdate.compareTo(t) > 0) {
        final tm = e.time.isNotEmpty ? ', ${e.time}' : '';
        return 'Следующая серия №${i + 1}: ${fmtDate(e.airdate)}$tm';
      }
    }
    return '';
  }

  void _openPlayer({int? episode, String? dub}) {
    final title = store.ruTitle(d);
    final effDub = dub ?? store.dubOf[d.id];
    final availableUrls = _streamsLoaded
        ? StreamsLoader.getUrlsForDramaAndDub(d.id, effDub, _allStreams, enTitle: d.en, ruTitle: title)
        : <String>[];
    final availableStreams = _streamsLoaded
        ? StreamsLoader.getEntriesForDrama(d, effDub, _allStreams, ruTitle: title)
        : <Map<String, dynamic>>[];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          drama: d,
          urls: availableUrls,
          streams: availableStreams,
          initialEpisode: episode ?? _watchEpNum,
          activeDub: effDub,
        ),
      ),
    );
  }

  Widget _watchPlatformsSection(String title, String? activeDub) {
    final epToWatch = _watchEpNum;
    final availableUrls = _streamsLoaded
        ? StreamsLoader.getUrlsForDramaAndDub(
            d.id,
            activeDub,
            _allStreams,
            enTitle: d.en,
            ruTitle: title,
          )
        : <String>[];
    final availableStreams = _streamsLoaded
        ? StreamsLoader.getEntriesForDrama(d, activeDub, _allStreams, ruTitle: title)
        : <Map<String, dynamic>>[];
    final dramaDubs = _streamsLoaded
        ? StreamsLoader.getAvailableDubsForDrama(d, _allStreams, ruTitle: title)
        : kDubStudios.take(4).toList();

    final dubLabel = (activeDub != null && activeDub.isNotEmpty)
        ? activeDub
        : (dramaDubs.isNotEmpty ? dramaDubs.first : 'SoftBox');

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Смотреть онлайн'),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.s1,
          border: Border.all(color: const Color(0xFFE59A43), width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE59A43), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Встроенный плеер · Озвучка: $dubLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: C.tx),
              ),
            ),
          ]),
          if (dramaDubs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Доступные озвучки: ${dramaDubs.take(5).join(" · ")}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.tx2, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerPage(
                      drama: d,
                      urls: availableUrls,
                      streams: availableStreams,
                      initialEpisode: epToWatch,
                      activeDub: activeDub ?? dubLabel,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: Text(
                _watchBtnLabel,
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
        ]),
      ),
    ]);
  }

  Widget _dubPickerSection(String? activeDub) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Озвучка'),
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
                color: activeDub == studio ? const Color(0xFFE59A43) : C.s1,
                border: Border.all(color: activeDub == studio ? const Color(0xFFE59A43) : C.line),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                studio,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: activeDub == studio ? C.bg : C.tx2,
                ),
              ),
            ),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, elevation: 0, foregroundColor: C.tx),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final st = store.listOf[d.id];
          final r = store.rate[d.id];
          final activeDub = store.dubOf[d.id];
          final title = store.ruTitle(d);
          final next = _next();
          final sum = store.sumRu[d.id];
          final soon = d.date.isNotEmpty && d.date.compareTo(todayIso()) > 0;
          final cs = cast;
          final el = eps;
          final badgeStatus = d.status == 'Running'
              ? 'НОВАЯ СЕРИЯ СЕГОДНЯ'
              : (soon ? 'СКОРО ВЫХОДИТ' : 'МОЖНО СМОТРЕТЬ ЗАЛПОМ');
          final epCountTxt = total > 0
              ? (aired > 0 && aired < total ? '$aired из $total серий' : '$total серий')
              : '16 серий';
          final gTxt = d.genres.isNotEmpty ? d.genres.take(2).map(ruGenre).join(', ') : 'Драма';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // Заголовок карточки в стиле DoramaOn
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFFE59A43), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  badgeStatus,
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
                    'ЮЖНАЯ КОРЕЯ${d.network.isNotEmpty ? " · ${d.network.toUpperCase()}" : ""}',
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
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(width: 116, height: 172, child: Poster(d)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.12),
                    ),
                    if (title != d.en) ...[
                      const SizedBox(height: 4),
                      Text(d.en, style: const TextStyle(color: C.tx2, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFE59A43), size: 17),
                        Text(
                          (d.rating ?? 8.5).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFE59A43),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                        const Text(' / ', style: TextStyle(color: C.tx2)),
                        if (d.year != null) ...[
                          Text('${d.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          const Text(' / ', style: TextStyle(color: C.tx2)),
                        ],
                        Text(epCountTxt, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/  $gTxt  /  15+',
                      style: const TextStyle(color: C.tx2, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    if (soon) ...[
                      const SizedBox(height: 6),
                      Text('Выход: ${fmtDate(d.date)}',
                          style: const TextStyle(color: C.gd, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                    if (activeDub != null && activeDub.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DubBadge(activeDub),
                    ],
                  ]),
                ),
              ]),

              EpisodeCountdownBadge(d, banner: true),
              if (next.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(next, style: const TextStyle(color: C.jd, fontWeight: FontWeight.w700)),
              ],

              // Кнопки «Смотреть» и «+ В список»
              _watchPlatformsSection(title, activeDub),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _listBtn('Смотрю', Icons.visibility_rounded, st == 'watch', 'watch')),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('В планах', Icons.bookmark_rounded, st == 'plan', 'plan')),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('Готово', Icons.check_circle_rounded, st == 'done', 'done')),
                const SizedBox(width: 8),
                Expanded(child: _listBtn('Брошено', Icons.block_rounded, st == 'drop', 'drop')),
              ]),
              if (st == 'watch') ...[
                const SizedBox(height: 12),
                _progressBox(),
              ],
              _dubPickerSection(activeDub),
              ..._extraBlocks(),

              const SectionTitle('Описание'),
              if (sum != null)
                Text(sum, style: const TextStyle(height: 1.45, fontSize: 14))
              else if (sumBusy || !loaded)
                const Row(children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                  SizedBox(width: 10),
                  Text('Переводим описание…', style: TextStyle(color: C.tx2)),
                ])
              else
                Text(
                  d.id < 0 ? 'Описание появится ближе к выходу.' : 'Описание недоступно.',
                  style: const TextStyle(color: C.tx2),
                ),

              if ((cs != null && cs.isNotEmpty) || store.richCastOf(d).isNotEmpty) ...[
                const SectionTitle('Актёры'),
                SizedBox(
                  height: 158,
                  child: Builder(builder: (_) {
                    final eff = (cs != null && cs.isNotEmpty) ? cs : store.richCastOf(d);
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: eff.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _actorTile(eff[i]),
                    );
                  }),
                ),
              ],

              if (el != null && el.isNotEmpty) ...[
                const SectionTitle('Серии и даты выхода'),
                _epList(el),
              ],

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
                      child: Text('$i', style: TextStyle(fontWeight: FontWeight.w800, color: r == i ? C.bg : C.tx2)),
                    ),
                  ),
              ]),

              if (sim.isNotEmpty) ...[
                const SectionTitle('Похожие дорамы'),
                PosterRail(sim),
              ],

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
          );
        },
      ),
    );
  }

  List<Widget> _extraBlocks() {
    final out = <Widget>[];
    final tl = Taste.tropeLabels(d);
    if (tl.isNotEmpty) {
      out.add(const SizedBox(height: 12));
      out.add(Wrap(spacing: 8, runSpacing: 8, children: [
        for (final tp in tl)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.jd), borderRadius: BorderRadius.circular(100)),
            child: Text(tp, style: const TextStyle(fontSize: 12, color: C.jd, fontWeight: FontWeight.w700)),
          ),
      ]));
    }
    final m = store.rate[d.id] == null ? Taste.match(d) : null;
    if (m != null) {
      out.add(const SizedBox(height: 12));
      out.add(MatchCard(d, m));
    }
    out.add(const SizedBox(height: 12));
    out.add(extraBtn('Сравнить с другими', Icons.compare_arrows_rounded, () => openCompare(context, first: d)));
    return out;
  }

  Widget _progressBox() {
    final t = total;
    final p = t > 0 ? (store.prog[d.id] ?? 0).clamp(0, t) : (store.prog[d.id] ?? 0);
    final dub = store.dubOf[d.id];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t > 0 ? 'Просмотрено: $p из $t' : 'Просмотрено серий: $p',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              if (dub != null && dub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Озвучка: $dub', style: const TextStyle(color: C.tx2, fontSize: 12)),
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
              minHeight: 8,
              color: C.jd,
              backgroundColor: C.s2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => store.finishWatching(d),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Досмотрел(а) до конца'),
              style: FilledButton.styleFrom(
                backgroundColor: C.jd,
                foregroundColor: C.onPk,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ]),
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

  Widget _epList(List<Ep> l) {
    final t = todayIso();
    final p = store.prog[d.id] ?? 0;
    final multi = l.map((e) => e.season).toSet().length > 1;
    final show = allEps ? l.length : (l.length > 6 ? 6 : l.length);
    return Container(
      decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (var i = 0; i < show; i++) _epRow(i, l[i], t, p, multi),
        if (l.length > 6)
          TextButton(
            onPressed: () => setState(() => allEps = !allEps),
            child: Text(
              allEps ? 'Свернуть' : 'Показать все (${l.length})',
              style: const TextStyle(color: C.pk, fontWeight: FontWeight.w700),
            ),
          ),
      ]),
    );
  }

  Widget _epRow(int i, Ep e, String today, int p, bool multi) {
    final out = e.airdate.isNotEmpty && e.airdate.compareTo(today) <= 0;
    final seen = i < p;
    final label = multi ? 'С${e.season} · серия ${e.number}' : 'Серия ${i + 1}';
    return InkWell(
      onTap: () => _openPlayer(episode: i + 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(
            seen ? Icons.check_circle_rounded : (out ? Icons.play_circle_outline_rounded : Icons.schedule_rounded),
            size: 19,
            color: seen ? C.jd : (out ? const Color(0xFFE59A43) : C.gd),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text(
            e.airdate.isEmpty ? 'Смотреть' : fmtDate(e.airdate),
            style: TextStyle(color: out ? C.tx2 : C.gd, fontSize: 12),
          ),
        ]),
      ),
    );
  }

  Widget _listBtn(String t, IconData i, bool on, String key) {
    return GestureDetector(
      onTap: () => store.setList(d, on ? null : key),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: on ? C.pk : C.s1,
          border: Border.all(color: on ? C.pk : C.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(i, color: on ? C.onPk : C.tx2),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? C.onPk : C.tx2)),
          ),
        ]),
      ),
    );
  }
}

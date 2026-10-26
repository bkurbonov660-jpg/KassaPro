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
      final ph = await store.ensureActorPhoto(a.name);
      const int? pid = null;
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

  int get total => store.totals[d.id] ?? (eps?.length ?? 0);

  int get aired {
    final l = eps;
    if (l == null) return 0;
    final t = todayIso();
    return l.where((e) => e.airdate.isNotEmpty && e.airdate.compareTo(t) <= 0).length;
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

  Widget _trailerSection(String title) {
    final qOfficial = Uri.encodeComponent('${d.en} ${d.year ?? ""} official trailer korean drama'.trim());
    final qRu = Uri.encodeComponent('$title дорама русский трейлер тизер'.trim());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openExternal('https://www.youtube.com/results?search_query=$qOfficial', 'YouTube'),
            icon: const Icon(Icons.play_arrow_rounded, size: 18, color: C.pk),
            label: const Text('Смотреть трейлер', style: TextStyle(color: C.tx, fontWeight: FontWeight.w700, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              side: const BorderSide(color: C.line),
              backgroundColor: C.s1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _openExternal('https://www.youtube.com/results?search_query=$qRu', 'YouTube'),
          icon: const Icon(Icons.ondemand_video_rounded, size: 16, color: C.tx2),
          label: const Text('Тизер RU', style: TextStyle(color: C.tx2, fontWeight: FontWeight.w700, fontSize: 12.5)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            side: const BorderSide(color: C.line),
            backgroundColor: C.s1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ]),
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
      ('Кинопоиск', Icons.movie_outlined, 'https://www.kinopoisk.ru/index.php?kp_query=$qKp'),
      ('Иви', Icons.tv_rounded, 'https://www.ivi.ru/search/?q=$qIvi'),
      ('SoftBox', Icons.mic_none_rounded, 'https://vkvideo.ru/?q=$qSoftBox'),
      ('DubLik', Icons.record_voice_over_outlined, 'https://vkvideo.ru/?q=$qDubLik'),
      ('Kodik', Icons.ondemand_video_rounded, 'https://yandex.ru/video/search?text=$qKodik'),
      ('FSG Мания', Icons.subtitles_outlined, 'https://vkvideo.ru/?q=$qMania'),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Где смотреть'),
      if (activeDub != null && activeDub.isNotEmpty) ...[
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openExternal(
              'https://vkvideo.ru/?q=${Uri.encodeComponent("$title $activeDub серия $nextEpNum")}',
              'VK Видео ($activeDub)',
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('Смотреть $nextEpNum-ю серию ($activeDub)',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: C.pk,
              foregroundColor: C.onPk,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
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
                Icon(p.$2, size: 15, color: C.tx2),
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
                color: activeDub == studio ? C.tx : C.s1,
                border: Border.all(color: activeDub == studio ? C.tx : C.line),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                studio,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: activeDub == studio ? C.bg : C.tx2,
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
              hintText: 'Своя студия озвучки или субтитров',
              hintStyle: const TextStyle(color: C.tx2, fontSize: 12.5),
              suffixIcon: (activeDub != null && activeDub.isNotEmpty)
                  ? IconButton(
                      onPressed: () {
                        dubCtl.clear();
                        store.setDub(d, null);
                      },
                      icon: const Icon(Icons.clear_rounded, color: C.tx2, size: 18),
                    )
                  : null,
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
          child: const Text('ОК', style: TextStyle(fontWeight: FontWeight.w700)),
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
          final meta = <String>[
            if (d.year != null) '${d.year}',
            'Корея',
            if (d.status.isNotEmpty) ruStatus(d.status),
            if (d.rating != null) 'TVmaze ${d.rating!.toStringAsFixed(1)}',
          ].where((e) => e.isNotEmpty).join(' · ');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: SizedBox(width: 120, height: 180, child: Poster(d))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, height: 1.15)),
                    const SizedBox(height: 6),
                    if (title != d.en) Text(d.en, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(meta, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    if (d.network.isNotEmpty) Text(d.network, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    if (soon) Text('Выход: ${fmtDate(d.date)}', style: const TextStyle(color: C.gd, fontWeight: FontWeight.w800)),
                    if (total > 0)
                      Text(el != null ? 'Серий: $total · вышло: $aired' : 'Серий: $total',
                          style: const TextStyle(color: C.tx2, fontSize: 13)),
                    if (activeDub != null && activeDub.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      DubBadge(activeDub),
                    ],
                  ]),
                ),
              ]),
              _trailerSection(title),
              EpisodeCountdownBadge(d, banner: true),
              if (d.genres.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in d.genres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: C.s2, borderRadius: BorderRadius.circular(100)),
                      child: Text(ruGenre(g), style: const TextStyle(fontSize: 12, color: C.tx2)),
                    ),
                ]),
              ],
              if (next.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(next, style: const TextStyle(color: C.jd, fontWeight: FontWeight.w700)),
              ],
              ..._extraBlocks(),
              const SizedBox(height: 18),
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
              _watchPlatformsSection(title, activeDub),
              _dubPickerSection(activeDub),
              const SectionTitle('Ваша оценка'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 1; i <= 10; i++)
                  GestureDetector(
                    onTap: () => store.setRate(d, r == i ? null : i),
                    child: Container(
                      width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: r == i ? C.gd : C.s1,
                        border: Border.all(color: r == i ? C.gd : C.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$i', style: TextStyle(fontWeight: FontWeight.w800, color: r == i ? C.bg : C.tx2)),
                    ),
                  ),
              ]),
              const SectionTitle('Описание'),
              if (sum != null) Text(sum, style: const TextStyle(height: 1.45, fontSize: 14))
              else if (sumBusy || !loaded)
                const Row(children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)),
                  SizedBox(width: 10),
                  Text('Переводим описание…', style: TextStyle(color: C.tx2)),
                ])
              else Text(d.id < 0 ? 'Описание появится ближе к выходу.' : 'Описание недоступно.',
                  style: const TextStyle(color: C.tx2)),
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
              if (sim.isNotEmpty) ...[
                const SectionTitle('Похожие дорамы'),
                PosterRail(sim),
              ],
              const SectionTitle('Личные заметки'),
              TextField(
                controller: noteCtl, minLines: 2, maxLines: 5,
                onChanged: (v) => store.setNote(d, v),
                style: const TextStyle(color: C.tx),
                decoration: InputDecoration(
                  hintText: 'Что понравилось, на чём остановились…',
                  hintStyle: const TextStyle(color: C.tx2),
                  filled: true, fillColor: C.s1,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
                ),
              ),
              const SectionTitle('Название по-русски'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: nameCtl,
                    style: const TextStyle(color: C.tx),
                    decoration: InputDecoration(
                      hintText: title, hintStyle: const TextStyle(color: C.tx2),
                      filled: true, fillColor: C.s1,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () { store.setCustom(d, nameCtl.text); FocusScope.of(context).unfocus(); },
                  style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18)),
                  child: const Text('Сохранить'),
                ),
              ]),
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
      out.add(const SizedBox(height: 10));
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
    final p = store.prog[d.id] ?? 0;
    final t = total;
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
            icon: const Icon(Icons.remove_circle_outline_rounded)),
          IconButton(
            onPressed: (t == 0 || p < t) ? () => store.setProg(d, p + 1) : null,
            icon: const Icon(Icons.add_circle_rounded, color: C.pk)),
        ]),
        if (t > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (p / t).clamp(0.0, 1.0).toDouble(),
              minHeight: 8, color: C.jd, backgroundColor: C.s2),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => store.finishWatching(d),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Досмотрел(а) до конца'),
              style: FilledButton.styleFrom(backgroundColor: C.jd, foregroundColor: C.onPk,
                padding: const EdgeInsets.symmetric(vertical: 12)),
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
                width: 72, height: 72,
                child: a.photo.isEmpty ? ph
                  : Image.network(a.photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ph),
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
          Text(store.ruActor(a.name), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.15)),
          if (a.role.isNotEmpty)
            Text(a.role, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: C.tx2)),
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
            child: Text(allEps ? 'Свернуть' : 'Показать все (${l.length})',
                style: const TextStyle(color: C.pk, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _epRow(int i, Ep e, String today, int p, bool multi) {
    final out = e.airdate.isNotEmpty && e.airdate.compareTo(today) <= 0;
    final seen = i < p;
    final label = multi ? 'С${e.season} · серия ${e.number}' : 'Серия ${i + 1}';
    final watching = store.listOf[d.id] == 'watch';
    return InkWell(
      onTap: watching ? () => store.setProg(d, (seen && i + 1 == p) ? i : i + 1) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(seen ? Icons.check_circle_rounded : (out ? Icons.circle_outlined : Icons.schedule_rounded),
              size: 18, color: seen ? C.jd : (out ? C.tx2 : C.gd)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text(e.airdate.isEmpty ? 'дата не объявлена' : fmtDate(e.airdate),
              style: TextStyle(color: out ? C.tx2 : C.gd, fontSize: 12)),
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
          FittedBox(fit: BoxFit.scaleDown,
            child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? C.onPk : C.tx2))),
        ]),
      ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'actor_page.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'taste.dart';
import 'ui_common.dart';
import 'widgets.dart';

class CatalogPage extends StatefulWidget {
  final int initialMode;
  const CatalogPage({this.initialMode = 0, super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _q = TextEditingController();
  int mode = 0; // 0: Дорамы, 1: Актёры
  String? year;
  String? genre;
  String sort = 'new';
  Timer? _deb;
  List<Drama>? online;
  List<Actor>? onlineActors;
  bool onlineBusy = false;
  Trope? trope;
  List<Drama> descHits = <Drama>[];

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
  }

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQ(String v) {
    _deb?.cancel();
    setState(() {
      online = null;
      onlineActors = null;
      onlineBusy = false;
      descHits = Taste.searchAll(v);
    });
    final q = v.trim();
    final cyr = RegExp(r'[а-яёА-ЯЁ]').hasMatch(q);
    if (q.length < (cyr ? 2 : 3)) return;
    _deb = Timer(const Duration(milliseconds: 550), () => _searchOnline(q));
  }

  Future<void> _searchOnline(String q) async {
    if (!mounted) return;
    setState(() => onlineBusy = true);
    if (mode == 1) {
      final actors = await store.searchActorsOnline(q);
      if (!mounted || _q.text.trim() != q) return;
      setState(() {
        onlineActors = actors;
        onlineBusy = false;
      });
    } else {
      final results = await Future.wait([
        store.searchOnline(q),
        store.searchActorsOnline(q),
      ]);
      if (!mounted || _q.text.trim() != q) return;
      setState(() {
        online = results[0] as List<Drama>;
        onlineActors = results[1] as List<Actor>;
        onlineBusy = false;
      });
    }
  }

  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.s1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => mode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode == 0 ? C.pk : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.movie_filter_rounded, size: 16, color: mode == 0 ? C.onPk : C.tx2),
                    const SizedBox(width: 6),
                    Text(
                      'Дорамы',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: mode == 0 ? C.onPk : C.tx2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => mode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode == 1 ? C.pk : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded, size: 16, color: mode == 1 ? C.onPk : C.tx2),
                    const SizedBox(width: 6),
                    Text(
                      'Найти актёра',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: mode == 1 ? C.onPk : C.tx2,
                      ),
                    ),
                  ],
                ),
              ),
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
        final queryText = _q.text.trim();
        final matchedActors = onlineActors ?? store.allKnownActors(q: queryText);

        if (mode == 1) {
          return SafeArea(
            child: LayoutBuilder(builder: (context, cons) {
              final w = cons.maxWidth - 32;
              final cols = math.max(2, (w / 155).floor());
              const gap = 14.0;
              final cw = (w - gap * (cols - 1)) / cols;
              final ch = cw * (4 / 3) + 54;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Каталог и Актёры',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          _modeSwitch(),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _q,
                            onChanged: _onQ,
                            style: const TextStyle(color: C.tx),
                            decoration: InputDecoration(
                              hintText: 'Имя актёра (напр. Константин Романенко, Го Юн Чжон)…',
                              hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                              prefixIcon: const Icon(Icons.person_search_rounded, color: C.pk),
                              suffixIcon: onlineBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: C.pk),
                                      ),
                                    )
                                  : (_q.text.isNotEmpty
                                      ? IconButton(
                                          onPressed: () {
                                            _q.clear();
                                            _onQ('');
                                          },
                                          icon: const Icon(Icons.close_rounded, color: C.tx2, size: 18),
                                        )
                                      : null),
                              filled: true,
                              fillColor: C.s1,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100),
                                borderSide: const BorderSide(color: C.line),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(100),
                                borderSide: const BorderSide(color: C.pk),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Актёров найдено: ${matchedActors.length} · Нажмите на карточку для биографии и всех дорам',
                            style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (matchedActors.isEmpty)
                    const SliverToBoxAdapter(
                      child: EmptyBox(
                        Icons.person_off_rounded,
                        'Актёр не найден',
                        'Попробуйте ввести имя по-русски или по-английски, например «Константин Романенко» или «Go Youn-jung».',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (c, i) => ActorGridCard(matchedActors[i], key: ValueKey(matchedActors[i].name)),
                          childCount: matchedActors.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: gap,
                          childAspectRatio: cw / ch,
                        ),
                      ),
                    ),
                ],
              );
            }),
          );
        }

        // Режим 0: Каталог дорам (с горизонтальным блоком найденных актёров при вводе запроса)
        final tq = trope == null ? Taste.tropeForQuery(_q.text) : null;
        var list = store.browse(year: year, genre: genre, sort: sort, q: tq != null ? '' : _q.text);
        final tsel = trope ?? tq;
        if (tsel != null) {
          final Trope t2 = tsel;
          list = list.where((d) => Taste.hasTrope(d, t2)).toList();
        } else if (descHits.isNotEmpty) {
          final have0 = list.map((e) => e.id).toSet();
          list = [...list, ...descHits.where((d) => !have0.contains(d.id))];
        }
        if (online != null) {
          final have = list.map((e) => e.id).toSet();
          list = [...list, ...online!.where((d) => !have.contains(d.id))];
        }
        // Если запрос совпал с именем актёра, также добавляем все его дорамы в выдачу
        if (queryText.length >= 2 && matchedActors.isNotEmpty) {
          final have = list.map((e) => e.id).toSet();
          for (final a in matchedActors.take(3)) {
            for (final d in store.dramasForActorKey(a.name)) {
              if (have.add(d.id)) list.add(d);
            }
          }
        }
        final genres = store.genreSet().toList()..sort();

        return SafeArea(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 165).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 78;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Каталог и Актёры',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _modeSwitch(),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _q,
                      onChanged: _onQ,
                      style: const TextStyle(color: C.tx),
                      decoration: InputDecoration(
                        hintText: 'Реальное название дорамы, актёр или сюжет…',
                        hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.pk),
                        suffixIcon: onlineBusy
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: C.pk),
                                ),
                              )
                            : (_q.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _q.clear();
                                      _onQ('');
                                    },
                                    icon: const Icon(Icons.close_rounded, color: C.tx2, size: 18),
                                  )
                                : null),
                        filled: true,
                        fillColor: C.s1,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: C.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: C.pk),
                        ),
                      ),
                    ),
                    // Если при поиске дорамы нашлись актёры — сразу показываем их сверху!
                    if (queryText.length >= 2 && matchedActors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: matchedActors.take(8).length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final a = matchedActors[i];
                            final ph = store.actorPhotoOf(a.name, a.photo);
                            return GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => ActorPage(actor: a)),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: C.s1,
                                  border: Border.all(color: C.pk.withOpacity(0.55)),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 40,
                                        height: 48,
                                        child: ph.isEmpty
                                            ? Container(color: C.s2, child: const Icon(Icons.person_rounded, size: 20, color: C.tx2))
                                            : CachedPic(ph,
                                                placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, size: 20, color: C.tx2))),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(store.ruActor(a.name),
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: C.tx)),
                                        const Text('Открыть карточку актёра →',
                                            style: TextStyle(color: C.pk, fontSize: 11, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ChipRow([
                      FilterPill('Все годы', year == null, () => setState(() => year = null)),
                      FilterPill('Скоро', year == 'soon', () => setState(() => year = 'soon')),
                      FilterPill('Выходят', year == 'running', () => setState(() => year = 'running')),
                      for (var y = DateTime.now().year + 1; y >= 2022; y--)
                        FilterPill('$y', year == '$y', () => setState(() => year = '$y')),
                      FilterPill('До ${Cfg.minYear}', year == 'old', () => setState(() => year = 'old')),
                    ]),
                    const SizedBox(height: 8),
                    ChipRow([
                      FilterPill('Новые', sort == 'new', () => setState(() => sort = 'new')),
                      FilterPill('Лучшие', sort == 'top', () => setState(() => sort = 'top')),
                      FilterPill('А–Я', sort == 'az', () => setState(() => sort = 'az')),
                    ]),
                    const SizedBox(height: 8),
                    ChipRow([
                      FilterPill('Все жанры', genre == null, () => setState(() => genre = null)),
                      for (final g in genres) FilterPill(ruGenre(g), genre == g, () => setState(() => genre = g)),
                    ]),
                    const SizedBox(height: 8),
                    ChipRow([
                      FilterPill('Все темы', trope == null, () => setState(() => trope = null)),
                      for (final t in kTropes)
                        FilterPill(t.label, trope == t, () => setState(() => trope = trope == t ? null : t)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Всего в базе: ${fmtNum(store.krCount)} · найдено: ${fmtNum(list.length)}',
                      style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
              ),
              if (list.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyBox(
                    Icons.tv_off_rounded,
                    store.scanning ? 'Каталог ещё грузится' : 'Ничего не нашли',
                    'Введите народное название по-русски, имя актёра (например, «Константин Романенко») или оригинальное название.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => DramaCard(list[i], key: ValueKey(list[i].id)),
                      childCount: list.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: gap,
                      childAspectRatio: cw / ch,
                    ),
                  ),
                ),
            ]);
          }),
        );
      },
    );
  }
}

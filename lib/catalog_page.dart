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
  final TextEditingController _q = TextEditingController();
  int mode = 0; // 0: Дорамы, 1: Актёры
  String _activeQuery = '';
  String? year;
  String? genre;
  String sort = 'new';
  Timer? _filterDeb;
  Timer? _netDeb;
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
    _filterDeb?.cancel();
    _netDeb?.cancel();
    _q.dispose();
    super.dispose();
  }

  // Мгновенный отклик клавиатуры без тормозов: фильтрация списка запускается через короткий debounce (120 мс),
  // поэтому ввод букв в поле поиска работает идеально плавно (60 FPS).
  void _onQ(String v) {
    _filterDeb?.cancel();
    _netDeb?.cancel();
    final trimmed = v.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _activeQuery = '';
        online = null;
        onlineActors = null;
        onlineBusy = false;
        descHits = const <Drama>[];
      });
      return;
    }
    _filterDeb = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _activeQuery = trimmed;
        online = null;
        onlineActors = null;
      });
    });
    final cyr = RegExp(r'[а-яёА-ЯЁ]').hasMatch(trimmed);
    if (trimmed.length < (cyr ? 2 : 3)) return;
    _netDeb = Timer(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      final hits = Taste.searchAll(trimmed);
      setState(() {
        descHits = hits;
      });
      _searchOnline(trimmed);
    });
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
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: C.s1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => mode = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode == 0 ? C.tx : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Дорамы',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: mode == 0 ? C.bg : C.tx2,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => mode = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: mode == 1 ? C.tx : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Актёры',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: mode == 1 ? C.bg : C.tx2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField({required String hint}) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _q,
      builder: (context, val, _) {
        final hasText = val.text.isNotEmpty;
        return TextField(
          controller: _q,
          onChanged: _onQ,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _filterDeb?.cancel();
            setState(() => _activeQuery = v.trim());
          },
          style: const TextStyle(color: C.tx, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: C.tx2, size: 20),
            suffixIcon: onlineBusy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: C.tx),
                    ),
                  )
                : (hasText
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
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.tx, width: 1.2),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final queryText = _activeQuery;
        final matchedActors = (mode == 1 || queryText.length >= 2)
            ? (onlineActors ?? store.allKnownActors(q: queryText))
            : const <Actor>[];

        if (mode == 1) {
          return SafeArea(
            child: LayoutBuilder(builder: (context, cons) {
              final w = cons.maxWidth - 32;
              final cols = math.max(2, (w / 155).floor());
              const gap = 14.0;
              final cw = (w - gap * (cols - 1)) / cols;
              final ch = cw * (4 / 3) + 54;
              return CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Каталог',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                          const SizedBox(height: 10),
                          _modeSwitch(),
                          const SizedBox(height: 10),
                          _searchField(hint: 'Имя актёра (напр. Константин Романенко, Го Юн Чжон)…'),
                          const SizedBox(height: 10),
                          Text(
                            'Актёров: ${matchedActors.length}',
                            style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w600),
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
                        'Попробуйте ввести имя по-русски или по-английски.',
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

        // Режим 0: Каталог дорам
        final tq = trope == null && queryText.length >= 4 ? Taste.tropeForQuery(queryText) : null;
        var list = store.browse(year: year, genre: genre, sort: sort, q: tq != null ? '' : queryText);
        final tsel = trope ?? tq;
        if (tsel != null) {
          final Trope t2 = tsel;
          list = list.where((d) => Taste.hasTrope(d, t2)).toList();
        } else if (queryText.length >= 2 && descHits.isNotEmpty) {
          final have0 = list.map((e) => e.id).toSet();
          list = [...list, ...descHits.where((d) => !have0.contains(d.id))];
        }
        if (online != null && queryText.isNotEmpty) {
          final have = list.map((e) => e.id).toSet();
          list = [...list, ...online!.where((d) => !have.contains(d.id))];
        }
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
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Каталог',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                      const SizedBox(height: 10),
                      _modeSwitch(),
                      const SizedBox(height: 10),
                      _searchField(hint: 'Название дорамы, актёр или сюжет…'),
                      if (queryText.length >= 2 && matchedActors.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 58,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: matchedActors.take(8).length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                    border: Border.all(color: C.line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 36,
                                          height: 44,
                                          child: ph.isEmpty
                                              ? Container(color: C.s2, child: const Icon(Icons.person_rounded, size: 18, color: C.tx2))
                                              : CachedPic(ph,
                                                  placeholder: Container(color: C.s2, child: const Icon(Icons.person_rounded, size: 18, color: C.tx2))),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(store.ruActor(a.name),
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: C.tx)),
                                          const Text('Актёр →',
                                              style: TextStyle(color: C.tx2, fontSize: 11, fontWeight: FontWeight.w600)),
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
                      const SizedBox(height: 10),
                      ChipRow([
                        FilterPill('Все годы', year == null, () => setState(() => year = null)),
                        FilterPill('Выходят', year == 'running', () => setState(() => year = 'running')),
                        FilterPill('Скоро', year == 'soon', () => setState(() => year = 'soon')),
                        for (var y = DateTime.now().year; y >= 2022; y--)
                          FilterPill('$y', year == '$y', () => setState(() => year = '$y')),
                        FilterPill('До ${Cfg.minYear}', year == 'old', () => setState(() => year = 'old')),
                      ]),
                      const SizedBox(height: 8),
                      ChipRow([
                        FilterPill('Новые', sort == 'new', () => setState(() => sort = 'new')),
                        FilterPill('Лучшие', sort == 'top', () => setState(() => sort = 'top')),
                        FilterPill('А–Я', sort == 'az', () => setState(() => sort = 'az')),
                        const SizedBox(width: 4),
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
                        'Найдено: ${fmtNum(list.length)} из ${fmtNum(store.krCount)}',
                        style: const TextStyle(color: C.tx2, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ),
                if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyBox(
                      Icons.tv_off_rounded,
                      store.scanning ? 'Каталог ещё грузится' : 'Ничего не нашли',
                      'Введите русское название дорамы, имя актёра или оригинальное название.',
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
              ],
            );
          }),
        );
      },
    );
  }
}

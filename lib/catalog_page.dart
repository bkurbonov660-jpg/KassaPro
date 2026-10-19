import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'taste.dart';
import 'ui_common.dart';
import 'widgets.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _q = TextEditingController();
  String? year; String? genre; String sort = 'new';
  Timer? _deb;
  List<Drama>? online;
  bool onlineBusy = false;
  Trope? trope;
  List<Drama> descHits = <Drama>[];

  @override
  void dispose() { _deb?.cancel(); _q.dispose(); super.dispose(); }

  void _onQ(String v) {
    _deb?.cancel();
    setState(() { online = null; onlineBusy = false; descHits = Taste.searchDesc(v); });
    final q = v.trim();
    final cyr = RegExp(r'[а-яёА-ЯЁ]').hasMatch(q);
    if (q.length < (cyr ? 2 : 3)) return;
    _deb = Timer(const Duration(milliseconds: 700), () => _searchOnline(q));
  }

  Future<void> _searchOnline(String q) async {
    if (!mounted) return;
    setState(() => onlineBusy = true);
    final r = await store.searchOnline(q);
    if (!mounted) return;
    if (_q.text.trim() != q) return;
    setState(() { online = r; onlineBusy = false; });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
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
        final genres = store.genreSet().toList()..sort();
        return SafeArea(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 170).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 80;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Каталог', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    const Text('Корейские дорамы всех лет', style: TextStyle(color: C.tx2, fontSize: 12)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _q, onChanged: _onQ,
                      style: const TextStyle(color: C.tx),
                      decoration: InputDecoration(
                        hintText: 'Название, тема или сюжет: слоуберн, месть…',
                        hintStyle: const TextStyle(color: C.tx2),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.tx2),
                        suffixIcon: onlineBusy ? const Padding(padding: EdgeInsets.all(14),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk))) : null,
                        filled: true, fillColor: C.s1,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: C.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(100), borderSide: const BorderSide(color: C.pk)),
                      ),
                    ),
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
                    Text('Всего в базе: ${fmtNum(store.krCount)} · найдено: ${fmtNum(list.length)}',
                      style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              if (list.isEmpty)
                SliverToBoxAdapter(child: EmptyBox(Icons.tv_off_rounded,
                  store.scanning ? 'Каталог ещё грузится' : 'Ничего не нашли',
                  'Введите название по-русски или по-английски, например «Гоблин» или Squid Game.'))
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (c, i) => DramaCard(list[i], key: ValueKey(list[i].id)),
                      childCount: list.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols, mainAxisSpacing: 16, crossAxisSpacing: gap,
                      childAspectRatio: cw / ch),
                  ),
                ),
            ]);
          }),
        );
      },
    );
  }
}

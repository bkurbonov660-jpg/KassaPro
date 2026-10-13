import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';
import 'widgets.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _q = TextEditingController();
  String? year;
  String? country;
  String? genre;
  String sort = 'new';
  Timer? _deb;
  List<Drama>? online;
  bool onlineBusy = false;

  @override
  void dispose() { _deb?.cancel(); _q.dispose(); super.dispose(); }

  void _onQ(String v) {
    _deb?.cancel();
    setState(() { online = null; onlineBusy = false; });
    final q = v.trim();
    if (q.length < 3 || RegExp(r'[а-яёА-ЯЁ]').hasMatch(q)) return;
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
        var list = store.browse(year: year, country: country, genre: genre, sort: sort, q: _q.text);
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
            final ch = cw * 1.5 + 66;
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Каталог', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _q,
                      onChanged: _onQ,
                      style: const TextStyle(color: C.tx),
                      decoration: InputDecoration(
                        hintText: 'Название по-русски или по-английски',
                        hintStyle: const TextStyle(color: C.tx2),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.tx2),
                        suffixIcon: onlineBusy
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: C.pk)))
                            : null,
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
                      for (var y = DateTime.now().year + 1; y >= 2020; y--)
                        FilterPill('$y', year == '$y', () => setState(() => year = '$y')),
                    ]),
                    const SizedBox(height: 8),
                    ChipRow([
                      FilterPill('Все страны', country == null, () => setState(() => country = null)),
                      for (final e in Cfg.countries.entries)
                        FilterPill(e.value, country == e.key, () => setState(() => country = e.key)),
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
                    const SizedBox(height: 6),
                    Text('Найдено: ${list.length}', style: const TextStyle(color: C.tx2, fontSize: 12)),
                  ]),
                ),
              ),
              if (list.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyBox(
                    Icons.tv_off_rounded,
                    store.scanning ? 'Каталог ещё грузится' : 'Ничего не нашли',
                    'Русские названия ищутся среди загруженных. Для остальных введите английское, например Squid Game.',
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

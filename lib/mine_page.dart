import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'detail_page.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';
import 'widgets.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String tab = 'watch';
  String sort = 'added';
  String? dubFilter;
  bool gridView = true;
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<Drama> _filteredAndSorted(List<Drama> raw) {
    final q = _searchCtl.text.trim().toLowerCase().replaceAll('ё', 'е');
    var list = raw.where((d) {
      if (dubFilter != null && store.dubOf[d.id] != dubFilter) return false;
      if (q.isEmpty) return true;
      final ru = store.ruTitle(d).toLowerCase().replaceAll('ё', 'е');
      final en = d.en.toLowerCase();
      final dub = (store.dubOf[d.id] ?? '').toLowerCase().replaceAll('ё', 'е');
      final note = (store.notes[d.id] ?? '').toLowerCase().replaceAll('ё', 'е');
      return ru.contains(q) || en.contains(q) || dub.contains(q) || note.contains(q);
    }).toList();

    if (sort == 'az') {
      list.sort((a, b) => store.ruTitle(a).toLowerCase().compareTo(store.ruTitle(b).toLowerCase()));
    } else if (sort == 'rate') {
      list.sort((a, b) {
        final ra = store.rate[a.id] ?? 0;
        final rb = store.rate[b.id] ?? 0;
        if (rb != ra) return rb.compareTo(ra);
        return (b.rating ?? 0).compareTo(a.rating ?? 0);
      });
    } else {
      list.sort((a, b) {
        final ta = store.addedAt[a.id] ?? 0;
        final tb = store.addedAt[b.id] ?? 0;
        if (tb != ta) return tb.compareTo(ta);
        return b.date.compareTo(a.date);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rawList = store.listItems(tab);
        final availableDubs = <String>{
          for (final d in rawList)
            if ((store.dubOf[d.id] ?? '').isNotEmpty) store.dubOf[d.id]!,
        }.toList()..sort();
        if (dubFilter != null && !availableDubs.contains(dubFilter)) {
          dubFilter = null;
        }
        final l = _filteredAndSorted(rawList);

        return SafeArea(
          child: LayoutBuilder(builder: (context, cons) {
            final w = cons.maxWidth - 32;
            final cols = math.max(2, (w / 165).floor());
            const gap = 14.0;
            final cw = (w - gap * (cols - 1)) / cols;
            final ch = cw * 1.5 + 78;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Expanded(
                            child: Text('Мои дорамы', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                          ),
                          if (rawList.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '${l.length}',
                                style: const TextStyle(color: C.tx2, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          IconButton(
                            tooltip: gridView ? 'Список' : 'Сетка карточек',
                            onPressed: () => setState(() => gridView = !gridView),
                            icon: Icon(gridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                                color: C.tx, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: C.s1,
                              side: const BorderSide(color: C.line),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        ChipRow([
                          FilterPill('Смотрю (${store.listItems("watch").length})', tab == 'watch',
                              () => setState(() => tab = 'watch')),
                          FilterPill('В планах (${store.listItems("plan").length})', tab == 'plan',
                              () => setState(() => tab = 'plan')),
                          FilterPill('Просмотрено (${store.listItems("done").length})', tab == 'done',
                              () => setState(() => tab = 'done')),
                          FilterPill('Брошено (${store.listItems("drop").length})', tab == 'drop',
                              () => setState(() => tab = 'drop')),
                        ]),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: C.tx, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Поиск по названию, озвучке или заметке…',
                            hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: C.pk, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    onPressed: () {
                                      _searchCtl.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded, color: C.tx2, size: 18),
                                  )
                                : null,
                            filled: true,
                            fillColor: C.s1,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
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
                        ChipRow([
                          FilterPill('По дате', sort == 'added', () => setState(() => sort = 'added')),
                          FilterPill('По алфавиту', sort == 'az', () => setState(() => sort = 'az')),
                          FilterPill('По оценке', sort == 'rate', () => setState(() => sort = 'rate')),
                          for (final db in availableDubs)
                            FilterPill(db, dubFilter == db,
                                () => setState(() => dubFilter = dubFilter == db ? null : db)),
                        ]),
                        const SizedBox(height: 12),
                        if (tab == 'plan' && rawList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(children: [
                              Expanded(child: extraBtn('Случайная', Icons.casino_rounded, () => showRoulette(context))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: extraBtn('Сравнить', Icons.compare_arrows_rounded, () => openCompare(context))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                if (rawList.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyBox(
                      Icons.bookmark_border_rounded,
                      'Здесь пока пусто',
                      'Откройте любую дораму в каталоге или нажмите на галочку в правом верхнем углу постера.',
                    ),
                  )
                else if (l.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyBox(
                      Icons.search_off_rounded,
                      'Ничего не найдено',
                      'Попробуйте изменить запрос поиска или фильтр.',
                    ),
                  )
                else if (gridView)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (c, i) => DramaCard(l[i], key: ValueKey(l[i].id)),
                        childCount: l.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: gap,
                        childAspectRatio: cw / ch,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (c, i) {
                          final d = l[i];
                          return GestureDetector(
                            onTap: () => openDrama(context, d),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: C.s1,
                                border: Border.all(color: C.line),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(width: 60, height: 88, child: Poster(d)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(store.ruTitle(d),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${d.year ?? ""}${store.rate[d.id] != null ? " · ★ ${store.rate[d.id]}" : ""}',
                                          style: const TextStyle(color: C.tx2, fontSize: 12),
                                        ),
                                        if ((store.dubOf[d.id] ?? '').isNotEmpty)
                                          DubBadge(store.dubOf[d.id]!, small: true),
                                      ],
                                    ),
                                    if (tab == 'watch')
                                      Row(children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) - 1),
                                          icon: const Icon(Icons.remove_circle_outline_rounded, color: C.tx2),
                                        ),
                                        Text(
                                          'Серия ${store.prog[d.id] ?? 0}${store.totals[d.id] != null ? " из ${store.totals[d.id]}" : ""}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, color: C.jd),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) + 1),
                                          icon: const Icon(Icons.add_circle_rounded, color: C.pk),
                                        ),
                                      ]),
                                  ]),
                                ),
                              ]),
                            ),
                          );
                        },
                        childCount: l.length,
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

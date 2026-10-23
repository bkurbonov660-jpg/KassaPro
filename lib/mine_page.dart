import 'package:flutter/material.dart';
import 'detail_page.dart';
import 'extras_ui.dart';
import 'models.dart';
import 'store.dart';
import 'ui_common.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String tab = 'watch';
  String sort = 'added'; // 'added', 'az', 'rate'
  String? dubFilter;
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
      // По дате добавления (новые сверху)
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(children: [
                const Expanded(
                  child: Text('Мои дорамы', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                Text(
                  'Всего: ${rawList.length}',
                  style: const TextStyle(color: C.jd, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ]),
              const SizedBox(height: 12),
              ChipRow([
                FilterPill('Смотрю (${store.listItems('watch').length})', tab == 'watch', () => setState(() => tab = 'watch')),
                FilterPill('В планах (${store.listItems('plan').length})', tab == 'plan', () => setState(() => tab = 'plan')),
                FilterPill('Просмотрено (${store.listItems('done').length})', tab == 'done', () => setState(() => tab = 'done')),
                FilterPill('Брошено (${store.listItems('drop').length})', tab == 'drop', () => setState(() => tab = 'drop')),
              ]),
              const SizedBox(height: 12),
              // Строка поиска внутри своих списков
              TextField(
                controller: _searchCtl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: C.tx, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск в списке по названию, озвучке или заметке…',
                  hintStyle: const TextStyle(color: C.tx2, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: C.tx2),
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
              // Сортировка внутри списков
              ChipRow([
                FilterPill('По дате добавления', sort == 'added', () => setState(() => sort = 'added')),
                FilterPill('По алфавиту (А–Я)', sort == 'az', () => setState(() => sort = 'az')),
                FilterPill('По вашей оценке ★', sort == 'rate', () => setState(() => sort = 'rate')),
              ]),
              if (availableDubs.isNotEmpty) ...[
                const SizedBox(height: 8),
                ChipRow([
                  FilterPill('Все озвучки', dubFilter == null, () => setState(() => dubFilter = null)),
                  for (final db in availableDubs)
                    FilterPill('🎙 $db', dubFilter == db, () => setState(() => dubFilter = dubFilter == db ? null : db)),
                ]),
              ],
              const SizedBox(height: 12),
              if (tab == 'plan' && rawList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Expanded(child: extraBtn('Случайная', Icons.casino_rounded, () => showRoulette(context))),
                    const SizedBox(width: 10),
                    Expanded(child: extraBtn('Сравнить', Icons.compare_arrows_rounded, () => openCompare(context))),
                  ]),
                ),
              if (rawList.isEmpty)
                const EmptyBox(Icons.bookmark_border_rounded, 'Здесь пока пусто',
                  'Откройте дораму в каталоге и добавьте её в список.')
              else if (l.isEmpty)
                const EmptyBox(Icons.search_off_rounded, 'Ничего не найдено',
                  'Попробуйте изменить запрос поиска или сбросить фильтр озвучки.'),
              for (final d in l)
                GestureDetector(
                  onTap: () => openDrama(context, d),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 60, height: 90, child: Poster(d))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.ruTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                        const SizedBox(height: 4),
                        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(
                            '${d.year ?? "скоро"}${store.rate[d.id] != null ? " · ★ ${store.rate[d.id]}/10" : (d.rating != null ? " · TVmaze ${d.rating!.toStringAsFixed(1)}" : "")}',
                            style: const TextStyle(color: C.tx2, fontSize: 12),
                          ),
                          if ((store.dubOf[d.id] ?? '').isNotEmpty)
                            DubBadge(store.dubOf[d.id]!, small: true),
                        ]),
                        if ((store.notes[d.id] ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💬 ${store.notes[d.id]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: C.tx2, fontSize: 11.5, fontStyle: FontStyle.italic),
                            ),
                          ),
                        const SizedBox(height: 4),
                        EpisodeCountdownBadge(d, compact: true),
                        if (tab == 'watch' && store.newEps(d) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text('Новых серий: ${store.newEps(d)}',
                              style: const TextStyle(color: C.gd, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        if (tab == 'watch')
                          Row(children: [
                            IconButton(visualDensity: VisualDensity.compact,
                              onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) - 1),
                              icon: const Icon(Icons.remove_circle_outline_rounded, color: C.tx2)),
                            Text('Серия ${store.prog[d.id] ?? 0}${store.totals[d.id] != null ? " из ${store.totals[d.id]}" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: C.jd)),
                            IconButton(visualDensity: VisualDensity.compact,
                              onPressed: () => store.setProg(d, (store.prog[d.id] ?? 0) + 1),
                              icon: const Icon(Icons.add_circle_rounded, color: C.pk)),
                          ]),
                      ])),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

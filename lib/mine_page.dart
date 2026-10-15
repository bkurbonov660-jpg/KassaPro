import 'package:flutter/material.dart';
import 'detail_page.dart';
import 'store.dart';
import 'ui_common.dart';

class MinePage extends StatefulWidget {
  const MinePage({super.key});
  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  String tab = 'watch';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final l = store.listItems(tab);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text('Мои дорамы', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ChipRow([
                FilterPill('Смотрю', tab == 'watch', () => setState(() => tab = 'watch')),
                FilterPill('В планах', tab == 'plan', () => setState(() => tab = 'plan')),
                FilterPill('Просмотрено', tab == 'done', () => setState(() => tab = 'done')),
              ]),
              const SizedBox(height: 12),
              if (l.isEmpty)
                const EmptyBox(Icons.bookmark_border_rounded, 'Здесь пока пусто',
                  'Откройте дораму в каталоге и добавьте её в список.'),
              for (final d in l)
                GestureDetector(
                  onTap: () => openDrama(context, d),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 56, height: 84, child: Poster(d))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.ruTitle(d), maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${d.year ?? ""}${store.rate[d.id] != null ? " · ★ ${store.rate[d.id]}" : ""}',
                          style: const TextStyle(color: C.tx2, fontSize: 12)),
                        if (tab == 'watch' && store.newEps(d) > 0)
                          Text('Новых серий: ${store.newEps(d)}',
                            style: const TextStyle(color: C.gd, fontSize: 12, fontWeight: FontWeight.w800)),
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

import 'package:flutter/material.dart';
import 'config.dart';
import 'openrouter.dart';
import 'store.dart';
import 'ui_common.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final soon = store.upcoming();
        final fresh = store.fresh();
        final top = store.topYear();
        final lu = store.lastUpdate;
        final status = store.refreshing
            ? 'Обновляем данные…'
            : lu == null ? 'Загрузка…' : 'Обновлено в ${two(lu.hour)}:${two(lu.minute)}';
        final left = store.translator.left;
        return SafeArea(
          child: RefreshIndicator(
            color: C.pk,
            backgroundColor: C.s1,
            onRefresh: () => store.refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text(Cfg.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text(status, style: const TextStyle(color: C.tx2, fontSize: 13)),
                    ]),
                  ),
                  IconButton(
                    onPressed: store.refreshing ? null : () => store.refresh(),
                    icon: store.refreshing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.pk))
                        : const Icon(Icons.refresh_rounded, color: C.tx2),
                    style: IconButton.styleFrom(backgroundColor: C.s1, side: const BorderSide(color: C.line)),
                  ),
                ]),
                const SizedBox(height: 12),
                if (store.scanning)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Ищем новые дорамы по всему миру: ${(store.scanProgress * 100).round()}%',
                          style: const TextStyle(color: C.tx2, fontSize: 12)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: store.scanProgress, color: C.pk, backgroundColor: C.s2, minHeight: 3),
                    ]),
                  ),
                if (left > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Переводим названия на русский: осталось $left'
                      '${OpenRouter.lastOk ? " · ИИ онлайн" : " · работает встроенный переводчик"}',
                      style: const TextStyle(color: C.tx2, fontSize: 12),
                    ),
                  ),
                if (store.newFinds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.pk), borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome_rounded, color: C.pk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Появились новые дорамы: ${store.newFinds.take(3).map(store.ruTitle).join(", ")}'
                          '${store.newFinds.length > 3 ? " и ещё ${store.newFinds.length - 3}" : ""}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        onPressed: () { store.newFinds.clear(); store.changed(); },
                        icon: const Icon(Icons.close_rounded, color: C.tx2),
                      ),
                    ]),
                  ),
                const SectionTitle('Сегодня в эфире', live: true),
                if (store.live.isEmpty)
                  const Text('Сегодня новых серий не нашли или данные ещё грузятся.', style: TextStyle(color: C.tx2))
                else
                  SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: store.live.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => LiveCard(store.live[i]),
                    ),
                  ),
                if (fresh.isNotEmpty) const SectionTitle('Новые находки'),
                if (fresh.isNotEmpty) PosterRail(fresh),
                if (soon.isNotEmpty) const SectionTitle('Скоро выходят и анонсы'),
                if (soon.isNotEmpty) PosterRail(soon),
                if (top.isNotEmpty) SectionTitle('Лучшее ${DateTime.now().year} года'),
                if (top.isNotEmpty) PosterRail(top),
                if (soon.isEmpty && top.isEmpty && fresh.isEmpty && store.live.isEmpty)
                  const EmptyBox(Icons.tv_rounded, 'Идёт загрузка каталога',
                      'Потяните вниз для обновления. Первый запуск занимает пару минут.'),
              ],
            ),
          ),
        );
      },
    );
  }
}

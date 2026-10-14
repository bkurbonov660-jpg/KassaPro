import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dict.dart';
import 'openrouter.dart';
import 'store.dart';
import 'ui_common.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bk = TextEditingController();
  @override
  void dispose() { _bk.dispose(); super.dispose(); }
  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Widget _stat(String v, String t) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(v, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(t, style: const TextStyle(color: C.tx2, fontSize: 12)),
    ]));

  Widget _btn(String t, IconData i, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: f, icon: Icon(i, color: C.pk),
      label: Text(t, style: const TextStyle(color: C.tx)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: C.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rated = store.rate.values.toList();
        final avg = rated.isEmpty ? '—' : (rated.reduce((a, b) => a + b) / rated.length).toStringAsFixed(1);
        final ai = OpenRouter.lastOk ? 'ИИ работает: ${OpenRouter.lastModel}'
          : OpenRouter.badKey ? 'Ключ OpenRouter не принят'
          : 'ИИ пока не отвечал';
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Профиль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: [
                  _stat('${store.rate.length}', 'Оценено'),
                  _stat(avg, 'Средняя оценка'),
                  _stat('${store.listItems('watch').length}', 'Смотрю'),
                  _stat('${store.listItems('plan').length}', 'В планах'),
                  _stat('${store.listItems('done').length}', 'Просмотрено'),
                  _stat('${store.allDramas.length}', 'Дорам в каталоге'),
                ]),
              const SectionTitle('Точные названия'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(18)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('С русским названием: ${store.ruCount} из ${store.allDramas.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Словарь: $dictSize · Кинопоиск: ${store.countSrc("kinopoisk")} · '
                    'Википедия: ${store.countSrc("wiki")} · ИИ: ${store.countSrc("ai")} · '
                    'Авто: ${store.countSrc("mt") + store.countSrc("local")}',
                    style: const TextStyle(color: C.tx2, fontSize: 11)),
                  const SizedBox(height: 10),
                  Text(ai, style: const TextStyle(color: C.jd, fontSize: 12, fontWeight: FontWeight.w700)),
                  if (OpenRouter.lastError.isNotEmpty)
                    Text(OpenRouter.lastError, style: const TextStyle(color: C.tx2, fontSize: 11)),
                ])),
              const SizedBox(height: 12),
              _btn('Проверить ИИ', Icons.psychology_rounded, () async {
                _snack('Проверяем…');
                final r = await store.testAi();
                if (mounted) _snack(r);
              }),
              _btn('Обновить прямо сейчас', Icons.refresh_rounded, () => store.refresh()),
              _btn('Перевести названия заново', Icons.translate_rounded, () {
                store.retranslateAll(); _snack('Перевод запущен');
              }),
              _btn('Глубокое сканирование каталога', Icons.travel_explore_rounded, () {
                store.deepScan(); _snack('Ищем более старые дорамы');
              }),
              SwitchListTile(
                value: OpenRouter.webPlugin, onChanged: (v) => store.setWeb(v),
                activeColor: C.pk, contentPadding: EdgeInsets.zero,
                title: const Text('Веб-поиск OpenRouter для ИИ', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Может требовать кредиты. По умолчанию выключен.',
                  style: TextStyle(color: C.tx2, fontSize: 11))),
              const SectionTitle('Резервная копия'),
              Row(children: [
                Expanded(child: _btn('Скопировать', Icons.copy_rounded, () async {
                  await Clipboard.setData(ClipboardData(text: store.backup()));
                  _snack('Копия в буфере обмена');
                })),
                const SizedBox(width: 10),
                Expanded(child: _btn('Восстановить', Icons.restore_rounded, () {
                  final ok = store.restore(_bk.text);
                  _snack(ok ? 'Восстановлено' : 'Не удалось прочитать копию');
                })),
              ]),
              TextField(
                controller: _bk, maxLines: 4,
                style: const TextStyle(color: C.tx, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Вставьте сюда копию для восстановления',
                  hintStyle: const TextStyle(color: C.tx2),
                  filled: true, fillColor: C.s1,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.line)))),
            ],
          ),
        );
      },
    );
  }
}

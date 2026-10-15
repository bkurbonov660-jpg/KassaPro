import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        final genres = store.topGenres();
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text('Профиль', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _stat('${store.rate.length}', 'Оценено'),
                  _stat(avg, 'Средняя оценка'),
                  _stat('${store.listItems('watch').length}', 'Смотрю'),
                  _stat('${store.listItems('plan').length}', 'В планах'),
                  _stat('${store.listItems('done').length}', 'Просмотрено'),
                  _stat('${store.notes.length}', 'Заметок'),
                ]),
              const SectionTitle('Любимые жанры'),
              if (genres.isEmpty)
                const Text('Добавьте дорамы в списки и ставьте оценки — здесь появятся ваши жанры.',
                    style: TextStyle(color: C.tx2))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final g in genres)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: C.s1, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(100)),
                      child: Text('${ruGenre(g.key)} · ${g.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                ]),
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

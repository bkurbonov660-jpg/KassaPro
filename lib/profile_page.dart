import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native.dart';
import 'extras_ui.dart';
import 'feedback_page.dart';
import 'privacy_page.dart';
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

  Future<void> _saveFile() async {
    final ok = await Native.saveFile('dorama_pulse_backup.json', store.backup());
    if (!mounted) return;
    _snack(ok ? 'Бэкап сохранён в файл' : 'Бэкап не сохранён');
  }

  Future<void> _loadFile() async {
    final txt = await Native.pickFile();
    if (!mounted) return;
    if (txt == null || txt.trim().isEmpty) { _snack('Файл не выбран'); return; }
    final n = store.backupCount(txt);
    if (n < 0) { _snack('Это не файл бэкапа Дорама Пульс'); return; }
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.s1,
        title: const Text('Восстановить из файла?'),
        content: Text('В файле дорам в списках: $n. Текущие списки, серии, оценки и заметки будут заменены данными из файла.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: C.pk, foregroundColor: C.onPk),
            child: const Text('Восстановить')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = store.restore(txt);
    _snack(ok ? 'Данные восстановлены' : 'Не удалось прочитать файл');
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
                  _stat('${store.listItems('drop').length}', 'Брошено'),
                  _stat('${store.notes.length}', 'Заметок'),
                  _stat('${store.prog.values.fold<int>(0, (a, b) => a + b)}', 'Серий отмечено'),
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
              _btn('Сохранить бэкап в файл', Icons.save_alt_rounded, _saveFile),
              _btn('Восстановить из файла', Icons.folder_open_rounded, _loadFile),
              const SizedBox(height: 2),
              const Text('Или через буфер обмена', style: TextStyle(color: C.tx2, fontSize: 12)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
              const TgCard(),
              const SizedBox(height: 10),
              _btn('Идеи и ошибки: написать разработчику', Icons.forum_rounded,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FeedbackPage()))),
              _btn('Политика конфиденциальности', Icons.privacy_tip_rounded,
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPage()))),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'native.dart';
import 'ui_common.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  // (название, тема письма, подсказка, иконка)
  static const List<(String, String, String, IconData)> _kinds = [
    ('Идея', 'Идея', 'Что добавить или улучшить? Опишите, как это должно работать.', Icons.lightbulb_rounded),
    ('Ошибка', 'Ошибка', 'Что пошло не так? На каком экране и после каких действий?', Icons.bug_report_rounded),
    ('Перевод', 'Неточный перевод', 'Название дорамы и как её правильно называть по-русски.', Icons.translate_rounded),
    ('Дорама', 'Добавьте дораму', 'Название дорамы (лучше с годом выхода).', Icons.movie_rounded),
    ('Отзыв', 'Отзыв', 'Что нравится, а что нет?', Icons.favorite_rounded),
  ];

  int _k = 0;
  final TextEditingController _t = TextEditingController();

  @override
  void dispose() { _t.dispose(); super.dispose(); }

  String get _subject => '[${Cfg.appName}] ${_kinds[_k].$2}';

  String get _body =>
      '${_t.text.trim()}\n\n—\nМодель телефона и версия Android (по желанию): ';

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: 'Кому: ${Cfg.contactEmail}\nТема: $_subject\n\n$_body'));
    _snack('Письмо скопировано. Отправьте его на ${Cfg.contactEmail}');
  }

  Future<void> _send() async {
    if (_t.text.trim().isEmpty) { _snack('Сначала напишите сообщение'); return; }
    final ok = await Native.sendMail(Cfg.contactEmail, _subject, _body);
    if (!ok) {
      await _copy();
      _snack('Почтовое приложение не найдено. Текст скопирован');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg, elevation: 0, foregroundColor: C.tx,
        title: const Text('Идеи и ошибки',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Text('Помогите сделать «Дорама Пульс» лучше',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 6),
          const Text(
              'Предложите идею, сообщите об ошибке или неточном переводе. '
              'Администратор прочитает сообщение, ответит вам на почту и сообщит, когда ошибка исправлена '
              'или идея принята в работу.',
              style: TextStyle(color: C.tx2, fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (var i = 0; i < _kinds.length; i++)
                ChoiceChip(
                  avatar: Icon(_kinds[i].$4, size: 18, color: _k == i ? C.onPk : C.tx2),
                  label: Text(_kinds[i].$1),
                  selected: _k == i,
                  selectedColor: C.pk,
                  backgroundColor: C.s1,
                  side: const BorderSide(color: C.line),
                  labelStyle: TextStyle(color: _k == i ? C.onPk : C.tx, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _k = i),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _t, minLines: 6, maxLines: 12, maxLength: 2000,
            style: const TextStyle(color: C.tx, fontSize: 14),
            decoration: InputDecoration(
              hintText: _kinds[_k].$3,
              hintStyle: const TextStyle(color: C.tx2),
              filled: true, fillColor: C.s1,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: C.line)),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Отправить по почте'),
            style: FilledButton.styleFrom(
              backgroundColor: C.pk, foregroundColor: C.onPk,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _copy,
            icon: const Icon(Icons.copy_rounded, color: C.pk),
            label: const Text('Скопировать текст письма', style: TextStyle(color: C.tx)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: C.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
              'Приложение само ничего не отправляет: письмо уходит из вашей почты на ${Cfg.contactEmail}. '
              'Не пишите в нём пароли и платёжные данные.',
              style: const TextStyle(color: C.tx2, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}

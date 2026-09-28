import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../store.dart';
import '../models.dart';
import '../main.dart';
import 'icon_pack.dart';
import 'tx_sheet.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  const GoalCard({super.key, required this.goal});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final cur = goal.currency;
    final done = goal.isDone;
    final left = (goal.target - goal.current).clamp(0.0, double.infinity);
    final deadline = s.daysUntil(goal.deadline);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(iconFor(goal.icon), size: 20, color: AppColors.accent)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text('${s.fmt(goal.current,cur)} из ${s.fmt(goal.target,cur)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
          Text('${goal.pct.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent)),
          const SizedBox(width: 4),
          InkWell(
            onTap: ()=>_openMenu(context),
            borderRadius: BorderRadius.circular(6),
            child: Container(width: 28, height: 28, alignment: Alignment.center,
              child: const Icon(Icons.more_horiz, size: 18, color: AppColors.muted)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: goal.pct/100, minHeight: 6, backgroundColor: AppColors.panel2,
          valueColor: AlwaysStoppedAnimation(done ? AppColors.green : AppColors.accent))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(done ? '🎉 Готово!' : 'Осталось: ${s.fmt(left,cur)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if(!done) Text('${s.fmt(left/7,cur)} / мес', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        if(deadline != null && !done) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line, style: BorderStyle.solid))),
            child: Row(children: [
              Icon(Icons.access_time, size: 13, color: deadline<0 ? AppColors.red : AppColors.accent),
              const SizedBox(width: 5),
              Expanded(child: Text(
                deadline < 0
                  ? 'Просрочено на ${-deadline} дн.'
                  : 'До ${_fmtDate(goal.deadline!)} · $deadline дн. · нужно ${s.fmt((left/deadline)*30,cur)}/мес',
                style: TextStyle(fontSize: 11.5, color: deadline<0 ? AppColors.red : AppColors.muted),
                overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ]),
    );
  }

  String _fmtDate(String iso){
    final d = DateTime.parse(iso);
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}.${d.year}';
  }

  void _openMenu(BuildContext ctx){
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=>Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text(goal.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Что сделать с целью?', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          _btn(ctx, Icons.edit, 'Редактировать', (){
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), ()=>GoalEditorSheet.show(ctx, goal));
          }),
          _btn(ctx, Icons.add, 'Добавить доход', (){
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), ()=>TxSheet.show(ctx, 'income', goalId: goal.id));
          }),
          _btn(ctx, Icons.remove, 'Добавить расход', (){
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), ()=>TxSheet.show(ctx, 'expense', goalId: goal.id));
          }),
          _btn(ctx, Icons.delete_outline, 'Удалить цель', (){
            Navigator.pop(ctx);
            context.read<AppStore>().deleteGoal(goal.id);
          }, red: true),
        ])),
    );
  }

  Widget _btn(BuildContext ctx, IconData ic, String label, VoidCallback onTap, {bool red=false}){
    return Padding(padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, size: 16, color: red ? AppColors.red : AppColors.text),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: red ? AppColors.red : AppColors.text)),
          ]),
        ),
      ));
  }
}

class GoalEditorSheet {
  static void show(BuildContext context, Goal? edit) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.panel, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=>_GoalEditor(edit: edit));
  }
}

class _GoalEditor extends StatefulWidget {
  final Goal? edit;
  const _GoalEditor({this.edit});
  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late TextEditingController _title;
  late TextEditingController _target;
  late TextEditingController _deadline;
  String _icon = 'target';
  String _cur = 'RUB';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _cur = e?.currency ?? s.defaultCurrency ?? 'RUB';
    final tv = e!=null ? s.fromRub(e.target, _cur).round().toString() : '';
    _target = TextEditingController(text: tv);
    _deadline = TextEditingController(text: e?.deadline ?? '');
    _icon = e?.icon ?? 'target';
  }
  @override
  void dispose(){ _title.dispose(); _target.dispose(); _deadline.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text(widget.edit==null ? 'Новая цель' : 'Редактировать', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Заполни поля', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          _lbl('Название'),
          _input(_title, 'Например: Накопить на машину'),
          const SizedBox(height: 16),
          _lbl('Иконка'),
          GridView.count(crossAxisCount: 6, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6, crossAxisSpacing: 6,
            children: iconKeys.map((k){
              final on = _icon == k;
              return GestureDetector(
                onTap: ()=>setState(()=>_icon=k),
                child: Container(decoration: BoxDecoration(
                  color: on ? AppColors.accentSoft : AppColors.panel2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: on ? AppColors.accent : AppColors.line)),
                  child: Icon(iconFor(k), size: 20, color: on ? AppColors.accent : AppColors.muted)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _lbl('Целевая сумма'),
          _input(_target, '100000', number: true),
          const SizedBox(height: 16),
          _lbl('Валюта'),
          Wrap(spacing: 8, runSpacing: 8, children: ALL_CUR.map((c){
            final on = _cur == c;
            return GestureDetector(
              onTap: ()=>setState(()=>_cur=c),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.panel2,
                  borderRadius: BorderRadius.circular(9), border: Border.all(color: on ? AppColors.accent : AppColors.line)),
                child: Text('${CUR_SYM[c]} $c', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.muted))),
            );
          }).toList()),
          const SizedBox(height: 16),
          _lbl('Дедлайн (необязательно)'),
          _input(_deadline, 'ГГГГ-ММ-ДД'),
          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: (){
              final title = _title.text.trim();
              final t = double.tryParse(_target.text) ?? 0;
              if(title.isEmpty||t<=0) return;
              final d = _deadline.text.trim().isEmpty ? null : _deadline.text.trim();
              if(widget.edit == null){
                s.addGoal(Goal(id: const Uuid().v4(), title: title, icon: _icon,
                  target: s.toRub(t,_cur), current: 0, currency: _cur, deadline: d,
                  createdAt: DateTime.now().millisecondsSinceEpoch));
              } else {
                final g = widget.edit!;
                g.title = title; g.icon = _icon; g.currency = _cur;
                g.target = s.toRub(t,_cur); g.deadline = d;
                s.updateGoal(g);
              }
              Navigator.pop(context);
            },
            child: Text(widget.edit==null ? 'Создать цель' : 'Сохранить',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          )),
        ]),
      )));
  }

  Widget _lbl(String t)=>Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.4)));

  Widget _input(TextEditingController c, String hint, {bool number=false}){
    return TextField(
      controller: c, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: Color(0xFF3a3f4a)),
        filled: true, fillColor: AppColors.panel2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
      ),
    );
  }
}

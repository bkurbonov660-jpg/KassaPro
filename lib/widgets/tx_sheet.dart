import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../store.dart';
import '../models.dart';
import '../main.dart';

class TxSheet {
  static void show(BuildContext context, String type, {String? goalId, TxRecord? edit}) {
    showModalBottomSheet(context: context, backgroundColor: AppColors.panel, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=>_TxEditor(type: type, initialGoalId: goalId, edit: edit));
  }
}

class _TxEditor extends StatefulWidget {
  final String type; final String? initialGoalId; final TxRecord? edit;
  const _TxEditor({required this.type, this.initialGoalId, this.edit});
  @override
  State<_TxEditor> createState() => _TxEditorState();
}

class _TxEditorState extends State<_TxEditor> {
  late TextEditingController _amount;
  late TextEditingController _note;
  late String _type;
  late String _cur;
  String _goalId = 'auto';
  String _expenseGoal = 'none';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    final e = widget.edit;
    _type = e?.type ?? widget.type;
    _cur = e?.cur ?? s.defaultCurrency ?? 'RUB';
    _amount = TextEditingController(text: e!=null ? e.amount.toString() : '');
    _note = TextEditingController(text: e?.note ?? '');
    if(e!=null){
      if(e.type=='income'){ _goalId = e.isAuto ? 'auto' : (e.goalId ?? 'auto'); }
      else { _expenseGoal = e.affectsGoal ? (e.goalId ?? 'none') : 'none'; }
    } else {
      if(widget.type=='income' && widget.initialGoalId!=null) _goalId = widget.initialGoalId!;
      if(widget.type=='expense' && widget.initialGoalId!=null) _expenseGoal = widget.initialGoalId!;
    }
  }
  @override
  void dispose(){ _amount.dispose(); _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final amt = double.tryParse(_amount.text) ?? 0;
    final rub = s.toRub(amt, _cur);
    final preview = amt > 0
      ? (_cur != s.defaultCurrency ? '${amt.toStringAsFixed(amt.truncateToDouble()==amt?0:2)} ${CUR_SYM[_cur]} → ${s.fmt(rub)}' : s.fmt(rub))
      : '0 ${CUR_SYM[_cur]}';

    return Padding(padding: EdgeInsets.only(bottom: inset),
      child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text(widget.edit==null ? (_type=='income' ? 'Новый доход' : 'Новый расход') : 'Редактировать',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(widget.edit==null ? 'Заполни поля' : 'Измени данные',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line)),
            child: Row(children: [
              _typeTab('income','Доход', Icons.add),
              _typeTab('expense','Расход', Icons.remove),
            ]),
          ),
          const SizedBox(height: 16),
          _lbl('Сумма'),
          _input(_amount, '5000', number: true, onChanged: ()=>setState((){})),
          const SizedBox(height: 16),
          _lbl('Валюта'),
          Wrap(spacing: 8, runSpacing: 8, children: ALL_CUR.map((c){
            final on = _cur == c;
            return GestureDetector(onTap: ()=>setState(()=>_cur=c),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.panel2,
                  borderRadius: BorderRadius.circular(9), border: Border.all(color: on ? AppColors.accent : AppColors.line)),
                child: Text('${CUR_SYM[c]} $c', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.muted))));
          }).toList()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line)),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(
                color: _type=='income' ? AppColors.greenSoft : AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.swap_horiz, size: 18, color: _type=='income' ? AppColors.green : AppColors.red)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('АВТОКОНВЕРТАЦИЯ', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(preview, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
              ])),
            ]),
          ),
          if(_type=='income') ...[
            const SizedBox(height: 16),
            _lbl('Куда направить'),
            _chipsWrap([
              ('auto','Все цели'),
              ...s.activeGoals.map((g)=>(g.id, g.title)),
            ], _goalId, (v)=>setState(()=>_goalId=v)),
          ] else ...[
            const SizedBox(height: 16),
            _lbl('Списать с цели?'),
            _chipsWrap([
              ('none','Просто расход'),
              ...s.activeGoals.map((g)=>(g.id, 'Списать с «${g.title}»')),
            ], _expenseGoal, (v)=>setState(()=>_expenseGoal=v)),
          ],
          const SizedBox(height: 16),
          _lbl('Заметка (необязательно)'),
          _input(_note, 'Например: зарплата'),
          const SizedBox(height: 24),
          SizedBox(height: 52, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _type=='income' ? AppColors.green : AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: (){
              final amt = double.tryParse(_amount.text) ?? 0;
              if(amt<=0) return;
              final rub = s.toRub(amt,_cur);
              final note = _note.text.trim();

              if(widget.edit != null){
                final t = widget.edit!;
                t.type = _type; t.rub = rub; t.cur = _cur; t.amount = amt;
                t.note = note; t.date = DateTime.now().millisecondsSinceEpoch;
                if(_type=='income'){
                  if(_goalId=='auto'){ t.isAuto = true; t.goalId = null; t.goalTitle = 'Все цели'; }
                  else { final g = s.goals.firstWhere((x)=>x.id==_goalId); t.isAuto=false; t.goalId=g.id; t.goalTitle=g.title; }
                } else {
                  if(_expenseGoal=='none'){ t.affectsGoal = false; t.goalId = null; t.goalTitle = null; }
                  else { final g = s.goals.firstWhere((x)=>x.id==_expenseGoal); t.affectsGoal=true; t.goalId=g.id; t.goalTitle=g.title; }
                }
                s.updateTx(t);
                Navigator.pop(context);
                return;
              }

              final t = TxRecord(id: const Uuid().v4(), date: DateTime.now().millisecondsSinceEpoch,
                type: _type, rub: rub, cur: _cur, amount: amt, note: note);
              if(_type=='income'){
                if(_goalId=='auto'){ t.isAuto=true; t.goalTitle='Все цели'; }
                else { final g = s.goals.firstWhere((x)=>x.id==_goalId); t.goalId=g.id; t.goalTitle=g.title; }
              } else {
                if(_expenseGoal!='none'){ final g = s.goals.firstWhere((x)=>x.id==_expenseGoal); t.affectsGoal=true; t.goalId=g.id; t.goalTitle=g.title; }
              }
              s.addTx(t);
              Navigator.pop(context);
            },
            child: Text(widget.edit==null ? 'Добавить' : 'Сохранить', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          )),
        ]),
      )));
  }

  Widget _typeTab(String key, String label, IconData ic){
    final on = _type == key;
    final c = key == 'income' ? AppColors.green : AppColors.red;
    return Expanded(child: InkWell(
      onTap: ()=>setState(()=>_type=key),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: on ? c : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ic, size: 15, color: on ? Colors.white : AppColors.muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.muted)),
        ]),
      ),
    ));
  }

  Widget _lbl(String t)=>Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.4)));

  Widget _input(TextEditingController c, String hint, {bool number=false, ValueChanged<String>? onChanged}){
    return TextField(
      controller: c, keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      onChanged: onChanged,
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

  Widget _chipsWrap(List<(String,String)> items, String selected, ValueChanged<String> onSel){
    return Wrap(spacing: 8, runSpacing: 8, children: items.map((it){
      final on = selected == it.$1;
      return GestureDetector(onTap: ()=>onSel(it.$1),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: on ? AppColors.accent : AppColors.panel2,
            borderRadius: BorderRadius.circular(9), border: Border.all(color: on ? AppColors.accent : AppColors.line)),
          child: Text(it.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: on ? Colors.white : AppColors.muted))));
    }).toList());
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../models.dart';
import '../widgets/tx_tile.dart';
import '../widgets/archive_card.dart';
import '../widgets/icon_pack.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _recTarget = TextEditingController();
  final _recMonths = TextEditingController();
  final _recMonthly = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    if(s.recTarget>0) _recTarget.text = s.recTarget.toStringAsFixed(0);
    _recMonths.text = s.recMonths.toStringAsFixed(0);
    _recMonthly.text = s.recMonthly.toStringAsFixed(0);
    _recTarget.addListener(_onChange);
    _recMonths.addListener(_onChange);
    _recMonthly.addListener(_onChange);
  }
  void _onChange(){ setState((){}); }
  @override
  void dispose(){ _recTarget.dispose(); _recMonths.dispose(); _recMonthly.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line)),
          child: Row(children: [
            _tab(s,'money','💰 О деньгах'),
            _tab(s,'history','📜 История','${s.txs.length}'),
            _tab(s,'archive','📦 Архив','${s.archivedGoals.length}'),
          ]),
        ),
        const SizedBox(height: 14),
        if(s.reportTab=='money') ..._money(s),
        if(s.reportTab=='history') ..._history(s),
        if(s.reportTab=='archive') ..._archive(s),
      ],
    );
  }

  Widget _tab(AppStore s, String key, String label, [String? cnt]){
    final on = s.reportTab == key;
    return Expanded(child: InkWell(
      onTap: ()=>s.setReportTab(key),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(color: on ? AppColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: on ? Colors.white : AppColors.muted), overflow: TextOverflow.ellipsis)),
          if(cnt!=null) ...[
            const SizedBox(width: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: on ? Colors.white24 : Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: Text(cnt, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.muted))),
          ],
        ]),
      ),
    ));
  }

  List<Widget> _money(AppStore s){
    final net = s.totalEarned - s.totalSpent;
    final cur = s.defaultCurrency ?? 'RUB';
    return [
      _recommend(s),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0x264f7cff), Color(0x1422c55e)]),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x404f7cff)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ОБЩИЙ БАЛАНС', style: TextStyle(fontSize: 11.5, color: AppColors.muted, letterSpacing: 0.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(s.fmt(net), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
            color: net>=0 ? AppColors.green : AppColors.red, letterSpacing: -0.6)),
          const SizedBox(height: 4),
          RichText(text: TextSpan(children: [
            const TextSpan(text: 'Заработано ', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            TextSpan(text: s.fmt(s.totalEarned), style: const TextStyle(fontSize: 12.5, color: AppColors.green, fontWeight: FontWeight.w700)),
            const TextSpan(text: ' · потрачено ', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            TextSpan(text: s.fmt(s.totalSpent), style: const TextStyle(fontSize: 12.5, color: AppColors.red, fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
      const SizedBox(height: 14),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7,
        children: [
          _moneyCard('Заработано', s.fmt(s.totalEarned), AppColors.green),
          _moneyCard('Потрачено', s.fmt(s.totalSpent), AppColors.red),
          _moneyCard('🎯 В целях', s.fmt(s.totalCurrent), AppColors.text),
          _moneyCard('📦 В архиве', s.fmt(s.archivedGoals.fold(0.0,(a,g)=>a+g.target)), AppColors.text),
        ]),
      if(s.activeGoals.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text('РАЗБИВКА ПО ЦЕЛЯМ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
        ...s.activeGoals.map((g){
          var inc = 0.0, sp = 0.0;
          for(final t in s.txs){ if(t.goalId==g.id){ if(t.type=='income') inc+=t.rub; else sp+=t.rub; } }
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line)),
            child: Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(9)),
                child: Icon(iconFor(g.icon), size: 15, color: AppColors.accent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text('+${s.fmt(inc,g.currency)} / -${s.fmt(sp,g.currency)}', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ])),
              Text(s.fmt(g.current,g.currency), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
            ]),
          );
        }),
      ],
    ];
  }

  Widget _moneyCard(String label, String val, Color color){
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _recommend(AppStore s){
    final cur = s.defaultCurrency ?? 'RUB';
    final target = double.tryParse(_recTarget.text) ?? 0;
    final months = double.tryParse(_recMonths.text) ?? 0;
    final monthly = double.tryParse(_recMonthly.text) ?? 0;

    Widget result;
    if(s.recMode=='save'){
      if(target<=0||months<=0){ result = const Text('Введи сумму и срок', style: TextStyle(fontSize: 11.5, color: AppColors.muted)); }
      else{
        final days = months*30;
        result = Column(children: [
          _recRow('В день', s.fmt(s.toRub(target/days,cur),cur)),
          _recRow('В неделю', s.fmt(s.toRub(target/(days/7),cur),cur)),
          _recRow('В месяц', s.fmt(s.toRub(target/months,cur),cur)),
        ]);
      }
    } else {
      if(target<=0||monthly<=0){ result = const Text('Введи сумму и сколько копишь в месяц', style: TextStyle(fontSize: 11.5, color: AppColors.muted)); }
      else{
        final m = target/monthly;
        final days = (m*30).ceil();
        final finish = DateTime.now().add(Duration(days: days));
        result = Column(children: [
          _recRow('Месяцев', m.toStringAsFixed(1)),
          _recRow('Дней', '$days'),
          _recRow('Финиш', '${finish.day.toString().padLeft(2,'0')}.${finish.month.toString().padLeft(2,'0')}.${finish.year}'),
        ]);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0x1FF59e0b), Color(0x10ef4444)]),
        borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x4DF59e0b)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lightbulb_outline, size: 15, color: Color(0xFFfbbf24)),
          SizedBox(width: 7),
          Text('РЕКОМЕНДАЦИИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFfbbf24), letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _recTab(s,'save','Сколько копить'),
            _recTab(s,'time','За сколько накоплю'),
          ]),
        ),
        const SizedBox(height: 14),
        if(s.recMode=='save') Row(children: [
          Expanded(child: _recField('Цель',_recTarget,'100000')),
          const SizedBox(width: 8),
          Expanded(child: _recField('Месяцев',_recMonths,'12')),
        ]) else Row(children: [
          Expanded(child: _recField('Цель',_recTarget,'100000')),
          const SizedBox(width: 8),
          Expanded(child: _recField('В месяц',_recMonthly,'5000')),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line)),
          child: result,
        ),
      ]),
    );
  }

  Widget _recTab(AppStore s, String key, String label){
    final on = s.recMode == key;
    return Expanded(child: InkWell(
      onTap: ()=>s.setRecMode(key),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: on ? Colors.white12 : Colors.transparent, borderRadius: BorderRadius.circular(7)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : AppColors.muted)),
      ),
    ));
  }

  Widget _recField(String label, TextEditingController c, String hint){
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 5),
      TextField(
        controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Color(0xFF3a3f4a)),
          filled: true, fillColor: Colors.black26,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFf59e0b))),
        ),
      ),
    ]);
  }

  Widget _recRow(String label, String val){
    return Padding(padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        Text(val, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
      ]));
  }

  List<Widget> _history(AppStore s){
    if(s.txs.isEmpty) return [_empty('Операций пока нет','Добавь доход или расход — они появятся здесь.')];
    final sorted = [...s.txs]..sort((a,b)=>b.date.compareTo(a.date));
    return sorted.map((t)=>TxTile(tx: t)).toList();
  }

  List<Widget> _archive(AppStore s){
    if(s.archivedGoals.isEmpty) return [_empty('Архив пуст','Здесь появятся завершённые цели.')];
    return s.archivedGoals.map((g)=>ArchiveCard(goal: g)).toList();
  }

  Widget _empty(String title, String text){
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line)),
      child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.inbox_outlined, size: 28, color: AppColors.muted)),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
      ]),
    );
  }
}

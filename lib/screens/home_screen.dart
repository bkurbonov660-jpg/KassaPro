import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../models.dart';
import '../widgets/goal_card.dart';
import '../widgets/cur_picker.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final cur = s.defaultCurrency ?? 'RUB';
    final pct = s.totalTarget>0 ? (s.totalCurrent/s.totalTarget*100).clamp(0,100) : 0.0;
    final left = (s.totalTarget-s.totalCurrent).clamp(0,double.infinity);
    final others = ALL_CUR.where((c)=>c!=cur).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('ВСЕГО НАКОПЛЕНО',
                style: TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 0.4, fontWeight: FontWeight.w600))),
              CurPickerButton(),
            ]),
            const SizedBox(height: 8),
            Text(s.fmt(s.totalCurrent), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Text('Из ${s.fmt(s.totalTarget)} · цель', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct/100, minHeight: 8,
                backgroundColor: AppColors.panel2, valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${pct.toStringAsFixed(1)}% от общей цели', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              RichText(text: TextSpan(children: [
                TextSpan(text: s.fmt(left), style: const TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w700)),
                const TextSpan(text: ' осталось', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ])),
            ]),
            const Padding(padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(height: 1, color: AppColors.line)),
            const Row(children: [
              Icon(Icons.swap_horiz, size: 14, color: AppColors.accent),
              SizedBox(width: 7),
              Text('НАКОПЛЕНО ВО ВСЕХ ВАЛЮТАХ',
                style: TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 0.4, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.4,
              children: others.map((c) {
                final v = s.fromRub(s.totalCurrent, c);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Row(children: [
                      Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(c, style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                    ]),
                    const SizedBox(height: 4),
                    Text(s.fmtQuick(v, c), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                );
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _StatCard(icon: Icons.attach_money, color: AppColors.green, label: 'Заработано', value: s.fmt(s.totalEarned))),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(icon: Icons.trending_down, color: AppColors.red, label: 'Потрачено', value: s.fmt(s.totalSpent))),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(0,20,0,12),
          child: Row(children: [
            const Expanded(child: Text('МОИ ЦЕЛИ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
            TextButton.icon(
              onPressed: () => GoalEditorSheet.show(context, null),
              icon: const Icon(Icons.add, size: 14, color: AppColors.accent),
              label: const Text('Добавить', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
          ]),
        ),
        if (s.activeGoals.isEmpty)
          const _EmptyState()
        else
          ...s.activeGoals.take(3).map((g)=>GoalCard(goal: g)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color color; final String label; final String value;
  const _StatCard({required this.icon, required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(
          color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.2),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, style: BorderStyle.solid)),
      child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(
          color: AppColors.panel2, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.track_changes, size: 28, color: AppColors.muted)),
        const SizedBox(height: 14),
        const Text('У тебя пока нет целей', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        const Text('Создай первую цель — накопить на телефон, путешествие или отправить деньги родным.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5)),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: () => GoalEditorSheet.show(context, null),
          icon: const Icon(Icons.add, size: 15),
          label: const Text('Создать цель'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0, textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

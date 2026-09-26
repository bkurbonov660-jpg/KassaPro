import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../main.dart';
import '../widgets/goal_card.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      children: [
        Row(children: [
          const Expanded(child: Text('ВСЕ ЦЕЛИ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
          TextButton.icon(
            onPressed: () => GoalEditorSheet.show(context, null),
            icon: const Icon(Icons.add, size: 14, color: AppColors.accent),
            label: const Text('Добавить', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        if (s.activeGoals.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 40),
            child: Center(child: Text('Целей пока нет', style: TextStyle(color: AppColors.muted))))
        else
          ...s.activeGoals.map((g)=>GoalCard(goal: g)),
      ],
    );
  }
}

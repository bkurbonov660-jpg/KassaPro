import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../models.dart';
import '../main.dart';
import 'icon_pack.dart';

class ArchiveCard extends StatelessWidget {
  final Goal goal;
  const ArchiveCard({super.key, required this.goal});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final doneStr = goal.completedAt != null ? 'Закрыто ${s.fmtDateShort(goal.completedAt!)}' : 'Готово';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Container(width: 3, height: 62, color: AppColors.green),
          Expanded(child: Padding(padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(
                color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(iconFor(goal.icon), size: 18, color: AppColors.green)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(goal.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${s.fmt(goal.target,goal.currency)} · $doneStr',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(6)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, size: 11, color: AppColors.green),
                  SizedBox(width: 4),
                  Text('Готово', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                ]),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

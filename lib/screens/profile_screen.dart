import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../store.dart';
import '../main.dart';
import '../widgets/goal_card.dart';
import '../widgets/tx_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line)),
          child: Column(children: [
            Container(width: 72, height: 72, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.person, color: Colors.white, size: 34)),
            const SizedBox(height: 12),
            const Text('Мой профиль', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('${s.activeGoals.length} активных · ${s.archivedGoals.length} в архиве',
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
        ),
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text('УВЕДОМЛЕНИЯ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
        _MenuTile(
          icon: Icons.notifications_none, title: 'Уведомления',
          sub: s.notificationsEnabled ? 'Включены · напомним о целях' : 'Нажми, чтобы включить',
          trailing: Switch(
            value: s.notificationsEnabled,
            activeColor: AppColors.accent,
            onChanged: (v) async {
              if(!v){ s.notificationsEnabled=false; await s.save(); s.notifyListeners(); return; }
              final android = notifPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
              bool? granted = await android?.requestNotificationsPermission();
              if(granted == true){
                s.notificationsEnabled = true; await s.save(); s.notifyListeners();
                await showNotif('GoalFlow','Уведомления работают! Будем напоминать о целях.');
              } else {
                if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Разреши уведомления в настройках')));
              }
            },
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text('НАСТРОЙКИ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
        _MenuTile(
          icon: Icons.trending_down, title: 'Учитывать расходы в целях',
          sub: s.expensesFromGoals ? 'Включено · списываются' : 'Выключено · расходы отдельно',
          onTap: ()=>s.toggleExpenses(),
        ),
        _MenuTile(
          icon: Icons.language, title: 'Валюта по умолчанию',
          sub: '${s.defaultCurrency} — ${CUR_NAME[s.defaultCurrency]}',
          onTap: ()=>_pickCur(context, s),
        ),
        _MenuTile(icon: Icons.track_changes, title: 'Создать цель',
          sub: 'Добавить новую финансовую цель',
          onTap: ()=>GoalEditorSheet.show(context, null)),
        _MenuTile(icon: Icons.add, title: 'Добавить доход',
          sub: 'Распределить деньги по целям',
          onTap: ()=>TxSheet.show(context, 'income')),
        _MenuTile(icon: Icons.remove, title: 'Добавить расход',
          sub: 'Записать трату',
          onTap: ()=>TxSheet.show(context, 'expense')),
        _MenuTile(icon: Icons.upload_file, title: 'Экспорт данных',
          sub: 'Поделиться JSON-файлом',
          onTap: ()=>_export(context, s)),
        _MenuTile(icon: Icons.delete_outline, title: 'Сбросить всё',
          sub: 'Удалить все данные', red: true,
          onTap: ()=>_reset(context, s)),
      ],
    );
  }

  void _pickCur(BuildContext ctx, AppStore s){
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.panel, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=>Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          const Text('Валюта по умолчанию', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Все суммы будут отображаться в этой валюте', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 9, crossAxisSpacing: 9, childAspectRatio: 1.4,
            children: ALL_CUR.map((c){
              final on = s.defaultCurrency == c;
              return GestureDetector(
                onTap: (){ s.setCurrency(c); Navigator.pop(ctx); },
                child: Container(
                  decoration: BoxDecoration(
                    color: on ? AppColors.accentSoft : AppColors.panel2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: on ? AppColors.accent : AppColors.line),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text('${CUR_SYM[c]} $c', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(CUR_NAME[c]!, style: const TextStyle(fontSize: 10.5, color: AppColors.muted), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            }).toList(),
          ),
        ])),
    );
  }

  Future<void> _export(BuildContext ctx, AppStore s) async {
    final data = jsonEncode({
      'defaultCurrency': s.defaultCurrency,
      'goals': s.goals.map((g)=>g.toJson()).toList(),
      'txs': s.txs.map((t)=>t.toJson()).toList(),
      'rates': s.rates,
    });
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/goalflow-backup.json');
      await f.writeAsString(data);
      await Share.shareXFiles([XFile(f.path)], text: 'GoalFlow backup');
    } catch(e){
      if(ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _reset(BuildContext ctx, AppStore s){
    showDialog(context: ctx, builder: (_)=>AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Сбросить всё?', style: TextStyle(color: AppColors.text)),
      content: const Text('Все цели и операции будут удалены. Это нельзя отменить.',
        style: TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text('Отмена')),
        TextButton(onPressed: () async {
          s.goals.clear(); s.txs.clear();
          await s.save(); s.notifyListeners();
          if(ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Удалить', style: TextStyle(color: AppColors.red))),
      ],
    ));
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon; final String title; final String sub; final VoidCallback? onTap;
  final Widget? trailing; final bool red;
  const _MenuTile({required this.icon, required this.title, required this.sub, this.onTap, this.trailing, this.red=false});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 18, color: red ? AppColors.red : AppColors.muted)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: red ? AppColors.red : AppColors.text)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
          trailing ?? const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }
}

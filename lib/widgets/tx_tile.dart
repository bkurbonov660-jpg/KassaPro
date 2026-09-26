import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../models.dart';
import '../main.dart';
import 'tx_sheet.dart';

class TxTile extends StatelessWidget {
  final TxRecord tx;
  const TxTile({super.key, required this.tx});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final sym = CUR_SYM[tx.cur]!;
    String amountText;
    if(tx.cur=='USD'||tx.cur=='EUR'){ amountText = '$sym${tx.amount.toStringAsFixed(2)}'; }
    else { amountText = '${tx.amount.round()} $sym'; }
    final sign = tx.type=='income' ? '+' : '−';
    final title = tx.type=='income'
      ? (tx.note?.isNotEmpty==true ? tx.note! : (tx.isAuto ? 'Пополнение · все цели' : 'Доход · ${tx.goalTitle ?? "без цели"}'))
      : (tx.affectsGoal ? 'Расход · ${tx.goalTitle ?? ""}' : 'Расход · ${tx.note?.isNotEmpty==true ? tx.note! : "просто расход"}');

    return InkWell(
      onTap: ()=>_openActions(context, s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(
            color: tx.type=='income' ? AppColors.greenSoft : AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(tx.type=='income' ? Icons.add : Icons.remove, size: 16,
              color: tx.type=='income' ? AppColors.green : AppColors.red)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(s.fmtDate(tx.date), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$sign$amountText', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: tx.type=='income' ? AppColors.green : AppColors.red)),
            if(s.defaultCurrency != tx.cur) Padding(padding: const EdgeInsets.only(top: 1),
              child: Text(s.fmt(tx.rub), style: const TextStyle(fontSize: 10.5, color: AppColors.muted))),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.more_horiz, size: 16, color: AppColors.muted),
        ]),
      ),
    );
  }

  void _openActions(BuildContext ctx, AppStore s){
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_)=>Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text(tx.type=='income' ? 'Доход' : 'Расход', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 6),
          Text('${tx.type=='income' ? '+' : '−'}${tx.amount} ${CUR_SYM[tx.cur]} · ${s.fmtDate(tx.date)}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          _btn(ctx, Icons.edit, 'Редактировать', (){
            Navigator.pop(ctx);
            Future.delayed(const Duration(milliseconds: 150), ()=>TxSheet.show(ctx, tx.type, edit: tx));
          }),
          _btn(ctx, Icons.delete_outline, 'Удалить операцию', (){
            Navigator.pop(ctx);
            s.deleteTx(tx.id);
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

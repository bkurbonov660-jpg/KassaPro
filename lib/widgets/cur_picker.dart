import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';
import '../main.dart';

class CurPickerButton extends StatelessWidget {
  const CurPickerButton({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final cur = s.defaultCurrency ?? 'RUB';
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(CUR_FLAG[cur]!, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(cur, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 12, color: AppColors.muted),
        ]),
      ),
    );
  }

  void _open(BuildContext ctx){
    showModalBottomSheet(context: ctx, backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_){
        final s = ctx.read<AppStore>();
        return Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            ...ALL_CUR.map((c){
              final on = s.defaultCurrency == c;
              return InkWell(
                onTap: (){ s.setCurrency(c); Navigator.pop(ctx); },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: on ? AppColors.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Text('${CUR_SYM[c]} $c', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const Spacer(),
                    Text(CUR_NAME[c]!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              );
            }),
          ]),
        );
      });
  }
}

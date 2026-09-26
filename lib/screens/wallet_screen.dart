import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late TextEditingController _ctrl;
  String _from = 'RUB';
  String _to = 'USD';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    final s = context.read<AppStore>();
    _from = s.defaultCurrency ?? 'RUB';
    _to = _from == 'USD' ? 'RUB' : 'USD';
  }

  @override
  void dispose(){ _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final amount = double.tryParse(_ctrl.text) ?? 0;
    final result = amount>0 ? s.fromRub(s.toRub(amount,_from),_to) : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16,16,16,100),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Expanded(child: Row(children: [
              _dot(s.ratesStatus),
              const SizedBox(width: 8),
              Flexible(child: Text(
                s.ratesStatus=='ok' && s.ratesUpdated!=null
                  ? 'Обновлено: ${s.fmtDate(s.ratesUpdated!)}'
                  : s.ratesStatus=='error'
                    ? 'Ошибка сети · курсы по умолчанию'
                    : 'Курсы по умолчанию',
                style: const TextStyle(fontSize: 12, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
            ])),
            InkWell(
              onTap: () async {
                final ok = await s.fetchRates();
                if(!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Курсы обновлены ✓' : 'Не удалось обновить'),
                  behavior: SnackBarBehavior.floating, backgroundColor: AppColors.panel2));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh, size: 12, color: AppColors.text),
                  SizedBox(width: 5),
                  Text('Обновить', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line)),
          child: Column(children: [
            _field('Из', _ctrl, _from, (c)=>setState(()=>_from=c)),
            const SizedBox(height: 8),
            Center(child: InkWell(
              onTap: () => setState((){final a=_from;_from=_to;_to=a;}),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 3)),
                child: const Icon(Icons.swap_vert, size: 16, color: Colors.white)),
            )),
            const SizedBox(height: 8),
            _fieldRO('В', result, _to, (c)=>setState(()=>_to=c)),
          ]),
        ),
        const Padding(padding: EdgeInsets.only(top: 20, bottom: 12),
          child: Text('КУРСЫ К РУБЛЮ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5))),
        ...['USD','EUR','CNY','TJS'].map((c)=>Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(CUR_NAME[c]!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
              const SizedBox(height: 1),
              Text('1 $c = ${s.rates[c]!.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ])),
            Text('${s.rates[c]!.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
          ]),
        )),
      ],
    );
  }

  Widget _dot(String status){
    Color c = AppColors.green;
    if(status=='stale') c = AppColors.orange;
    if(status=='error') c = AppColors.red;
    return Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }

  Widget _field(String label, TextEditingController c, String cur, ValueChanged<String> onCur){
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Expanded(child: TextField(
            controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_)=>setState((){}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              hintText: '0', hintStyle: TextStyle(color: Color(0xFF3a3f4a))),
          )),
          _curChip(cur, onCur),
        ]),
      ),
    ]);
  }

  Widget _fieldRO(String label, double value, String cur, ValueChanged<String> onCur){
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(value.toStringAsFixed(2), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
          )),
          _curChip(cur, onCur),
        ]),
      ),
    ]);
  }

  Widget _curChip(String cur, ValueChanged<String> onCur){
    return PopupMenuButton<String>(
      onSelected: onCur,
      color: AppColors.panel2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => ALL_CUR.map((c)=>PopupMenuItem(value: c,
        child: Row(children: [
          Text(CUR_FLAG[c]!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text('${CUR_SYM[c]} $c', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
          const Spacer(),
          Text(CUR_NAME[c]!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(8)),
        child: Text(cur, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
      ),
    );
  }
}

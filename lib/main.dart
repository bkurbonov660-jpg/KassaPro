import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/models.dart';
import 'utils/l10n.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KassaproApp());
}

class AppColors {
  static const bg       = Color(0xFF0F172A);
  static const surface  = Color(0xFF1E293B);
  static const card     = Color(0xFF334155);
  static const accent   = Color(0xFF3B82F6);
  static const warn     = Color(0xFFF59E0B);
  static const danger   = Color(0xFFEF4444);
  static const success  = Color(0xFF10B981);
  static const textPri  = Color(0xFFF8FAFC);
  static const textSec  = Color(0xFF94A3B8);
}

class KassaproApp extends StatelessWidget {
  const KassaproApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KassaPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(surface: AppColors.surface, primary: AppColors.accent),
      ),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _ready = false, _langSet = false, _trainingDone = false;
  String _lang = 'ru';
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final savedL = p.getString('kp_lang');
    final tDone = p.getBool('kp_training') ?? false;
    setState(() { _ready = true; _lang = savedL ?? 'ru'; _langSet = savedL != null; _trainingDone = tDone; });
  }

  void _confirmLang(String lang) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('kp_lang', lang);
    setState(() { _lang = lang; _langSet = true; });
  }

  void _finishTraining() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('kp_training', true);
    setState(() => _trainingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
    if (!_langSet) return LanguageSelectScreen(onConfirm: _confirmLang);
    if (!_trainingDone) return TrainingScreen(onFinish: _finishTraining, lang: _lang);
    return KassaHomeScreen(lang: _lang);
  }
}

class TrainingScreen extends StatelessWidget {
  final VoidCallback onFinish;
  final String lang;
  const TrainingScreen({super.key, required this.onFinish, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(24), child: Text('Добро пожаловать в KassaPro!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPri), textAlign: TextAlign.center)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _slide(Icons.qr_code_scanner, 'Сканер и добавление', 'В разделе "Товары" большие кнопки. Нажмите "Сканер", чтобы быстро добавить товар по штрих-коду.'),
                  _slide(Icons.delete_sweep, 'Удаление товаров', 'Просто смахните товар влево в списке, чтобы удалить его. Или нажмите иконку корзины при редактировании.'),
                  _slide(Icons.cloud_sync, 'Передача смены и данных', 'В настройках есть "Резервная копия". Скопируйте длинный код и отправьте напарнику. Он вставит его, и вся база (товары, долги) появится у него!'),
                  _slide(Icons.calendar_month, 'Календарь продаж', 'Следите за историей продаж прямо в удобном календаре. Нажимайте на дни, чтобы видеть выручку.'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: onFinish, child: const Text('Я всё понял, начать!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _slide(IconData ic, String title, String desc) => Container(
    margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
    child: Row(children: [
      Icon(ic, size: 40, color: AppColors.accent), const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPri)), const SizedBox(height: 4),
        Text(desc, style: const TextStyle(color: AppColors.textSec, fontSize: 13, height: 1.4)),
      ]))
    ]),
  );
}

class LanguageSelectScreen extends StatelessWidget {
  final void Function(String) onConfirm;
  const LanguageSelectScreen({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)]), child: const Icon(Icons.point_of_sale_rounded, size: 80, color: AppColors.accent)),
            const SizedBox(height: 50),
            _btn('Русский (₽)', () => onConfirm('ru')), const SizedBox(height: 16),
            _btn('Тоҷикӣ (сом.)', () => onConfirm('tj')), const SizedBox(height: 16),
            _btn('English (\$)', () => onConfirm('en')),
          ],
        ),
      ),
    );
  }
  Widget _btn(String name, VoidCallback onTap) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, foregroundColor: AppColors.textPri, minimumSize: const Size(260, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: onTap, child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
}

class KassaHomeScreen extends StatefulWidget {
  final String lang;
  const KassaHomeScreen({super.key, required this.lang});
  @override
  State<KassaHomeScreen> createState() => _KassaHomeScreenState();
}

class _KassaHomeScreenState extends State<KassaHomeScreen> {
  int _tab = 0;
  late String _lang, _currency;
  final _uuid = const Uuid();
  List<Product> _products = [];
  List<CartItem> _cart = [];
  List<SaleRecord> _sales = [];
  List<DebtRecord> _debts = [];
  bool _shiftOpen = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() { super.initState(); _lang = widget.lang; _currency = getCurrency(_lang); _selectedDay = _focusedDay; _loadAll(); }

  String _t(String key) => t(key, _lang);

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    try {
      _products = (p.getStringList('kp_products') ?? []).map((s) => Product.fromJson(jsonDecode(s))).toList();
      _sales = (p.getStringList('kp_sales') ?? []).map((s) {
        final j = jsonDecode(s);
        final items = (j['items'] as List).map((item) => CartItem(product: Product(id: item['productId'], name: item['productName'], price: (item['price'] as num).toDouble(), costPrice: 0, quantity: item['qty']), qty: item['qty'])).toList();
        return SaleRecord(id: j['id'], dateTime: DateTime.parse(j['dateTime']), items: items, totalAmount: (j['totalAmount'] as num).toDouble());
      }).toList();
      _debts = (p.getStringList('kp_debts') ?? []).map((s) => DebtRecord.fromJson(jsonDecode(s))).toList();
      _shiftOpen = p.getBool('kp_shiftOpen') ?? false;
    } catch(e){}
    setState(() {});
  }

  Future<void> _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('kp_products', _products.map((x) => jsonEncode(x.toJson())).toList());
    await p.setStringList('kp_sales', _sales.map((x) => jsonEncode(x.toJson())).toList());
    await p.setStringList('kp_debts', _debts.map((x) => jsonEncode(x.toJson())).toList());
    await p.setBool('kp_shiftOpen', _shiftOpen);
  }

  void _showSnack(String msg, {Color color = AppColors.accent, IconData icon = Icons.info_outline}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16)));
  }

  void _openBackupDialog() {
    final importCtrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (_) {
      return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Резервная копия', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 24),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), icon: const Icon(Icons.copy), label: const Text('СКОПИРОВАТЬ ДАННЫЕ', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () {
          final data = {'p': _products.map((e)=>e.toJson()).toList(), 's': _sales.map((e)=>e.toJson()).toList(), 'd': _debts.map((e)=>e.toJson()).toList()};
          final encoded = base64Encode(utf8.encode(jsonEncode(data)));
          Clipboard.setData(ClipboardData(text: encoded));
          Navigator.pop(context); _showSnack('Код скопирован! Отправьте его напарнику', color: AppColors.success);
        }),
        const SizedBox(height: 24), const Text('Или вставьте код для восстановления:', style: TextStyle(color: AppColors.textSec)), const SizedBox(height: 8),
        TextField(controller: importCtrl, maxLines: 3, decoration: InputDecoration(hintText: 'Вставьте длинный код сюда...', filled: true, fillColor: AppColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))), const SizedBox(height: 16),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.warn, foregroundColor: Colors.black, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('ВОССТАНОВИТЬ (Заменит базу)', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () {
          try {
            final decoded = jsonDecode(utf8.decode(base64Decode(importCtrl.text)));
            setState(() {
              _products = (decoded['p'] as List).map((j)=>Product.fromJson(j)).toList();
              _debts = (decoded['d'] as List).map((j)=>DebtRecord.fromJson(j)).toList();
              _sales = (decoded['s'] as List).map((j){
                final items = (j['items'] as List).map((i)=>CartItem(product: Product(id: i['productId'], name: i['productName'], price: (i['price'] as num).toDouble(), costPrice: 0, quantity: i['qty']), qty: i['qty'])).toList();
                return SaleRecord(id: j['id'], dateTime: DateTime.parse(j['dateTime']), items: items, totalAmount: (j['totalAmount'] as num).toDouble());
              }).toList();
            }); _saveAll(); Navigator.pop(context); _showSnack('Данные успешно восстановлены!', color: AppColors.success);
          } catch(e) { _showSnack('Ошибка! Неверный код.', color: AppColors.danger); }
        }), const SizedBox(height: 32),
      ]));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(extendBody: true, body: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _buildCurrentTab()), bottomNavigationBar: _buildNavBar());
  }

  Widget _buildCurrentTab() {
    switch (_tab) { case 0: return _buildCashier(); case 1: return _buildProducts(); case 2: return _buildCalendarHistory(); case 3: return _buildDebts(); case 4: return _buildMenu(); default: return const SizedBox.shrink(); }
  }

  Widget _buildNavBar() {
    final items = [(Icons.point_of_sale_rounded, _t('navCash')), (Icons.inventory_2_rounded, _t('navProducts')), (Icons.calendar_month_rounded, _t('navHistory')), (Icons.people_rounded, _t('navDebts')), (Icons.grid_view_rounded, _t('navShift'))];
    return Container(margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(height: 70, decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(items.length, (i) {
      final active = _tab == i;
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _tab = i), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: active ? AppColors.accent.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [Icon(items[i].$1, color: active ? AppColors.accent : AppColors.textSec, size: active ? 26 : 22), const SizedBox(height: 4), Text(items[i].$2, style: TextStyle(fontSize: 10, color: active ? AppColors.accent : AppColors.textSec, fontWeight: active ? FontWeight.bold : FontWeight.normal))])));
    }))))));
  }

  Widget _buildCashier() {
    final filtered = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || p.barcode.contains(_searchQuery)).toList();
    return SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchCtrl, onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: _t('search'), prefixIcon: const Icon(Icons.search, color: AppColors.textSec), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
      Expanded(child: GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.9, mainAxisSpacing: 12, crossAxisSpacing: 12), itemCount: filtered.length, itemBuilder: (_, i) {
        final p = filtered[i]; bool outOfStock = p.quantity <= 0;
        return GestureDetector(onTap: () {
          if (!_shiftOpen) { _showSnack('Сначала откройте смену в Меню!', color: AppColors.warn); return; }
          if (outOfStock) { _showSnack('Товар закончился!', color: AppColors.danger); return; }
          setState(() { final idx = _cart.indexWhere((c) => c.product.id == p.id); if (idx >= 0) { if (_cart[idx].qty < p.quantity) _cart[idx].qty++; } else _cart.add(CartItem(product: p)); });
        }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: outOfStock ? AppColors.danger.withOpacity(0.5) : Colors.transparent)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: outOfStock ? AppColors.danger.withOpacity(0.2) : AppColors.surface, borderRadius: BorderRadius.circular(8)), child: Text('${_t("stock")}: ${p.quantity}', style: TextStyle(color: outOfStock ? AppColors.danger : AppColors.textSec, fontSize: 11, fontWeight: FontWeight.bold))), const Spacer(), Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text('${p.price} $_currency', style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w900))])));
      })),
      if (_cart.isNotEmpty) Container(margin: const EdgeInsets.all(16).copyWith(bottom: 85), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${_t('cart')} (${_cart.length})', style: const TextStyle(color: AppColors.textSec, fontWeight: FontWeight.bold)), Text('${_cart.fold(0.0, (s, c) => s + c.total)} $_currency', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.success))]), const SizedBox(height: 12), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () {
        final sale = SaleRecord(id: _uuid.v4(), dateTime: DateTime.now(), items: List.from(_cart), totalAmount: _cart.fold(0.0, (s, c) => s + c.total));
        for (final item in _cart) { final pi = _products.indexWhere((p) => p.id == item.product.id); if (pi >= 0) _products[pi].quantity -= item.qty; }
        setState(() { _sales.insert(0, sale); _cart.clear(); });
        _saveAll(); _showSnack('Продано!', color: AppColors.success);
      }, child: Text(_t('sell').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)))]))
    ]));
  }

  Widget _buildProducts() {
    return SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: InkWell(onTap: () => _productDialog(), borderRadius: BorderRadius.circular(20), child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accent.withOpacity(0.3))), child: Column(children: [const Icon(Icons.edit_document, size: 32, color: AppColors.accent), const SizedBox(height: 8), Text(_t('addProduct'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 12), textAlign: TextAlign.center)])))), const SizedBox(width: 12),
        Expanded(child: InkWell(onTap: () async { var res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SimpleBarcodeScannerPage())); if (res is String && res != '-1') _productDialog(code: res); }, borderRadius: BorderRadius.circular(20), child: Ink(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.success.withOpacity(0.3))), child: Column(children: [const Icon(Icons.qr_code_scanner, size: 32, color: AppColors.success), const SizedBox(height: 8), Text(_t('scanProduct'), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12), textAlign: TextAlign.center)])))),
      ])),
      Expanded(child: ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 100), itemCount: _products.length, separatorBuilder: (_,__) => const SizedBox(height: 10), itemBuilder: (_, i) => Dismissible(key: Key(_products[i].id), direction: DismissDirection.endToStart, background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.delete, color: Colors.white)), onDismissed: (_) { setState(() => _products.removeAt(i)); _saveAll(); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.inventory, color: AppColors.accent)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_products[i].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 4), Text('${_products[i].price} $_currency', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Остаток', style: TextStyle(color: AppColors.textSec, fontSize: 10)), Text('${_products[i].quantity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))])])))))
    ]));
  }

  void _productDialog({String? code}) {
    final nCtrl = TextEditingController(), pCtrl = TextEditingController(), qCtrl = TextEditingController(), bCtrl = TextEditingController(text: code ?? '');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Новый товар', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 24),
      TextField(controller: nCtrl, decoration: _inputDeco(_t('productName'), Icons.label)), const SizedBox(height: 12),
      Row(children: [Expanded(child: TextField(controller: pCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(_t('sellingPrice'), Icons.payments))), const SizedBox(width: 12), Expanded(child: TextField(controller: qCtrl, keyboardType: TextInputType.number, decoration: _inputDeco(_t('stock'), Icons.layers)))]), const SizedBox(height: 12),
      TextField(controller: bCtrl, decoration: _inputDeco(_t('barcode'), Icons.qr_code)), const SizedBox(height: 24),
      ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { if (nCtrl.text.isEmpty || pCtrl.text.isEmpty) { _showSnack('Заполните название и цену', color: AppColors.danger); return; } setState(() => _products.add(Product(id: _uuid.v4(), name: nCtrl.text, price: double.tryParse(pCtrl.text) ?? 0, costPrice: 0, quantity: int.tryParse(qCtrl.text) ?? 0, barcode: bCtrl.text))); _saveAll(); Navigator.pop(context); _showSnack('Товар сохранен'); }, child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 32),
    ])));
  }

  Widget _buildCalendarHistory() {
    final selectedSales = _sales.where((s) => s.dateTime.year == _selectedDay!.year && s.dateTime.month == _selectedDay!.month && s.dateTime.day == _selectedDay!.day).toList();
    final dayTotal = selectedSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    return SafeArea(child: Column(children: [
      Container(margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(24)), child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.twoWeeks, startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (sDay, fDay) => setState(() { _selectedDay = sDay; _focusedDay = fDay; }),
        calendarStyle: const CalendarStyle(selectedDecoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle), todayDecoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle)),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Выручка за день:', style: TextStyle(color: AppColors.textSec, fontWeight: FontWeight.bold)), Text('${dayTotal.toStringAsFixed(0)} $_currency', style: const TextStyle(color: AppColors.success, fontSize: 20, fontWeight: FontWeight.w900))])),
      Expanded(child: selectedSales.isEmpty ? const Center(child: Text('В этот день продаж не было', style: TextStyle(color: AppColors.textSec))) : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 100), itemCount: selectedSales.length, separatorBuilder: (_,__) => const SizedBox(height: 10), itemBuilder: (_, i) {
        final s = selectedSales[i]; return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${s.totalAmount} $_currency', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success)), const SizedBox(height: 4), Text('${s.dateTime.hour}:${s.dateTime.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: AppColors.textSec, fontSize: 12))]), Text('${s.items.length} поз.', style: const TextStyle(color: AppColors.textPri))]));
      }))
    ]));
  }

  Widget _buildDebts() {
    return SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_t('debtors'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), FloatingActionButton.small(backgroundColor: AppColors.accent, onPressed: () {
        final nCtrl = TextEditingController(), aCtrl = TextEditingController();
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppColors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 32), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Выдать в долг', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 24),
          TextField(controller: nCtrl, decoration: _inputDeco('Имя клиента', Icons.person)), const SizedBox(height: 12),
          TextField(controller: aCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма долга', Icons.money_off)), const SizedBox(height: 24),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { final amount = double.tryParse(aCtrl.text) ?? 0; if (nCtrl.text.isNotEmpty && amount > 0) { setState(() => _debts.insert(0, DebtRecord(id: _uuid.v4(), clientName: nCtrl.text, phone: '', amount: amount, createdAt: DateTime.now()))); _saveAll(); Navigator.pop(context); _showSnack('Долг записан'); } }, child: const Text('СОХРАНИТЬ', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 32),
        ])));
      }, child: const Icon(Icons.person_add, color: Colors.white))])),
      Expanded(child: _debts.isEmpty ? const Center(child: Text('Отлично! Должников нет.', style: TextStyle(color: AppColors.textSec))) : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 100), itemCount: _debts.length, separatorBuilder: (_,__) => const SizedBox(height: 10), itemBuilder: (_, i) {
        final d = _debts[i]; return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)), child: Row(children: [CircleAvatar(backgroundColor: d.isPaid ? AppColors.success.withOpacity(0.2) : AppColors.warn.withOpacity(0.2), child: Text(d.clientName[0].toUpperCase(), style: TextStyle(color: d.isPaid ? AppColors.success : AppColors.warn, fontWeight: FontWeight.bold))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.clientName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: d.isPaid ? TextDecoration.lineThrough : null, color: d.isPaid ? AppColors.textSec : AppColors.textPri)), const SizedBox(height: 4), Text('${d.createdAt.day}.${d.createdAt.month}.${d.createdAt.year}', style: const TextStyle(color: AppColors.textSec, fontSize: 12))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${d.amount} $_currency', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: d.isPaid ? AppColors.textSec : AppColors.warn)), const SizedBox(height: 8), if (!d.isPaid) GestureDetector(onTap: () { setState(() => d.isPaid = true); _saveAll(); _showSnack('Долг погашен', color: AppColors.success); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)), child: const Text('Погасить', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))) else const Text('Оплачено', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold))])]));
      }))
    ]));
  }

  Widget _buildMenu() {
    return SafeArea(child: ListView(padding: const EdgeInsets.all(20).copyWith(bottom: 100), children: [
      const Text('Меню', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: LinearGradient(colors: [_shiftOpen ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1), AppColors.surface]), borderRadius: BorderRadius.circular(24), border: Border.all(color: _shiftOpen ? AppColors.success.withOpacity(0.3) : AppColors.danger.withOpacity(0.3))), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.circle, size: 16, color: _shiftOpen ? AppColors.success : AppColors.danger), const SizedBox(width: 12), Text(_shiftOpen ? 'Смена ОТКРЫТА' : 'Смена ЗАКРЫТА', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]), const SizedBox(height: 24), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _shiftOpen ? AppColors.surface : AppColors.accent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { setState(() => _shiftOpen = !_shiftOpen); _saveAll(); _showSnack(_shiftOpen ? 'Смена открыта' : 'Смена закрыта', color: _shiftOpen ? AppColors.success : AppColors.warn); }, child: Text(_shiftOpen ? _t('closeShift').toUpperCase() : _t('openShift').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)))])), const SizedBox(height: 32),
      const Text('Настройки', style: TextStyle(color: AppColors.textSec, fontWeight: FontWeight.bold, letterSpacing: 1.2)), const SizedBox(height: 12),
      _menuTile(Icons.language, 'Сменить язык (${_lang.toUpperCase()})', () => setState(() { _lang = _lang == 'ru' ? 'tj' : (_lang == 'tj' ? 'en' : 'ru'); _currency = getCurrency(_lang); _saveAll(); })),
      _menuTile(Icons.cloud_sync, _t('exportImport'), _openBackupDialog, color: AppColors.success),
      _menuTile(Icons.school, _t('training'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingScreen(onFinish: () => Navigator.pop(context), lang: _lang)))),
      _menuTile(Icons.delete_forever, _t('clearDB'), () { setState(() { _products.clear(); _sales.clear(); _debts.clear(); _cart.clear(); }); _saveAll(); _showSnack('Всё удалено', color: AppColors.danger); }, color: AppColors.danger),
      const SizedBox(height: 32),
      const Text('Команда разработчиков', style: TextStyle(color: AppColors.textSec, fontWeight: FontWeight.bold, letterSpacing: 1.2)), const SizedBox(height: 12),
      _devTile('Курбонов Бахтиёр', 'Главный разработчик (Lead Dev)'),
      _devTile('Серафим Демидов', 'Дизайн интерфейсов (UI/UX)'),
      _devTile('Дмитрий Соколов', 'Разработка БД и логики'),
      _devTile('Илья Романов', 'Оптимизация сканера и железа'),
      _devTile('Леонид Фадеев', 'Тестирование (QA)'),
      _devTile('Арсений Полянский', 'Локализация и техподдержка'),
    ]));
  }

  Widget _menuTile(IconData ic, String title, VoidCallback onTap, {Color? color}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: ListTile(onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), tileColor: AppColors.card, leading: Icon(ic, color: color ?? AppColors.accent), title: Text(title, style: TextStyle(color: color ?? AppColors.textPri, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.chevron_right, color: AppColors.textSec)));
  Widget _devTile(String name, String role) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.person, color: AppColors.textSec, size: 20), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPri)), Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textSec))]))]));
  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(hintText: hint, filled: true, fillColor: AppColors.bg, prefixIcon: Icon(icon, color: AppColors.textSec), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));
}

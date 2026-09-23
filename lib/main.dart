import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/history.dart';
import 'models/calculator_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MiCalculatorApp());
}

class MiColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const keyGray = Color(0xFF1E1E1E);
  static const keyOrange = Color(0xFFFF6E00);
  static const textPri = Color(0xFFFFFFFF);
  static const textSec = Color(0xFF888888);
  static const divider = Color(0xFF262626);

  static const bgLight = Color(0xFFF5F5F5);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const keyGrayLight = Color(0xFFE8E8E8);
  static const textPriLight = Color(0xFF1A1A1A);
  static const textSecLight = Color(0xFF9A9A9A);
  static const dividerLight = Color(0xFFE0E0E0);
}

/// Simple app-wide theme + favorites notifier so every screen can react
/// without a heavier state-management dependency.
class AppState extends ChangeNotifier {
  bool isDark = true;
  Set<String> favoriteConverters = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    isDark = p.getBool('mi_theme_dark') ?? true;
    favoriteConverters = (p.getStringList('mi_fav_converters') ?? []).toSet();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('mi_theme_dark', isDark);
  }

  Future<void> toggleFavorite(String id) async {
    if (favoriteConverters.contains(id)) {
      favoriteConverters.remove(id);
    } else {
      favoriteConverters.add(id);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('mi_fav_converters', favoriteConverters.toList());
  }
}

final appState = AppState();

class MiCalculatorApp extends StatefulWidget {
  const MiCalculatorApp({super.key});
  @override
  State<MiCalculatorApp> createState() => _MiCalculatorAppState();
}

class _MiCalculatorAppState extends State<MiCalculatorApp> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChange);
    appState.load();
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final dark = appState.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: dark ? MiColors.bg : MiColors.bgLight,
    ));
    return MaterialApp(
      title: 'Калькулятор',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: dark ? MiColors.bg : MiColors.bgLight,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0; // 0: Калькулятор, 1: Конвертер
  bool _scientific = false;
  String _expression = '';
  String _liveResult = '';
  List<CalcHistoryItem> _history = [];

  Color get bg => appState.isDark ? MiColors.bg : MiColors.bgLight;
  Color get surface => appState.isDark ? MiColors.surface : MiColors.surfaceLight;
  Color get keyGray => appState.isDark ? MiColors.keyGray : MiColors.keyGrayLight;
  Color get textPri => appState.isDark ? MiColors.textPri : MiColors.textPriLight;
  Color get textSec => appState.isDark ? MiColors.textSec : MiColors.textSecLight;
  Color get divider => appState.isDark ? MiColors.divider : MiColors.dividerLight;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('mi_calc_history') ?? [];
    setState(() {
      _history = list.map((e) => CalcHistoryItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('mi_calc_history', _history.map((e) => jsonEncode(e.toJson())).toList());
  }

  void _copyResult() {
    final toCopy = _liveResult.isNotEmpty ? _liveResult : _expression;
    if (toCopy.isEmpty) return;
    Clipboard.setData(ClipboardData(text: toCopy));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Скопировано'), backgroundColor: surface, duration: const Duration(seconds: 1)),
    );
  }

  void _onKey(String label) {
    HapticFeedback.lightImpact();
    setState(() {
      if (label == 'AC') {
        _expression = '';
        _liveResult = '';
      } else if (label == 'DEL') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
          _calculateLive();
        }
      } else if (label == '=') {
        if (_expression.isNotEmpty) {
          final resVal = CalcEngine.evaluate(_expression);
          final resStr = CalcEngine.formatNumber(resVal);
          _history.insert(0, CalcHistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            expression: _expression,
            result: resStr,
            timestamp: DateTime.now(),
          ));
          _saveHistory();
          _expression = resStr;
          _liveResult = '';
        }
      } else if (label == '+/-') {
        if (_expression.isNotEmpty) {
          if (_expression.startsWith('-')) {
            _expression = _expression.substring(1);
          } else {
            _expression = '-$_expression';
          }
          _calculateLive();
        }
      } else if (label == 'π') {
        _expression += '3.14159265';
        _calculateLive();
      } else if (label == 'e') {
        _expression += '2.71828182';
        _calculateLive();
      } else if (['sin', 'cos', 'tan', '√', 'x²', 'log', 'ln', '1/x', '!'].contains(label)) {
        final current = double.tryParse(_liveResult.isNotEmpty ? _liveResult : _expression) ?? CalcEngine.evaluate(_expression);
        final res = CalcEngine.applyFunction(label, current);
        _expression = CalcEngine.formatNumber(res);
        _liveResult = '';
      } else if (label == '^') {
        _expression += '×';
        _calculateLive();
      } else {
        final ops = ['+', '−', '×', '÷', '%'];
        if (ops.contains(label) && _expression.isNotEmpty && ops.contains(_expression[_expression.length - 1])) {
          _expression = _expression.substring(0, _expression.length - 1) + label;
        } else {
          _expression += label;
        }
        _calculateLive();
      }
    });
  }

  void _calculateLive() {
    if (_expression.contains('+') || _expression.contains('−') || _expression.contains('×') || _expression.contains('÷') || _expression.contains('%')) {
      final res = CalcEngine.evaluate(_expression);
      _liveResult = CalcEngine.formatNumber(res);
    } else {
      _liveResult = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => appState.toggleTheme(),
                    child: Icon(appState.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: textSec, size: 22),
                  ),
                  Row(
                    children: [
                      _tabHeader('Калькулятор', 0),
                      const SizedBox(width: 20),
                      _tabHeader('Конвертер', 1),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: textSec),
                    color: surface,
                    onSelected: (val) {
                      if (val == 'history') _openHistorySheet();
                      if (val == 'sci') setState(() => _scientific = !_scientific);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'history', child: Text('История')),
                      PopupMenuItem(value: 'sci', child: Text(_scientific ? 'Обычный режим' : 'Научный режим')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -200 && _activeTab == 0) {
                    setState(() => _activeTab = 1);
                  } else if (details.primaryVelocity! > 200 && _activeTab == 1) {
                    setState(() => _activeTab = 0);
                  }
                },
                child: _activeTab == 0 ? _buildCalculatorView() : const ConverterGridView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabHeader(String title, int idx) {
    final active = _activeTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = idx),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? textPri : textSec,
        ),
      ),
    );
  }

  Widget _buildCalculatorView() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: _copyResult,
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expression.isEmpty ? '0' : _expression,
                      style: TextStyle(
                        fontSize: _expression.length > 10 ? 36 : 56,
                        fontWeight: FontWeight.w300,
                        color: textPri,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.right,
                    ),
                    if (_liveResult.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '= $_liveResult',
                        style: TextStyle(fontSize: 24, color: textSec),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text('Удерживайте для копирования', style: TextStyle(fontSize: 11, color: textSec.withOpacity(0.6))),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              if (_scientific) ...[
                _btnRow(['sin', 'cos', 'tan', '√'], small: true),
                const SizedBox(height: 10),
                _btnRow(['log', 'ln', 'x²', '!'], small: true),
                const SizedBox(height: 10),
                _btnRow(['π', 'e', '1/x', '^'], small: true),
                const SizedBox(height: 10),
              ],
              _btnRow(['AC', 'DEL', '%', '÷']),
              const SizedBox(height: 10),
              _btnRow(['7', '8', '9', '×']),
              const SizedBox(height: 10),
              _btnRow(['4', '5', '6', '−']),
              const SizedBox(height: 10),
              _btnRow(['1', '2', '3', '+']),
              const SizedBox(height: 10),
              _btnRow(['+/-', '0', '.', '=']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btnRow(List<String> labels, {bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels.map((l) => _buildKeyBtn(l, small: small)).toList(),
    );
  }

  Widget _buildKeyBtn(String label, {bool small = false}) {
    final isEq = label == '=';
    final isOp = ['AC', 'DEL', '%', '÷', '×', '−', '+', '^'].contains(label);

    Color bg = isEq ? MiColors.keyOrange : keyGray;
    Color fg = isEq ? Colors.white : (isOp ? MiColors.keyOrange : textPri);

    return SizedBox(
      width: small ? 76 : 76,
      height: small ? 52 : 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 16 : 22)),
        ),
        onPressed: () => _onKey(label),
        child: label == 'DEL'
            ? Icon(Icons.backspace_outlined, size: small ? 18 : 24)
            : Text(label, style: TextStyle(fontSize: small ? 16 : 26, fontWeight: FontWeight.w400)),
      ),
    );
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('История вычислений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPri)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: MiColors.keyOrange),
                    onPressed: () {
                      setState(() => _history.clear());
                      setLocal(() {});
                      _saveHistory();
                    },
                  ),
                ],
              ),
              Divider(color: divider),
              Expanded(
                child: _history.isEmpty
                    ? Center(child: Text('История пуста', style: TextStyle(color: textSec)))
                    : ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (_, i) {
                          final item = _history[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.expression, style: TextStyle(color: textSec, fontSize: 14)),
                            subtitle: Text('= ${item.result}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPri)),
                            trailing: Text(DateFormat('HH:mm').format(item.timestamp), style: TextStyle(color: textSec, fontSize: 11)),
                            onTap: () {
                              setState(() => _expression = item.result);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConverterGridView extends StatefulWidget {
  const ConverterGridView({super.key});
  @override
  State<ConverterGridView> createState() => _ConverterGridViewState();
}

class _ConverterGridViewState extends State<ConverterGridView> {
  Color get textPri => appState.isDark ? MiColors.textPri : MiColors.textPriLight;
  Color get textSec => appState.isDark ? MiColors.textSec : MiColors.textSecLight;

  static const List<Map<String, dynamic>> categories = [
    {'title': 'Валюта', 'icon': Icons.currency_exchange, 'id': 'currency'},
    {'title': 'Длина', 'icon': Icons.straighten, 'id': 'length'},
    {'title': 'Масса', 'icon': Icons.fitness_center, 'id': 'mass'},
    {'title': 'Площадь', 'icon': Icons.grid_view, 'id': 'area'},
    {'title': 'Время', 'icon': Icons.access_time, 'id': 'time'},
    {'title': 'Данные', 'icon': Icons.dns_outlined, 'id': 'data'},
    {'title': 'Скидка', 'icon': Icons.local_offer_outlined, 'id': 'discount'},
    {'title': 'Объем', 'icon': Icons.view_in_ar, 'id': 'volume'},
    {'title': 'Система\nсчисления', 'icon': Icons.tag, 'id': 'radix'},
    {'title': 'Скорость', 'icon': Icons.speed, 'id': 'speed'},
    {'title': 'Температура', 'icon': Icons.thermostat, 'id': 'temp'},
    {'title': 'ИМТ', 'icon': Icons.person_outline, 'id': 'bmi'},
  ];

  @override
  Widget build(BuildContext context) {
    final favs = categories.where((c) => appState.favoriteConverters.contains(c['id'])).toList();
    final rest = categories.where((c) => !appState.favoriteConverters.contains(c['id'])).toList();
    final ordered = [...favs, ...rest];

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        mainAxisSpacing: 24,
        crossAxisSpacing: 16,
      ),
      itemCount: ordered.length,
      itemBuilder: (_, i) {
        final cat = ordered[i];
        final isFav = appState.favoriteConverters.contains(cat['id']);
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => GenericConverterPage(title: cat['title'] as String, type: cat['id'] as String),
          )),
          onLongPress: () => appState.toggleFavorite(cat['id'] as String),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(cat['icon'] as IconData, size: 36, color: textPri),
                  const SizedBox(height: 12),
                  Text(
                    cat['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textPri, height: 1.2),
                  ),
                ],
              ),
              if (isFav)
                Positioned(
                  top: -4,
                  right: 8,
                  child: Icon(Icons.star, size: 14, color: MiColors.keyOrange),
                ),
            ],
          ),
        );
      },
    );
  }
}

class GenericConverterPage extends StatefulWidget {
  final String title;
  final String type;
  const GenericConverterPage({super.key, required this.title, required this.type});

  @override
  State<GenericConverterPage> createState() => _GenericConverterPageState();
}

class _GenericConverterPageState extends State<GenericConverterPage> {
  String _input = '1';
  String _unitFrom = '';
  String _unitTo = '';
  List<String> _units = [];

  final _discountCtrl = TextEditingController(text: '10');
  final _weightCtrl = TextEditingController(text: '70');
  final _heightCtrl = TextEditingController(text: '175');

  Color get bg => appState.isDark ? MiColors.bg : MiColors.bgLight;
  Color get surface => appState.isDark ? MiColors.surface : MiColors.surfaceLight;
  Color get keyGray => appState.isDark ? MiColors.keyGray : MiColors.keyGrayLight;
  Color get textPri => appState.isDark ? MiColors.textPri : MiColors.textPriLight;
  Color get textSec => appState.isDark ? MiColors.textSec : MiColors.textSecLight;
  Color get divider => appState.isDark ? MiColors.divider : MiColors.dividerLight;

  @override
  void initState() {
    super.initState();
    _initUnits();
  }

  // Fix: _unitTo must be a single unit string (the second entry by default),
  // never the whole _units list.
  void _initUnits() {
    switch (widget.type) {
      case 'currency':
        _units = ['USD (доллар)', 'TJS (сомони)', 'RUB (рубль)', 'EUR (евро)', 'CNY (юань)', 'KZT (тенге)', 'UZS (сум)'];
        break;
      case 'length':
        _units = ['Метры (м)', 'Километры (км)', 'Сантиметры (см)', 'Миллиметры (мм)', 'Мили (mi)', 'Футы (ft)', 'Дюймы (in)'];
        break;
      case 'mass':
        _units = ['Килограммы (кг)', 'Граммы (г)', 'Тонны (т)', 'Фунты (lb)', 'Унции (oz)'];
        break;
      case 'area':
        _units = ['Кв. метры (м²)', 'Кв. километры (км²)', 'Гектары (га)', 'Сотки (ар)', 'Акры', 'Кв. футы (ft²)'];
        break;
      case 'time':
        _units = ['Секунды (с)', 'Минуты (мин)', 'Часы (ч)', 'Дни (сут)', 'Недели', 'Месяцы', 'Годы'];
        break;
      case 'data':
        _units = ['Байты (B)', 'Килобайты (KB)', 'Мегабайты (MB)', 'Гигабайты (GB)', 'Терабайты (TB)'];
        break;
      case 'volume':
        _units = ['Литры (л)', 'Миллилитры (мл)', 'Куб. метры (м³)', 'Галлоны (gal)'];
        break;
      case 'radix':
        _units = ['Десятичная (DEC)', 'Двоичная (BIN)', 'Шестнадцатеричная (HEX)', 'Восьмеричная (OCT)'];
        break;
      case 'speed':
        _units = ['км/ч', 'м/с', 'мили/ч', 'узлы'];
        break;
      case 'temp':
        _units = ['Цельсий (°C)', 'Фаренгейт (°F)', 'Кельвин (K)'];
        break;
      default:
        _units = ['Единица 1', 'Единица 2'];
    }
    _unitFrom = _units[0];
    _unitTo = _units.length > 1 ? _units[1] : _units[0];
  }

  void _swapUnits() {
    setState(() {
      final tmp = _unitFrom;
      _unitFrom = _unitTo;
      _unitTo = tmp;
    });
  }

  String _calcResult() {
    final val = double.tryParse(_input) ?? 0;
    if (widget.type == 'currency') {
      final rates = {
        'USD (доллар)': 1.0,
        'TJS (сомони)': 10.92,
        'RUB (рубль)': 92.5,
        'EUR (евро)': 0.92,
        'CNY (юань)': 7.23,
        'KZT (тенге)': 475.0,
        'UZS (сум)': 12600.0,
      };
      final usd = val / (rates[_unitFrom] ?? 1.0);
      final res = usd * (rates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(2);
    } else if (widget.type == 'length') {
      final mRates = {
        'Метры (м)': 1.0,
        'Километры (км)': 1000.0,
        'Сантиметры (см)': 0.01,
        'Миллиметры (мм)': 0.001,
        'Мили (mi)': 1609.344,
        'Футы (ft)': 0.3048,
        'Дюймы (in)': 0.0254,
      };
      final m = val * (mRates[_unitFrom] ?? 1.0);
      final res = m / (mRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'mass') {
      final kgRates = {
        'Килограммы (кг)': 1.0,
        'Граммы (г)': 0.001,
        'Тонны (т)': 1000.0,
        'Фунты (lb)': 0.45359237,
        'Унции (oz)': 0.0283495,
      };
      final kg = val * (kgRates[_unitFrom] ?? 1.0);
      final res = kg / (kgRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'area') {
      final aRates = {
        'Кв. метры (м²)': 1.0,
        'Кв. километры (км²)': 1000000.0,
        'Гектары (га)': 10000.0,
        'Сотки (ар)': 100.0,
        'Акры': 4046.86,
        'Кв. футы (ft²)': 0.092903,
      };
      final sq = val * (aRates[_unitFrom] ?? 1.0);
      final res = sq / (aRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'time') {
      final tRates = {
        'Секунды (с)': 1.0,
        'Минуты (мин)': 60.0,
        'Часы (ч)': 3600.0,
        'Дни (сут)': 86400.0,
        'Недели': 604800.0,
        'Месяцы': 2592000.0,
        'Годы': 31536000.0,
      };
      final s = val * (tRates[_unitFrom] ?? 1.0);
      final res = s / (tRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'data') {
      final dRates = {
        'Байты (B)': 1.0,
        'Килобайты (KB)': 1024.0,
        'Мегабайты (MB)': 1048576.0,
        'Гигабайты (GB)': 1073741824.0,
        'Терабайты (TB)': 1099511627776.0,
      };
      final b = val * (dRates[_unitFrom] ?? 1.0);
      final res = b / (dRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'volume') {
      final vRates = {
        'Литры (л)': 1.0,
        'Миллилитры (мл)': 0.001,
        'Куб. метры (м³)': 1000.0,
        'Галлоны (gal)': 3.78541,
      };
      final l = val * (vRates[_unitFrom] ?? 1.0);
      final res = l / (vRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4);
    } else if (widget.type == 'speed') {
      final spRates = {
        'км/ч': 1.0,
        'м/с': 3.6,
        'мили/ч': 1.60934,
        'узлы': 1.852,
      };
      final kmh = val * (spRates[_unitFrom] ?? 1.0);
      final res = kmh / (spRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(2);
    } else if (widget.type == 'temp') {
      double c = val;
      if (_unitFrom.contains('°F')) c = (val - 32) * 5 / 9;
      if (_unitFrom.contains('K')) c = val - 273.15;
      if (_unitTo.contains('°C')) return c.toStringAsFixed(2);
      if (_unitTo.contains('°F')) return ((c * 9 / 5) + 32).toStringAsFixed(2);
      if (_unitTo.contains('K')) return (c + 273.15).toStringAsFixed(2);
    } else if (widget.type == 'radix') {
      final intVal = val.toInt();
      if (_unitTo.contains('BIN')) return intVal.toRadixString(2);
      if (_unitTo.contains('OCT')) return intVal.toRadixString(8);
      if (_unitTo.contains('HEX')) return intVal.toRadixString(16).toUpperCase();
      return intVal.toRadixString(10);
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'discount') return _buildDiscountSpecial();
    if (widget.type == 'bmi') return _buildBmiSpecial();

    final isFav = appState.favoriteConverters.contains(widget.type);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: MiColors.keyOrange),
            onPressed: () => setState(() => appState.toggleFavorite(widget.type)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _unitRow(_unitFrom, (v) => setState(() => _unitFrom = v), _input, isInput: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _swapUnits,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: keyGray, borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.swap_vert, size: 18, color: MiColors.keyOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _unitRow(_unitTo, (v) => setState(() => _unitTo = v), _calcResult(), isInput: false),
                ],
              ),
            ),
            const Spacer(),
            _buildCustomNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _unitRow(String selectedUnit, ValueChanged<String> onUnitChange, String value, {required bool isInput}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          value: selectedUnit,
          dropdownColor: surface,
          underline: const SizedBox(),
          style: TextStyle(fontSize: 14, color: textPri),
          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(fontSize: 14, color: textPri)))).toList(),
          onChanged: (v) { if (v != null) onUnitChange(v); },
        ),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isInput ? textPri : MiColors.keyOrange)),
      ],
    );
  }

  Widget _buildCustomNumpad() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['7', '8', '9'].map((l) => _padBtn(l)).toList()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['4', '5', '6'].map((l) => _padBtn(l)).toList()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['1', '2', '3'].map((l) => _padBtn(l)).toList()),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: ['C', '0', 'DEL'].map((l) => _padBtn(l)).toList()),
        ],
      ),
    );
  }

  Widget _padBtn(String label) {
    return SizedBox(
      width: 100, height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: keyGray, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (label == 'C') _input = '0';
            else if (label == 'DEL') {
              if (_input.length > 1) _input = _input.substring(0, _input.length - 1);
              else _input = '0';
            } else {
              if (_input == '0') _input = label;
              else _input += label;
            }
          });
        },
        child: label == 'DEL' ? Icon(Icons.backspace_outlined, color: textPri) : Text(label, style: TextStyle(fontSize: 22, color: textPri)),
      ),
    );
  }

  Widget _buildDiscountSpecial() {
    final orig = double.tryParse(_input) ?? 0;
    final disc = double.tryParse(_discountCtrl.text) ?? 0;
    final save = orig * (disc / 100.0);
    final finalPrice = orig - save;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Скидка'), backgroundColor: bg, foregroundColor: textPri),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Text('Итоговая цена к оплате:', style: TextStyle(color: textSec)),
                    const SizedBox(height: 6),
                    Text(finalPrice.toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: MiColors.keyOrange)),
                    const SizedBox(height: 10),
                    Text('Экономия: ${save.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (v) => setState(() => _input = v),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(labelText: 'Исходная цена', filled: true, fillColor: surface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _discountCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(labelText: 'Скидка в %', filled: true, fillColor: surface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBmiSpecial() {
    final w = double.tryParse(_weightCtrl.text) ?? 70;
    final h = (double.tryParse(_heightCtrl.text) ?? 175) / 100.0;
    final bmi = h > 0 ? (w / (h * h)) : 0;
    String status = 'Нормальный вес';
    Color sc = Colors.green;
    if (bmi < 18.5) { status = 'Дефицит массы'; sc = Colors.amber; }
    else if (bmi >= 25 && bmi < 30) { status = 'Избыточный вес'; sc = Colors.amber; }
    else if (bmi >= 30) { status = 'Ожирение'; sc = Colors.red; }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('ИМТ (Индекс массы тела)'), backgroundColor: bg, foregroundColor: textPri),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    Text('Ваш ИМТ:', style: TextStyle(color: textSec)),
                    const SizedBox(height: 6),
                    Text(bmi.toStringAsFixed(1), style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: sc)),
                    const SizedBox(height: 6),
                    Text(status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: sc)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _heightCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(labelText: 'Рост (см)', filled: true, fillColor: surface),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPri),
                decoration: InputDecoration(labelText: 'Вес (кг)', filled: true, fillColor: surface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/history.dart';
import 'models/calculator_engine.dart';
import 'services/currency_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MiCalculatorApp());
}

class HyperColors {
  static const darkBg = Color(0xFF0F0F11);
  static const darkSurface = Color(0xFF1B1B1E);
  static const darkCard = Color(0xFF242428);
  static const darkKeyNumber = Color(0xFF2C2C30);
  static const darkKeyOp = Color(0xFFFF7A00);
  static const darkKeyFunc = Color(0xFF38383E);
  static const darkTextPri = Color(0xFFFFFFFF);
  static const darkTextSec = Color(0xFF8E8E93);
  static const darkDivider = Color(0xFF2A2A2E);

  static const lightBg = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightKeyNumber = Color(0xFFFFFFFF);
  static const lightKeyOp = Color(0xFFFF7A00);
  static const lightKeyFunc = Color(0xFFE5E5EA);
  static const lightTextPri = Color(0xFF1C1C1E);
  static const lightTextSec = Color(0xFF8E8E93);
  static const lightDivider = Color(0xFFE0E0E6);
}

class AppState extends ChangeNotifier {
  bool isDark = true;
  Set<String> favorites = {'currency', 'discount', 'loan', 'mass'};

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    isDark = p.getBool('app_theme_dark') ?? true;
    final favList = p.getStringList('app_favorites');
    if (favList != null && favList.isNotEmpty) {
      favorites = favList.toSet();
    }
    await CurrencyService.loadCachedRates();
    CurrencyService.fetchLiveRates().then((_) => notifyListeners());
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('app_theme_dark', isDark);
  }

  Future<void> toggleFavorite(String id) async {
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('app_favorites', favorites.toList());
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
    appState.addListener(_update);
    appState.init();
  }

  @override
  void dispose() {
    appState.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final dark = appState.isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: dark ? HyperColors.darkBg : HyperColors.lightBg,
    ));

    return MaterialApp(
      title: 'HyperOS Calculator',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: HyperColors.lightBg,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: HyperColors.darkBg,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

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
                children: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      appState.toggleTheme();
                    },
                    icon: Icon(
                      appState.isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      color: textSec,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(appState.isDark ? 0.3 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _pillItem('Калькулятор', 0, Icons.calculate_rounded),
                        _pillItem('Конвертер', 1, Icons.swap_horiz_rounded),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_tab == 0)
                    IconButton(
                      icon: Icon(Icons.history_rounded, color: textSec, size: 24),
                      onPressed: () => CalculatorTab.showHistory(context),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tab == 0 ? const CalculatorTab() : const ConverterTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillItem(String title, int idx, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tab = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? HyperColors.darkKeyOp : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : textSec),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? Colors.white : textSec,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalculatorTab extends StatefulWidget {
  const CalculatorTab({super.key});

  static void showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const HistorySheet(),
    );
  }

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  String _expr = '';
  String _preview = '';
  bool _scientific = false;
  List<CalcHistoryItem> _history = [];

  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;
  Color get keyNumber => appState.isDark ? HyperColors.darkKeyNumber : HyperColors.lightKeyNumber;
  Color get keyFunc => appState.isDark ? HyperColors.darkKeyFunc : HyperColors.lightKeyFunc;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('calc_history_v3') ?? [];
    _history = list.map((e) => CalcHistoryItem.fromJson(jsonDecode(e))).toList();
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('calc_history_v3', _history.map((e) => jsonEncode(e.toJson())).toList());
  }

  void _onPress(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'AC') {
        _expr = '';
        _preview = '';
      } else if (key == 'DEL') {
        if (_expr.isNotEmpty) {
          _expr = _expr.substring(0, _expr.length - 1);
          _calcLive();
        }
      } else if (key == '=') {
        if (_expr.isNotEmpty) {
          final res = CalcEngine.evaluate(_expr);
          final resStr = CalcEngine.formatNumber(res);
          if (resStr != 'Ошибка') {
            _history.insert(
              0,
              CalcHistoryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                expression: _expr,
                result: resStr,
                timestamp: DateTime.now(),
              ),
            );
            _saveHistory();
            _expr = resStr;
            _preview = '';
          }
        }
      } else if (key == '+/-') {
        if (_expr.isNotEmpty) {
          if (_expr.startsWith('-')) {
            _expr = _expr.substring(1);
          } else {
            _expr = '-$_expr';
          }
          _calcLive();
        }
      } else if (['sin', 'cos', 'tan', '√', 'x²', 'log', 'ln', '1/x', '!'].contains(key)) {
        final current = double.tryParse(_preview.isNotEmpty ? _preview : _expr) ?? CalcEngine.evaluate(_expr);
        final res = CalcEngine.applyFunction(key, current);
        _expr = CalcEngine.formatNumber(res);
        _preview = '';
      } else {
        final ops = ['+', '−', '×', '÷', '%', '^'];
        if (ops.contains(key) && _expr.isNotEmpty && ops.contains(_expr[_expr.length - 1])) {
          _expr = _expr.substring(0, _expr.length - 1) + key;
        } else {
          _expr += key;
        }
        _calcLive();
      }
    });
  }

  void _calcLive() {
    if (_expr.contains('+') || _expr.contains('−') || _expr.contains('×') || _expr.contains('÷') || _expr.contains('%') || _expr.contains('^')) {
      final res = CalcEngine.evaluate(_expr);
      _preview = CalcEngine.formatNumber(res);
    } else {
      _preview = '';
    }
  }

  void _copyResult() {
    final text = _preview.isNotEmpty ? _preview : _expr;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано: $text'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onLongPress: _copyResult,
            onHorizontalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0).abs() > 100) {
                _onPress('DEL');
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              alignment: Alignment.bottomRight,
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _expr.isEmpty ? '0' : _expr,
                      style: TextStyle(
                        fontSize: _expr.length > 12 ? 38 : 54,
                        fontWeight: FontWeight.w300,
                        color: textPri,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 3,
                    ),
                    if (_preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '= $_preview',
                        style: const TextStyle(fontSize: 26, color: HyperColors.darkKeyOp, fontWeight: FontWeight.w400),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Свайп для удаления | Удержание для копии',
                          style: TextStyle(fontSize: 11, color: textSec.withOpacity(0.5)),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _scientific = !_scientific),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _scientific ? HyperColors.darkKeyOp.withOpacity(0.2) : keyFunc,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _scientific ? '123 Простой' : 'f(x) Научный',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _scientific ? HyperColors.darkKeyOp : textSec,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              if (_scientific) ...[
                _row(['sin', 'cos', 'tan', '√'], isSmall: true),
                const SizedBox(height: 8),
                _row(['log', 'ln', 'x²', '!'], isSmall: true),
                const SizedBox(height: 8),
                _row(['(', ')', 'π', '^'], isSmall: true),
                const SizedBox(height: 8),
              ],
              _row(['AC', '+/-', '%', '÷']),
              const SizedBox(height: 10),
              _row(['7', '8', '9', '×']),
              const SizedBox(height: 10),
              _row(['4', '5', '6', '−']),
              const SizedBox(height: 10),
              _row(['1', '2', '3', '+']),
              const SizedBox(height: 10),
              _row(['0', '.', 'DEL', '=']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(List<String> items, {bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((e) => _btn(e, isSmall: isSmall)).toList(),
    );
  }

  Widget _btn(String label, {bool isSmall = false}) {
    final isEq = label == '=';
    final isOp = ['÷', '×', '−', '+', '^'].contains(label);
    final isTop = ['AC', '+/-', '%'].contains(label);

    Color bg;
    Color fg;

    if (isEq) {
      bg = HyperColors.darkKeyOp;
      fg = Colors.white;
    } else if (isOp) {
      bg = appState.isDark ? const Color(0xFF2C2218) : const Color(0xFFFFE8D6);
      fg = HyperColors.darkKeyOp;
    } else if (isTop || isSmall) {
      bg = keyFunc;
      fg = textPri;
    } else {
      bg = keyNumber;
      fg = textPri;
    }

    return SizedBox(
      width: isSmall ? 82 : 82,
      height: isSmall ? 48 : 68,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(isSmall ? 16 : 22),
        elevation: appState.isDark ? 0 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(isSmall ? 16 : 22),
          onTap: () => _onPress(label),
          child: Center(
            child: label == 'DEL'
                ? Icon(Icons.backspace_outlined, size: 22, color: fg)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 24,
                      fontWeight: isOp || isEq ? FontWeight.bold : FontWeight.w400,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class HistorySheet extends StatelessWidget {
  const HistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 300);
        final p = snap.data!;
        final raw = p.getStringList('calc_history_v3') ?? [];
        final items = raw.map((e) => CalcHistoryItem.fromJson(jsonDecode(e))).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('История вычислений', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: HyperColors.darkKeyOp),
                    onPressed: () async {
                      await p.remove('calc_history_v3');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('История пуста'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final it = items.elementAt(i);
                          return ListTile(
                            title: Text(it.expression, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            subtitle: Text('= ${it.result}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            trailing: Text(DateFormat('HH:mm').format(it.timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: it.result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Скопировано: ${it.result}')),
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConverterCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String section;

  const ConverterCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.section,
  });
}

const List<ConverterCategory> allCategories = [
  ConverterCategory(
    id: 'currency',
    title: 'Валюта (Онлайн)',
    subtitle: 'Курсы в реальном времени',
    icon: Icons.currency_exchange_rounded,
    gradient: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
    section: 'finance',
  ),
  ConverterCategory(
    id: 'loan',
    title: 'Кредит и Ипотека',
    subtitle: 'Платеж и переплата',
    icon: Icons.account_balance_wallet_rounded,
    gradient: [Color(0xFF34C759), Color(0xFF1B8A3B)],
    section: 'finance',
  ),
  ConverterCategory(
    id: 'discount',
    title: 'Скидка и Экономия',
    subtitle: 'Итоговая цена и выгода',
    icon: Icons.local_offer_rounded,
    gradient: [Color(0xFFFF2D55), Color(0xFFFF375F)],
    section: 'finance',
  ),
  ConverterCategory(
    id: 'tip',
    title: 'Чаевые и Сплит',
    subtitle: 'Разделить счёт с друзьями',
    icon: Icons.restaurant_rounded,
    gradient: [Color(0xFFFF9F0A), Color(0xFFFFD60A)],
    section: 'finance',
  ),
  ConverterCategory(
    id: 'fuel',
    title: 'Расход топлива',
    subtitle: 'Расчет стоимости поездки',
    icon: Icons.local_gas_station_rounded,
    gradient: [Color(0xFF5856D6), Color(0xFF3634A3)],
    section: 'daily',
  ),
  ConverterCategory(
    id: 'bmi',
    title: 'ИМТ (Индекс массы)',
    subtitle: 'Контроль здоровья тела',
    icon: Icons.favorite_rounded,
    gradient: [Color(0xFFFF3B30), Color(0xFFFF453A)],
    section: 'daily',
  ),
  ConverterCategory(
    id: 'age',
    title: 'Возраст и Даты',
    subtitle: 'Точный возраст и разница',
    icon: Icons.cake_rounded,
    gradient: [Color(0xFFAF52DE), Color(0xFF8944AB)],
    section: 'daily',
  ),
  ConverterCategory(
    id: 'length',
    title: 'Длина',
    subtitle: 'м, км, мили, футы, дюймы',
    icon: Icons.straighten_rounded,
    gradient: [Color(0xFF007AFF), Color(0xFF00C7BE)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'mass',
    title: 'Масса и Вес',
    subtitle: 'кг, г, тонны, фунты, унции',
    icon: Icons.scale_rounded,
    gradient: [Color(0xFF5AC8FA), Color(0xFF007AFF)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'area',
    title: 'Площадь',
    subtitle: 'м², км², сотки, гектары',
    icon: Icons.crop_square_rounded,
    gradient: [Color(0xFF30B0C7), Color(0xFF34C759)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'volume',
    title: 'Объем',
    subtitle: 'литры, мл, м³, галлоны',
    icon: Icons.view_in_ar_rounded,
    gradient: [Color(0xFF32ADE6), Color(0xFF0071A4)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'speed',
    title: 'Скорость',
    subtitle: 'км/ч, м/с, мили/ч, узлы',
    icon: Icons.speed_rounded,
    gradient: [Color(0xFFFF9500), Color(0xFFFFCC00)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'temp',
    title: 'Температура',
    subtitle: '°C, °F, Кельвин',
    icon: Icons.thermostat_rounded,
    gradient: [Color(0xFFFF453A), Color(0xFFFF9F0A)],
    section: 'physics',
  ),
  ConverterCategory(
    id: 'time',
    title: 'Время',
    subtitle: 'сек, мин, часы, дни, годы',
    icon: Icons.schedule_rounded,
    gradient: [Color(0xFF63E6E2), Color(0xFF007AFF)],
    section: 'daily',
  ),
  ConverterCategory(
    id: 'data',
    title: 'Данные',
    subtitle: 'Байты, КБ, МБ, ГБ, ТБ',
    icon: Icons.cloud_done_rounded,
    gradient: [Color(0xFF64D2FF), Color(0xFF5856D6)],
    section: 'daily',
  ),
  ConverterCategory(
    id: 'radix',
    title: 'Системы счисления',
    subtitle: 'BIN, OCT, DEC, HEX',
    icon: Icons.code_rounded,
    gradient: [Color(0xFF8E8E93), Color(0xFF636366)],
    section: 'daily',
  ),
];

class ConverterTab extends StatefulWidget {
  const ConverterTab({super.key});
  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
  String _filter = 'all';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get cardBg => appState.isDark ? HyperColors.darkCard : HyperColors.lightCard;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    List<ConverterCategory> list = allCategories;

    if (_filter == 'fav') {
      list = list.where((c) => appState.favorites.contains(c.id)).toList();
    } else if (_filter != 'all') {
      list = list.where((c) => c.section == _filter).toList();
    }

    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((c) => c.title.toLowerCase().contains(q) || c.subtitle.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: appState.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: textPri, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск (валюта, кредит, масса, скидка...)',
                hintStyle: TextStyle(color: textSec, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: textSec, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: textSec, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _chip('Все', 'all'),
              _chip('⭐ Избранное', 'fav'),
              _chip('💰 Финансы', 'finance'),
              _chip('📐 Физика', 'physics'),
              _chip('⚡ Повседневные', 'daily'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text('Ничего не найдено', style: TextStyle(color: textSec)))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, idx) {
                    final item = list.elementAt(idx);
                    final isFav = appState.favorites.contains(item.id);
                    return _buildCard(item, isFav);
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String key) {
    final active = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? HyperColors.darkKeyOp : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? HyperColors.darkKeyOp : (appState.isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w500,
              color: active ? Colors.white : textSec,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ConverterCategory item, bool isFav) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      elevation: appState.isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          _openCategory(item);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          appState.toggleFavorite(item.id);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: appState.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: item.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: item.gradient.first.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 22),
                  ),
                  GestureDetector(
                    onTap: () => appState.toggleFavorite(item.id),
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? Colors.amber : textSec.withOpacity(0.3),
                      size: 20,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPri),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: TextStyle(fontSize: 11, color: textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategory(ConverterCategory item) {
    Widget page;
    switch (item.id) {
      case 'currency':
        page = const RealtimeCurrencyPage();
        break;
      case 'loan':
        page = const LoanCalculatorPage();
        break;
      case 'tip':
        page = const TipCalculatorPage();
        break;
      case 'fuel':
        page = const FuelCalculatorPage();
        break;
      case 'discount':
        page = const DiscountCalculatorPage();
        break;
      case 'bmi':
        page = const BmiCalculatorPage();
        break;
      case 'age':
        page = const AgeCalculatorPage();
        break;
      default:
        page = UniversalUnitsConverterPage(category: item);
        break;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class RealtimeCurrencyPage extends StatefulWidget {
  const RealtimeCurrencyPage({super.key});
  @override
  State<RealtimeCurrencyPage> createState() => _RealtimeCurrencyPageState();
}

class _RealtimeCurrencyPageState extends State<RealtimeCurrencyPage> {
  String _amount = '1';
  CurrencyItem _from = CurrencyService.popularCurrencies.elementAt(1); // USD
  CurrencyItem _to = CurrencyService.popularCurrencies.first;          // TJS
  bool _loading = false;

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;
  Color get keyPadBg => appState.isDark ? HyperColors.darkCard : HyperColors.lightCard;

  @override
  void initState() {
    super.initState();
    _refreshRates();
  }

  Future<void> _refreshRates() async {
    setState(() => _loading = true);
    await CurrencyService.fetchLiveRates();
    if (mounted) setState(() => _loading = false);
  }

  void _swap() {
    HapticFeedback.lightImpact();
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
  }

  void _onKey(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'C') {
        _amount = '0';
      } else if (k == 'DEL') {
        if (_amount.length > 1) {
          _amount = _amount.substring(0, _amount.length - 1);
        } else {
          _amount = '0';
        }
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        if (_amount == '0') {
          _amount = k;
        } else if (_amount.length < 12) {
          _amount += k;
        }
      }
    });
  }

  void _pickCurrency(bool isFrom) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isFrom ? 'Выберите исходную валюту' : 'Выберите целевую валюту',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: CurrencyService.popularCurrencies.length,
                itemBuilder: (ctx, i) {
                  final cur = CurrencyService.popularCurrencies.elementAt(i);
                  return ListTile(
                    leading: Text(cur.flag, style: const TextStyle(fontSize: 26)),
                    title: Text('${cur.code} - ${cur.name}', style: TextStyle(color: textPri, fontWeight: FontWeight.w500)),
                    trailing: Text(cur.symbol, style: TextStyle(color: textSec, fontSize: 16)),
                    onTap: () {
                      setState(() {
                        if (isFrom) _from = cur;
                        else _to = cur;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amtVal = double.tryParse(_amount) ?? 0.0;
    final converted = CurrencyService.convert(amtVal, _from.code, _to.code);
    final singleRate = CurrencyService.convert(1.0, _from.code, _to.code);

    final timeStr = CurrencyService.lastUpdated != null
        ? DateFormat('HH:mm').format(CurrencyService.lastUpdated!)
        : 'Кэш';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Курсы валют онлайн'),
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: HyperColors.darkKeyOp))
                : const Icon(Icons.refresh_rounded, color: HyperColors.darkKeyOp),
            onPressed: _loading ? null : _refreshRates,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: CurrencyService.isOnline ? Colors.green : Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    CurrencyService.isOnline
                        ? 'Онлайн • Обновлено в $timeStr'
                        : 'Офлайн режим (сохраненные курсы)',
                    style: TextStyle(fontSize: 12, color: textSec),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(appState.isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _curRow(_from, _amount, true, () => _pickCurrency(true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _swap,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: keyPadBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.swap_vert_rounded, color: HyperColors.darkKeyOp, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _curRow(_to, converted.toStringAsFixed(2), false, () => _pickCurrency(false)),
                  const SizedBox(height: 12),
                  Text(
                    '1 ${_from.code} = ${singleRate.toStringAsFixed(4)} ${_to.code}',
                    style: TextStyle(fontSize: 13, color: textSec),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _curRow(CurrencyItem cur, String value, bool isInput, VoidCallback onPick) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Row(
              children: [
                Text(cur.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(cur.code, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPri)),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: isInput ? textPri : HyperColors.darkKeyOp,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _npRow(['7', '8', '9']),
          const SizedBox(height: 8),
          _npRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _npRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _npRow(['C', '0', 'DEL']),
        ],
      ),
    );
  }

  Widget _npRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) {
        return SizedBox(
          width: 105,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: keyPadBg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _onKey(k),
            child: k == 'DEL'
                ? Icon(Icons.backspace_outlined, color: textPri, size: 20)
                : Text(k, style: TextStyle(fontSize: 22, color: textPri, fontWeight: FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }
}

class LoanCalculatorPage extends StatefulWidget {
  const LoanCalculatorPage({super.key});
  @override
  State<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends State<LoanCalculatorPage> {
  final _amountCtrl = TextEditingController(text: '100000');
  final _rateCtrl = TextEditingController(text: '18');
  final _termCtrl = TextEditingController(text: '12');

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(_amountCtrl.text) ?? 0;
    final r = (double.tryParse(_rateCtrl.text) ?? 0) / 100.0 / 12.0;
    final n = int.tryParse(_termCtrl.text) ?? 1;

    double monthly = 0;
    if (r > 0 && n > 0) {
      monthly = (p * r * math.pow(1 + r, n)) / (math.pow(1 + r, n) - 1);
    } else if (n > 0) {
      monthly = p / n;
    }
    final total = monthly * n;
    final overpay = total - p;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Кредитный калькулятор'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('Ежемесячный платеж', style: TextStyle(color: textSec, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(monthly.toStringAsFixed(0), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: HyperColors.darkKeyOp)),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Общая переплата:', style: TextStyle(color: textSec)),
                      Text(overpay.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Всего к возврату:', style: TextStyle(color: textSec)),
                      Text(total.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _field('Сумма кредита', _amountCtrl, 'сомони / руб'),
            const SizedBox(height: 12),
            _field('Процентная ставка (% годовых)', _rateCtrl, '%'),
            const SizedBox(height: 12),
            _field('Срок кредита (месяцев)', _termCtrl, 'мес.'),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String suffix) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textPri),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textSec),
        suffixText: suffix,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class TipCalculatorPage extends StatefulWidget {
  const TipCalculatorPage({super.key});
  @override
  State<TipCalculatorPage> createState() => _TipCalculatorPageState();
}

class _TipCalculatorPageState extends State<TipCalculatorPage> {
  final _billCtrl = TextEditingController(text: '500');
  double _tipPercent = 10;
  int _people = 2;

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final bill = double.tryParse(_billCtrl.text) ?? 0;
    final tipVal = bill * (_tipPercent / 100.0);
    final total = bill + tipVal;
    final perPerson = _people > 0 ? (total / _people) : total;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Чаевые и сплит счёта'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('С человека', style: TextStyle(color: textSec)),
                  const SizedBox(height: 6),
                  Text(perPerson.toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: HyperColors.darkKeyOp)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Чаевые: ${tipVal.toStringAsFixed(2)}', style: TextStyle(color: textSec)),
                      Text('Итого: ${total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _billCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPri),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Сумма счёта',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Чаевые: ${_tipPercent.toInt()}%', style: TextStyle(color: textPri, fontWeight: FontWeight.bold)),
                Row(
                  children: [5, 10, 15, 20].map((v) {
                    final isSel = _tipPercent == v.toDouble();
                    return GestureDetector(
                      onTap: () => setState(() => _tipPercent = v.toDouble()),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? HyperColors.darkKeyOp : surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$v%', style: TextStyle(color: isSel ? Colors.white : textSec, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Количество персон: $_people', style: TextStyle(color: textPri, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: HyperColors.darkKeyOp,
                      onPressed: () {
                        if (_people > 1) setState(() => _people--);
                      },
                    ),
                    Text('$_people', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPri)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: HyperColors.darkKeyOp,
                      onPressed: () => setState(() => _people++),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DiscountCalculatorPage extends StatefulWidget {
  const DiscountCalculatorPage({super.key});
  @override
  State<DiscountCalculatorPage> createState() => _DiscountCalculatorPageState();
}

class _DiscountCalculatorPageState extends State<DiscountCalculatorPage> {
  final _priceCtrl = TextEditingController(text: '1000');
  final _discCtrl = TextEditingController(text: '15');

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final orig = double.tryParse(_priceCtrl.text) ?? 0;
    final disc = double.tryParse(_discCtrl.text) ?? 0;
    final save = orig * (disc / 100.0);
    final finalPrice = orig - save;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Скидка и Распродажа'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('Итого к оплате', style: TextStyle(color: textSec)),
                  const SizedBox(height: 6),
                  Text(finalPrice.toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: HyperColors.darkKeyOp)),
                  const Divider(height: 24),
                  Text('Ваша экономия: ${save.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPri),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Исходная цена',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPri),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Процент скидки (%)',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FuelCalculatorPage extends StatefulWidget {
  const FuelCalculatorPage({super.key});
  @override
  State<FuelCalculatorPage> createState() => _FuelCalculatorPageState();
}

class _FuelCalculatorPageState extends State<FuelCalculatorPage> {
  final _distCtrl = TextEditingController(text: '300');
  final _consCtrl = TextEditingController(text: '8.5');
  final _priceCtrl = TextEditingController(text: '10.5');

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final dist = double.tryParse(_distCtrl.text) ?? 0;
    final cons = double.tryParse(_consCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;

    final fuelNeeded = (dist / 100.0) * cons;
    final totalCost = fuelNeeded * price;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Расход топлива'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('Стоимость поездки', style: TextStyle(color: textSec)),
                  const SizedBox(height: 6),
                  Text(totalCost.toStringAsFixed(2), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: HyperColors.darkKeyOp)),
                  const Divider(height: 24),
                  Text('Потребуется топлива: ${fuelNeeded.toStringAsFixed(1)} л', style: TextStyle(color: textPri, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _f('Дистанция поездки (км)', _distCtrl),
            const SizedBox(height: 12),
            _f('Расход на 100 км (литров)', _consCtrl),
            const SizedBox(height: 12),
            _f('Цена за 1 литр', _priceCtrl),
          ],
        ),
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: TextStyle(color: textPri),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}

class BmiCalculatorPage extends StatefulWidget {
  const BmiCalculatorPage({super.key});
  @override
  State<BmiCalculatorPage> createState() => _BmiCalculatorPageState();
}

class _BmiCalculatorPageState extends State<BmiCalculatorPage> {
  final _hCtrl = TextEditingController(text: '175');
  final _wCtrl = TextEditingController(text: '70');

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final h = (double.tryParse(_hCtrl.text) ?? 175) / 100.0;
    final w = double.tryParse(_wCtrl.text) ?? 70;
    final bmi = h > 0 ? (w / (h * h)) : 0;

    String status = 'Нормальный вес';
    Color sc = Colors.green;
    if (bmi < 18.5) { status = 'Дефицит массы'; sc = Colors.amber; }
    else if (bmi >= 25 && bmi < 30) { status = 'Избыточный вес'; sc = Colors.amber; }
    else if (bmi >= 30) { status = 'Ожирение'; sc = Colors.red; }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('ИМТ (Индекс массы тела)'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('Ваш показатель ИМТ', style: TextStyle(color: textSec)),
                  const SizedBox(height: 6),
                  Text(bmi.toStringAsFixed(1), style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: sc)),
                  const SizedBox(height: 6),
                  Text(status, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: sc)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _hCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPri),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Рост (см)',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _wCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPri),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Вес (кг)',
                filled: true,
                fillColor: surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgeCalculatorPage extends StatefulWidget {
  const AgeCalculatorPage({super.key});
  @override
  State<AgeCalculatorPage> createState() => _AgeCalculatorPageState();
}

class _AgeCalculatorPageState extends State<AgeCalculatorPage> {
  DateTime _birth = DateTime(2000, 1, 1);

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int years = now.year - _birth.year;
    int months = now.month - _birth.month;
    int days = now.day - _birth.day;

    if (days < 0) {
      months--;
      days += 30;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    final totalDays = now.difference(_birth).inDays;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Калькулятор возраста'), backgroundColor: bg, foregroundColor: textPri, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24)),
              child: Column(
                children: [
                  Text('Ваш точный возраст:', style: TextStyle(color: textSec)),
                  const SizedBox(height: 6),
                  Text('$years лет', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: HyperColors.darkKeyOp)),
                  Text('$months мес., $days дн.', style: TextStyle(fontSize: 18, color: textPri, fontWeight: FontWeight.w500)),
                  const Divider(height: 24),
                  Text('Всего прожито: $totalDays дней', style: TextStyle(color: textSec, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: surface,
                foregroundColor: textPri,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.calendar_today_rounded, color: HyperColors.darkKeyOp),
              label: Text('Дата рождения: ${DateFormat('dd.MM.yyyy').format(_birth)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _birth,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _birth = d);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UniversalUnitsConverterPage extends StatefulWidget {
  final ConverterCategory category;
  const UniversalUnitsConverterPage({super.key, required this.category});

  @override
  State<UniversalUnitsConverterPage> createState() => _UniversalUnitsConverterPageState();
}

class _UniversalUnitsConverterPageState extends State<UniversalUnitsConverterPage> {
  String _input = '1';
  late String _unitFrom;
  late String _unitTo;
  late List<String> _units;

  Color get bg => appState.isDark ? HyperColors.darkBg : HyperColors.lightBg;
  Color get surface => appState.isDark ? HyperColors.darkSurface : HyperColors.lightSurface;
  Color get textPri => appState.isDark ? HyperColors.darkTextPri : HyperColors.lightTextPri;
  Color get textSec => appState.isDark ? HyperColors.darkTextSec : HyperColors.lightTextSec;
  Color get keyPadBg => appState.isDark ? HyperColors.darkCard : HyperColors.lightCard;

  @override
  void initState() {
    super.initState();
    _initUnits();
  }

  void _initUnits() {
    switch (widget.category.id) {
      case 'length':
        _units = ['Метры (м)', 'Километры (км)', 'Сантиметры (см)', 'Миллиметры (мм)', 'Мили (mi)', 'Футы (ft)', 'Дюймы (in)', 'Ярды (yd)'];
        break;
      case 'mass':
        _units = ['Килограммы (кг)', 'Граммы (г)', 'Тонны (т)', 'Миллиграммы (мг)', 'Фунты (lb)', 'Унции (oz)'];
        break;
      case 'area':
        _units = ['Кв. метры (м²)', 'Кв. километры (км²)', 'Гектары (га)', 'Сотки (ар)', 'Акры', 'Кв. футы (ft²)'];
        break;
      case 'volume':
        _units = ['Литры (л)', 'Миллилитры (мл)', 'Куб. метры (м³)', 'Галлоны (gal)', 'Пинты (pt)'];
        break;
      case 'speed':
        _units = ['км/ч', 'м/с', 'мили/ч', 'узлы (kn)'];
        break;
      case 'temp':
        _units = ['Цельсий (°C)', 'Фаренгейт (°F)', 'Кельвин (K)'];
        break;
      case 'time':
        _units = ['Секунды (с)', 'Минуты (мин)', 'Часы (ч)', 'Дни (сут)', 'Недели', 'Месяцы', 'Годы'];
        break;
      case 'data':
        _units = ['Байты (B)', 'Килобайты (KB)', 'Мегабайты (MB)', 'Гигабайты (GB)', 'Терабайты (TB)'];
        break;
      case 'radix':
        _units = ['Десятичная (DEC)', 'Двоичная (BIN)', 'Шестнадцатеричная (HEX)', 'Восьмеричная (OCT)'];
        break;
      default:
        _units = ['Единица 1', 'Единица 2'];
    }
    _unitFrom = _units.first;
    _unitTo = _units.length > 1 ? _units.elementAt(1) : _units.first;
  }

  void _swap() {
    HapticFeedback.lightImpact();
    setState(() {
      final tmp = _unitFrom;
      _unitFrom = _unitTo;
      _unitTo = tmp;
    });
  }

  String _calc() {
    final val = double.tryParse(_input) ?? 0;
    if (widget.category.id == 'length') {
      final mRates = {
        'Метры (м)': 1.0,
        'Километры (км)': 1000.0,
        'Сантиметры (см)': 0.01,
        'Миллиметры (мм)': 0.001,
        'Мили (mi)': 1609.344,
        'Футы (ft)': 0.3048,
        'Дюймы (in)': 0.0254,
        'Ярды (yd)': 0.9144,
      };
      final m = val * (mRates[_unitFrom] ?? 1.0);
      final res = m / (mRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'mass') {
      final kgRates = {
        'Килограммы (кг)': 1.0,
        'Граммы (г)': 0.001,
        'Тонны (т)': 1000.0,
        'Миллиграммы (мг)': 0.000001,
        'Фунты (lb)': 0.45359237,
        'Унции (oz)': 0.0283495,
      };
      final kg = val * (kgRates[_unitFrom] ?? 1.0);
      final res = kg / (kgRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'area') {
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
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'volume') {
      final vRates = {
        'Литры (л)': 1.0,
        'Миллилитры (мл)': 0.001,
        'Куб. метры (м³)': 1000.0,
        'Галлоны (gal)': 3.78541,
        'Пинты (pt)': 0.473176,
      };
      final l = val * (vRates[_unitFrom] ?? 1.0);
      final res = l / (vRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'speed') {
      final spRates = {
        'км/ч': 1.0,
        'м/с': 3.6,
        'мили/ч': 1.60934,
        'узлы (kn)': 1.852,
      };
      final kmh = val * (spRates[_unitFrom] ?? 1.0);
      final res = kmh / (spRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(2);
    } else if (widget.category.id == 'temp') {
      double c = val;
      if (_unitFrom.contains('°F')) c = (val - 32) * 5 / 9;
      if (_unitFrom.contains('K')) c = val - 273.15;
      if (_unitTo.contains('°C')) return c.toStringAsFixed(2);
      if (_unitTo.contains('°F')) return ((c * 9 / 5) + 32).toStringAsFixed(2);
      if (_unitTo.contains('K')) return (c + 273.15).toStringAsFixed(2);
    } else if (widget.category.id == 'time') {
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
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'data') {
      final dRates = {
        'Байты (B)': 1.0,
        'Килобайты (KB)': 1024.0,
        'Мегабайты (MB)': 1048576.0,
        'Гигабайты (GB)': 1073741824.0,
        'Терабайты (TB)': 1099511627776.0,
      };
      final b = val * (dRates[_unitFrom] ?? 1.0);
      final res = b / (dRates[_unitTo] ?? 1.0);
      return res.toStringAsFixed(4).replaceAll(RegExp(r'\.?0+$'), '');
    } else if (widget.category.id == 'radix') {
      final intVal = val.toInt();
      if (_unitTo.contains('BIN')) return intVal.toRadixString(2);
      if (_unitTo.contains('OCT')) return intVal.toRadixString(8);
      if (_unitTo.contains('HEX')) return intVal.toRadixString(16).toUpperCase();
      return intVal.toRadixString(10);
    }
    return val.toString();
  }

  void _onKey(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'C') {
        _input = '0';
      } else if (k == 'DEL') {
        if (_input.length > 1) {
          _input = _input.substring(0, _input.length - 1);
        } else {
          _input = '0';
        }
      } else if (k == '.') {
        if (!_input.contains('.')) _input += '.';
      } else {
        if (_input == '0') {
          _input = k;
        } else {
          _input += k;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFav = appState.favorites.contains(widget.category.id);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.category.title),
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber),
            onPressed: () => setState(() => appState.toggleFavorite(widget.category.id)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(appState.isDark ? 0.3 : 0.05), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  _unitDropdown(_unitFrom, (v) => setState(() => _unitFrom = v), _input, true),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _swap,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: keyPadBg, shape: BoxShape.circle),
                            child: const Icon(Icons.swap_vert_rounded, color: HyperColors.darkKeyOp, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _unitDropdown(_unitTo, (v) => setState(() => _unitTo = v), _calc(), false),
                ],
              ),
            ),
            const Spacer(),
            _buildNumpad(),
          ],
        ),
      ),
    );
  }

  Widget _unitDropdown(String cur, ValueChanged<String> onChange, String val, bool isInput) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButton<String>(
          value: cur,
          dropdownColor: surface,
          underline: const SizedBox(),
          style: TextStyle(fontSize: 14, color: textPri),
          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: TextStyle(fontSize: 14, color: textPri)))).toList(),
          onChanged: (v) { if (v != null) onChange(v); },
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isInput ? textPri : HyperColors.darkKeyOp,
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          _row(['7', '8', '9']),
          const SizedBox(height: 8),
          _row(['4', '5', '6']),
          const SizedBox(height: 8),
          _row(['1', '2', '3']),
          const SizedBox(height: 8),
          _row(['C', '0', 'DEL']),
        ],
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) {
        return SizedBox(
          width: 105,
          height: 60,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: keyPadBg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _onKey(k),
            child: k == 'DEL'
                ? Icon(Icons.backspace_outlined, color: textPri, size: 20)
                : Text(k, style: TextStyle(fontSize: 22, color: textPri, fontWeight: FontWeight.w500)),
          ),
        );
      }).toList(),
    );
  }
}

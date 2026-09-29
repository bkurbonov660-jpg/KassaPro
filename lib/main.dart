import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
  ));
  runApp(const GoalFlowApp());
}

// ─────────────────────────────────────────────
// ЦВЕТОВАЯ ПАЛИТРА ИЗ fjv.html
// ─────────────────────────────────────────────
class AppColors {
  static const bg         = Color(0xFF0F1115);
  static const panel      = Color(0xFF171A21);
  static const panel2     = Color(0xFF1E222B);
  static const line       = Color(0xFF272B35);
  static const text       = Color(0xFFE8EAED);
  static const muted      = Color(0xFF8A8F9C);
  static const accent     = Color(0xFF4F7CFF);
  static const accentSoft = Color(0x264F7CFF);
  static const red        = Color(0xFFEF4444);
  static const redSoft    = Color(0x1FEF4444);
  static const green      = Color(0xFF22C55E);
  static const greenSoft  = Color(0x1F22C55E);
  static const orange     = Color(0xFFF59E0B);
}

class AppConstants {
  static const List<String> currencies = ['RUB', 'USD', 'EUR', 'TJS', 'CNY'];
  static const Map<String, String> symbols = {
    'RUB': '₽', 'USD': r'$', 'EUR': '€', 'TJS': 'SM', 'CNY': '¥'
  };
  static const Map<String, String> flags = {
    'RUB': '🇷🇺', 'USD': '🇺🇸', 'EUR': '🇪🇺', 'TJS': '🇹🇯', 'CNY': '🇨🇳'
  };
  static const Map<String, String> names = {
    'RUB': 'Российский рубль',
    'USD': 'Доллар США',
    'EUR': 'Евро',
    'TJS': 'Таджикский сомони',
    'CNY': 'Китайский юань'
  };
  static const Map<String, double> defaultRates = {
    'RUB': 1.0, 'USD': 90.0, 'EUR': 99.0, 'TJS': 9.2, 'CNY': 12.5
  };
}

IconData getGoalIconData(String name) {
  switch (name) {
    case 'money': return Icons.attach_money_rounded;
    case 'home': return Icons.home_rounded;
    case 'car': return Icons.directions_car_rounded;
    case 'phone': return Icons.phone_iphone_rounded;
    case 'laptop': return Icons.laptop_rounded;
    case 'plane': return Icons.flight_takeoff_rounded;
    case 'globe': return Icons.public_rounded;
    case 'gift': return Icons.card_giftcard_rounded;
    case 'camera': return Icons.photo_camera_rounded;
    case 'watch': return Icons.watch_rounded;
    case 'game': return Icons.sports_esports_rounded;
    case 'diamond': return Icons.auto_awesome_rounded;
    case 'school': return Icons.school_rounded;
    case 'work': return Icons.work_rounded;
    case 'heart': return Icons.favorite_rounded;
    case 'send': return Icons.send_rounded;
    case 'family': return Icons.family_restroom_rounded;
    case 'bank': return Icons.account_balance_rounded;
    case 'star': return Icons.star_rounded;
    default: return Icons.track_changes_rounded;
  }
}

class GoalFlowApp extends StatelessWidget {
  const GoalFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.panel,
          primary: AppColors.accent,
        ),
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
  bool _loading = true;
  String? _defCur;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _defCur = p.getString('gf_default_currency');
      _loading = false;
    });
  }

  void _finishOnboarding(String cur) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('gf_default_currency', cur);
    setState(() => _defCur = cur);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_defCur == null) {
      return OnboardingScreen(onSelected: _finishOnboarding);
    }
    return MainScreen(defaultCurrency: _defCur!);
  }
}

// ─────────────────────────────────────────────
// 1. ONBOARDING SCREEN
// ─────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  final ValueChanged<String> onSelected;
  const OnboardingScreen({super.key, required this.onSelected});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.track_changes_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 18),
                const Text('GoalFlow', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 8),
                const Text(
                  'Выбери валюту по умолчанию. Всё будет автоматически конвертироваться в неё.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ВАЛЮТА ПО УМОЛЧАНИЮ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted.withOpacity(0.8), letterSpacing: 0.5)),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: AppConstants.currencies.map((c) {
                    final active = _selected == c;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = c),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: active ? AppColors.accentSoft : AppColors.panel2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? AppColors.accent : AppColors.line),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(AppConstants.flags[c]!, style: const TextStyle(fontSize: 22)),
                            const SizedBox(height: 4),
                            Text('${AppConstants.symbols[c]} $c', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text)),
                            Text(AppConstants.names[c]!, style: const TextStyle(fontSize: 9, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _selected == null ? null : () => widget.onSelected(_selected!),
                    child: const Text('Продолжить', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 2. ГЛАВНЫЙ ЭКРАН И ВКЛАДКИ
// ─────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  final String defaultCurrency;
  const MainScreen({super.key, required this.defaultCurrency});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tabIndex = 0;
  late String _defaultCurrency;
  Map<String, double> _rates = Map.from(AppConstants.defaultRates);
  int? _ratesUpdated;
  String _ratesStatus = 'default';

  List<Goal> _goals = [];
  List<Goal> _archivedGoals = [];
  List<Goal> _senders = [];
  List<Goal> _sentArchive = [];
  List<TransactionRecord> _transactions = [];
  bool _expensesFromGoals = false;
  bool _senderAuto = true;
  String _goalsSection = 'goals'; // goals, sender
  String _reportTab = 'money'; // money, history, archive

  // Конвертер
  String _convFrom = 'RUB';
  String _convTo = 'USD';
  final _convFromCtrl = TextEditingController();
  final _convToCtrl = TextEditingController();

  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _defaultCurrency = widget.defaultCurrency;
    _convFrom = _defaultCurrency;
    _convTo = _defaultCurrency == 'USD' ? 'RUB' : 'USD';
    _loadState();
    _fetchRates(false);
  }

  Future<void> _loadState() async {
    final p = await SharedPreferences.getInstance();
    final gStr = p.getStringList('gf_goals') ?? [];
    final aStr = p.getStringList('gf_archived') ?? [];
    final tStr = p.getStringList('gf_txs') ?? [];
    final cur = p.getString('gf_default_currency') ?? _defaultCurrency;
    final rStr = p.getString('gf_rates');
    final sStr = p.getStringList('gf_senders') ?? [];
    final sentStr = p.getStringList('gf_sent') ?? [];

    setState(() {
      _defaultCurrency = cur;
      _goals = gStr.map((x) => Goal.fromJson(jsonDecode(x))).toList();
      _archivedGoals = aStr.map((x) => Goal.fromJson(jsonDecode(x))).toList();
      _transactions = tStr.map((x) => TransactionRecord.fromJson(jsonDecode(x))).toList();
      _expensesFromGoals = p.getBool('gf_exp_from_goals') ?? false;
      _senders = sStr.map((x) => Goal.fromJson(jsonDecode(x))).toList();
      _sentArchive = sentStr.map((x) => Goal.fromJson(jsonDecode(x))).toList();
      _senderAuto = p.getBool('gf_sender_auto') ?? true;
      if (rStr != null) {
        _rates = Map<String, double>.from(jsonDecode(rStr));
      }
    });
  }

  Future<void> _saveState() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('gf_default_currency', _defaultCurrency);
    await p.setStringList('gf_goals', _goals.map((g) => jsonEncode(g.toJson())).toList());
    await p.setStringList('gf_archived', _archivedGoals.map((g) => jsonEncode(g.toJson())).toList());
    await p.setStringList('gf_txs', _transactions.map((t) => jsonEncode(t.toJson())).toList());
    await p.setBool('gf_exp_from_goals', _expensesFromGoals);
    await p.setStringList('gf_senders', _senders.map((g) => jsonEncode(g.toJson())).toList());
    await p.setStringList('gf_sent', _sentArchive.map((g) => jsonEncode(g.toJson())).toList());
    await p.setBool('gf_sender_auto', _senderAuto);
    await p.setString('gf_rates', jsonEncode(_rates));
  }

  Future<void> _fetchRates(bool manual) async {
    setState(() => _ratesStatus = 'loading');
    try {
      final res = await http.get(Uri.parse('https://open.er-api.com/v6/latest/RUB')).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['result'] == 'success') {
          final r = d['rates'] as Map<String, dynamic>;
          final nr = {'RUB': 1.0};
          for (var c in ['USD', 'EUR', 'TJS', 'CNY']) {
            if (r[c] != null) nr[c] = 1.0 / (r[c] as num).toDouble();
          }
          if (!mounted) return;
          setState(() {
            _rates = nr;
            _ratesUpdated = DateTime.now().millisecondsSinceEpoch;
            _ratesStatus = 'ok';
          });
          _saveState();
          if (manual) _toast('Курсы валют обновлены ✓');
          return;
        }
      }
      throw Exception();
    } catch (_) {
      if (!mounted) return;
      setState(() => _ratesStatus = 'error');
      if (manual) _toast('Не удалось обновить курс (используются резервные)');
    }
  }

  double _toRub(double amt, String cur) => amt * (_rates[cur] ?? 1.0);
  double _fromRub(double rub, String cur) => rub / (_rates[cur] ?? 1.0);

  String _fmt(double rub, [String? cur]) {
    final c = cur ?? _defaultCurrency;
    final val = _fromRub(rub, c);
    final sym = AppConstants.symbols[c] ?? c;
    final f = NumberFormat('#,##0', 'ru_RU');
    if (c == 'USD' || c == 'EUR') {
      return '$sym${val.toStringAsFixed(val.abs() < 100 ? 2 : 0)}';
    }
    return '${f.format(val.round())} $sym';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: AppColors.panel2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────
  // ЛОГИКА ТРАНЗАКЦИЙ И ЦЕЛЕЙ
  // ─────────────────────────────────────────────
  void _submitTx(String type, double amount, String cur, String? goalId, String note) {
    final rub = _toRub(amount, cur);
    final isAuto = type == 'income' && (goalId == null || goalId == 'auto');
    String? gTitle;
    bool affectsGoal = false;

    if (type == 'income') {
      if (isAuto) {
        // Цели + Отправитель делят доход по одной системе (пропорционально остатку)
        final pool = <Goal>[..._goals, if (_senderAuto) ..._senders];
        if (pool.isNotEmpty) {
          final totalLeft = pool.fold(0.0, (s, g) => s + max(0.0, g.target - g.current));
          if (totalLeft <= 0) {
            pool.first.current += rub;
          } else if (rub >= totalLeft) {
            for (final g in pool) {
              g.current = max(g.current, g.target);
            }
            pool.first.current += rub - totalLeft;
          } else {
            for (final g in pool) {
              final left = max(0.0, g.target - g.current);
              g.current += (left / totalLeft) * rub;
            }
          }
        }
      } else {
        final g = _findItem(goalId);
        if (g != null) {
          g.current += rub;
          gTitle = g.title;
        }
      }
    } else {
      // Expense
      if (goalId != null && goalId != 'none' && _expensesFromGoals) {
        final g = _findItem(goalId);
        if (g != null) {
          g.current = max(0.0, g.current - rub);
          gTitle = g.title;
          affectsGoal = true;
        }
      }
    }

    final tx = TransactionRecord(
      id: _uuid.v4(),
      date: DateTime.now().millisecondsSinceEpoch,
      type: type,
      amount: amount,
      cur: cur,
      rub: rub,
      note: note,
      isAuto: isAuto,
      goalId: isAuto ? null : goalId,
      goalTitle: gTitle,
      affectsGoal: affectsGoal,
    );

    setState(() => _transactions.insert(0, tx));
    _saveState();
    _checkGoalCompletion();
    _toast(type == 'income' ? '+${_fmt(rub)}' : '-${_fmt(rub)}');
  }

  Goal? _findItem(String? id) {
    if (id == null) return null;
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    for (final g in _senders) {
      if (g.id == id) return g;
    }
    return null;
  }

  void _checkGoalCompletion() {
    for (final g in _goals) {
      if (g.current >= g.target && !g.completionShown) {
        g.completionShown = true;
        _saveState();
        _showCompleteDialog(g);
        return;
      }
    }
    for (final s in _senders) {
      if (s.current >= s.target && !s.completionShown) {
        s.completionShown = true;
        _saveState();
        _showSenderReadyDialog(s);
        return;
      }
    }
  }

  void _showSenderReadyDialog(Goal s) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.line)),
        title: const Column(
          children: [
            Text('📤', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text('Пора отправлять!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text('«${s.title}» — нужная сумма собрана: ${_fmt(s.current, s.originalCurrency)}', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _markSent(s);
            },
            child: const Text('✈️ Отправлено', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Позже', style: TextStyle(color: AppColors.muted)),
          )
        ],
      ),
    );
  }

  void _confirmSent(Goal s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Отметить отправленным?'),
        content: Text('Накоплено: ${_fmt(s.current, s.originalCurrency)}. Эта сумма запишется как расход, а отправка уйдёт в историю.', style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              Navigator.pop(context);
              _markSent(s);
            },
            child: const Text('Отправлено', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _markSent(Goal s) {
    final amt = s.current;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      s.completedAt = now;
      _sentArchive.insert(0, s);
      _senders.removeWhere((x) => x.id == s.id);
      if (amt > 0) {
        _transactions.insert(0, TransactionRecord(
          id: _uuid.v4(),
          date: now,
          type: 'expense',
          amount: _fromRub(amt, s.originalCurrency),
          cur: s.originalCurrency,
          rub: amt,
          note: 'Отправлено: ${s.title}',
          goalTitle: s.title,
        ));
      }
    });
    _saveState();
    _toast('Отправка записана ✈️');
  }

  void _showCompleteDialog(Goal g) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.line)),
        title: const Column(
          children: [
            Text('🎉', style: TextStyle(fontSize: 48)),
            SizedBox(height: 8),
            Text('Цель достигнута!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text('«${g.title}» — вся сумма собрана!', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                g.completedAt = DateTime.now().millisecondsSinceEpoch;
                _archivedGoals.insert(0, g);
                _goals.removeWhere((x) => x.id == g.id);
              });
              _saveState();
              _toast('Цель отправлена в архив 📦');
            },
            child: const Text('📦 Отправить в архив', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveState();
            },
            child: const Text('Продолжить копить', style: TextStyle(color: AppColors.muted)),
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // UI МОДАЛКИ: ЦЕЛЬ И ТРАНЗАКЦИЯ
  // ─────────────────────────────────────────────
  void _openGoalModal([Goal? editGoal, bool sender = false]) {
    final titleCtrl = TextEditingController(text: editGoal?.title ?? '');
    final targetCtrl = TextEditingController(text: editGoal != null ? _fromRub(editGoal.target, editGoal.originalCurrency).round().toString() : '');
    String icon = editGoal?.icon ?? (sender ? 'send' : 'target');
    String cur = editGoal?.originalCurrency ?? _defaultCurrency;
    DateTime? deadline = editGoal?.deadline != null ? DateTime.tryParse(editGoal!.deadline!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(editGoal == null ? (sender ? 'Новая отправка' : 'Новая цель') : (sender ? 'Редактировать отправку' : 'Редактировать цель'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  decoration: _inputDeco(sender ? 'Кому / зачем (например: Маме в Таджикистан)' : 'Название (например: Накопить на машину)'),
                ),
                const SizedBox(height: 14),
                const Text('ИКОНКА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (sender
                      ? ['send', 'family', 'bank', 'home', 'gift', 'heart', 'money', 'globe']
                      : ['target', 'money', 'home', 'car', 'phone', 'laptop', 'plane', 'gift', 'star', 'heart']).map((k) {
                    final active = icon == k;
                    return GestureDetector(
                      onTap: () => setMState(() => icon = k),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: active ? AppColors.accentSoft : AppColors.panel2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? AppColors.accent : AppColors.line),
                        ),
                        child: Icon(getGoalIconData(k), color: active ? AppColors.accent : AppColors.muted, size: 22),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco(sender ? 'Сумма к отправке' : 'Целевая сумма'),
                ),
                const SizedBox(height: 14),
                Text(sender ? 'ВАЛЮТА ОТПРАВКИ' : 'ВАЛЮТА ЦЕЛИ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: AppConstants.currencies.map((c) {
                    final active = cur == c;
                    return ChoiceChip(
                      label: Text('${AppConstants.symbols[c]} $c'),
                      selected: active,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.panel2,
                      labelStyle: TextStyle(color: active ? Colors.white : AppColors.muted, fontWeight: FontWeight.bold),
                      onSelected: (_) => setMState(() => cur = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(deadline == null ? 'Установить дедлайн (необязательно)' : 'Дедлайн: ${DateFormat('dd.MM.yyyy').format(deadline!)}', style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.accent),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setMState(() => deadline = picked);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final t = titleCtrl.text.trim();
                    final amt = double.tryParse(targetCtrl.text) ?? 0.0;
                    if (t.isEmpty || amt <= 0) {
                      _toast('Заполните название и сумму');
                      return;
                    }
                    final rubTarget = _toRub(amt, cur);
                    setState(() {
                      if (editGoal != null) {
                        editGoal.title = t;
                        editGoal.target = rubTarget;
                        if (editGoal.current < rubTarget) editGoal.completionShown = false;
                        editGoal.icon = icon;
                        editGoal.originalCurrency = cur;
                        editGoal.deadline = deadline?.toIso8601String().split('T').first;
                      } else {
                        (sender ? _senders : _goals).add(Goal(
                          id: _uuid.v4(),
                          title: t,
                          icon: icon,
                          target: rubTarget,
                          current: 0,
                          originalCurrency: cur,
                          deadline: deadline?.toIso8601String().split('T').first,
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                        ));
                      }
                    });
                    _saveState();
                    Navigator.pop(context);
                  },
                  child: Text(editGoal == null ? (sender ? 'Добавить отправку' : 'Создать цель') : 'Сохранить', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openTxModal([String defaultType = 'income', String? preselectedGoalId]) {
    String type = defaultType;
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String cur = _defaultCurrency;
    String targetGoal = (type == 'expense' && !_expensesFromGoals)
        ? 'none'
        : (preselectedGoalId ?? (type == 'income' ? 'auto' : 'none'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setMState(() { type = 'income'; targetGoal = 'auto'; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: type == 'income' ? AppColors.green : AppColors.panel2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('+ Доход', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setMState(() { type = 'expense'; targetGoal = 'none'; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: type == 'expense' ? AppColors.red : AppColors.panel2,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('- Расход', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDeco('Сумма'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: AppConstants.currencies.map((c) {
                    final active = cur == c;
                    return ChoiceChip(
                      label: Text('${AppConstants.symbols[c]} $c'),
                      selected: active,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.panel2,
                      labelStyle: TextStyle(color: active ? Colors.white : AppColors.muted, fontWeight: FontWeight.bold),
                      onSelected: (_) => setMState(() => cur = c),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Text(type == 'income' ? 'КУДА НАПРАВИТЬ' : 'СПИСАТЬ С ЦЕЛИ?', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(type == 'income' ? (_senderAuto && _senders.isNotEmpty ? 'Авто: цели + отправитель' : 'Все цели') : 'Просто расход'),
                      selected: targetGoal == (type == 'income' ? 'auto' : 'none'),
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.panel2,
                      onSelected: (_) => setMState(() => targetGoal = type == 'income' ? 'auto' : 'none'),
                    ),
                    if (type == 'income' || _expensesFromGoals) ...[..._goals, ..._senders].map((g) => ChoiceChip(
                      label: Text(_senders.any((x) => x.id == g.id) ? '📤 ${g.title}' : g.title),
                      selected: targetGoal == g.id,
                      selectedColor: AppColors.accent,
                      backgroundColor: AppColors.panel2,
                      onSelected: (_) => setMState(() => targetGoal = g.id),
                    ))
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  decoration: _inputDeco('Заметка (необязательно)'),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final amt = double.tryParse(amtCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (amt <= 0) { _toast('Введите корректную сумму'); return; }
                    Navigator.pop(context);
                    _submitTx(type, amt, cur, targetGoal, noteCtrl.text.trim());
                  },
                  child: const Text('Добавить', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF555B68), fontSize: 14),
    filled: true,
    fillColor: AppColors.panel2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  // ─────────────────────────────────────────────
  // ВКЛАДКИ
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getTitle(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(_getSub(), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.line)),
            ),
            icon: const Icon(Icons.language_rounded, size: 16, color: AppColors.accent),
            label: Text(_defaultCurrency, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
            onPressed: _showCurrencyPicker,
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(),
          _buildGoalsTab(),
          _buildWalletTab(),
          _buildReportTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        backgroundColor: AppColors.panel,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes_rounded), label: 'Цели'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Валюты'),
          BottomNavigationBarItem(icon: Icon(Icons.assessment_rounded), label: 'Отчёт'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_tabIndex) {
      case 0: return 'Главная';
      case 1: return 'Мои цели';
      case 2: return 'Валюты';
      case 3: return 'Отчёт';
      default: return 'Профиль';
    }
  }

  String _getSub() {
    switch (_tabIndex) {
      case 0: return 'Обзор';
      case 1: return 'Цели и отправитель';
      case 2: return 'Конвертер и курсы';
      case 3: return 'Деньги · История · Архив';
      default: return 'Настройки';
    }
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Валюта по умолчанию', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            ...AppConstants.currencies.map((c) => ListTile(
              leading: Text(AppConstants.flags[c]!, style: const TextStyle(fontSize: 24)),
              title: Text('${AppConstants.symbols[c]} $c', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(AppConstants.names[c]!),
              trailing: _defaultCurrency == c ? const Icon(Icons.check_circle, color: AppColors.accent) : null,
              onTap: () {
                setState(() => _defaultCurrency = c);
                _saveState();
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 1. ВКЛАДКА: ГЛАВНАЯ
  // ─────────────────────────────────────────────
  Widget _buildHomeTab() {
    final totalTarget = _goals.fold(0.0, (s, g) => s + g.target);
    final totalCurrent = _goals.fold(0.0, (s, g) => s + g.current);
    final pct = totalTarget > 0 ? min(1.0, totalCurrent / totalTarget) : 0.0;
    final left = max(0.0, totalTarget - totalCurrent);

    double earned = 0, spent = 0;
    for (var t in _transactions) {
      if (t.type == 'income') earned += t.rub;
      else spent += t.rub;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ВСЕГО НАКОПЛЕНО', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(8)),
                    child: Text('${AppConstants.flags[_defaultCurrency]} $_defaultCurrency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(_fmt(totalCurrent), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text('Из ${_fmt(totalTarget)} · цель', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.panel2,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(pct * 100).toStringAsFixed(1)}% от общей цели', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  Text('Осталось ${_fmt(left)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text)),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.line),
              const SizedBox(height: 6),
              const Text('Накоплено во всех валютах', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: AppConstants.currencies.where((c) => c != _defaultCurrency).map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${AppConstants.flags[c]} $c', style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_fmt(totalCurrent, c), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }).toList(),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2 Stats Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_downward_rounded, color: AppColors.green, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Заработано', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          Text(_fmt(earned), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_upward_rounded, color: AppColors.red, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Потрачено', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          Text(_fmt(spent), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section: Мои цели
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('МОИ ЦЕЛИ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text('Добавить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              onPressed: () => _openGoalModal(),
            )
          ],
        ),
        if (_goals.isEmpty)
          _emptyState('У тебя пока нет целей', 'Создай первую цель — накопить на телефон, путешествие или автомобиль.')
        else
          ..._goals.take(3).map((g) => _buildGoalCard(g)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ОТПРАВИТЕЛЬ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text('Добавить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
              onPressed: () => _openGoalModal(null, true),
            )
          ],
        ),
        if (_senders.isEmpty)
          GestureDetector(
            onTap: () => setState(() {
              _tabIndex = 1;
              _goalsSection = 'sender';
            }),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
              child: const Row(
                children: [
                  Icon(Icons.send_rounded, color: AppColors.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Копишь деньги, чтобы кому-то отправить? Добавь в «Отправитель» — они будут распределяться вместе с целями.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                ],
              ),
            ),
          )
        else
          ..._senders.take(2).map((g) => _buildGoalCard(g, sender: true)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 2. ВКЛАДКА: ЦЕЛИ
  // ─────────────────────────────────────────────
  Widget _buildGoalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              _segBtn('🎯 Цели (${_goals.length})', 'goals'),
              _segBtn('📤 Отправитель (${_senders.length})', 'sender'),
            ],
          ),
        ),
        if (_goalsSection == 'goals') ..._goalsSectionItems() else ..._senderSectionItems(),
      ],
    );
  }

  Widget _segBtn(String title, String key) {
    final active = _goalsSection == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _goalsSection = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.muted)),
          ),
        ),
      ),
    );
  }

  List<Widget> _goalsSectionItems() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('ВСЕ ЦЕЛИ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
            label: const Text('Добавить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            onPressed: () => _openGoalModal(),
          )
        ],
      ),
      if (_goals.isEmpty)
        _emptyState('Целей нет', 'Нажмите "Добавить", чтобы запустить финансовую цель.')
      else
        ..._goals.map((g) => _buildGoalCard(g)),
    ];
  }

  List<Widget> _senderSectionItems() {
    final total = _senders.fold(0.0, (s, g) => s + g.target);
    final saved = _senders.fold(0.0, (s, g) => s + g.current);
    final pct = total > 0 ? min(1.0, saved / total) : 0.0;
    final left = max(0.0, total - saved);

    return [
      Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0x264F7CFF), Color(0x1422C55E)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x404F7CFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('НАКОПЛЕНО К ОТПРАВКЕ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(_fmt(saved), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text('Из ${_fmt(total)} · всего к отправке', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppColors.panel2,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(pct * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text('Осталось ${_fmt(left)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _senderAuto
                  ? 'Каждый доход автоматически делится между целями и отправками.'
                  : 'Авто-распределение выключено: деньги попадут сюда только если выбрать отправку вручную (настройка в Профиле).',
              style: TextStyle(fontSize: 11, color: _senderAuto ? AppColors.muted : AppColors.orange),
            ),
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('ОТПРАВКИ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
          TextButton.icon(
            icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
            label: const Text('Добавить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
            onPressed: () => _openGoalModal(null, true),
          )
        ],
      ),
      if (_senders.isEmpty)
        _emptyState('Отправок нет', 'Добавь сумму, которую нужно кому-то отправить, например 5000 сомони в Таджикистан. Она будет копиться из твоих доходов вместе с целями.')
      else
        ..._senders.map((g) => _buildGoalCard(g, sender: true)),
      if (_sentArchive.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('ОТПРАВЛЕНО (${_sentArchive.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ..._sentArchive.map((g) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(g.completedAt != null ? DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(g.completedAt!)) : '', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              Text(_fmt(g.current, g.originalCurrency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                onPressed: () {
                  setState(() => _sentArchive.removeWhere((x) => x.id == g.id));
                  _saveState();
                },
              ),
            ],
          ),
        )),
      ],
    ];
  }

  Widget _buildGoalCard(Goal g, {bool sender = false}) {
    final pct = g.target > 0 ? min(1.0, g.current / g.target) : 0.0;
    final left = max(0.0, g.target - g.current);
    final done = g.current >= g.target;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(getGoalIconData(g.icon), color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${_fmt(g.current, g.originalCurrency)} из ${_fmt(g.target, g.originalCurrency)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text('${(pct * 100).toInt()}%', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15)),
              PopupMenuButton<String>(
                color: AppColors.panel2,
                icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 20),
                onSelected: (val) {
                  if (val == 'edit') _openGoalModal(g, sender);
                  if (val == 'income') _openTxModal('income', g.id);
                  if (val == 'expense') _openTxModal('expense', g.id);
                  if (val == 'sent') _confirmSent(g);
                  if (val == 'delete') {
                    setState(() {
                      if (sender) {
                        _senders.removeWhere((x) => x.id == g.id);
                      } else {
                        _goals.removeWhere((x) => x.id == g.id);
                      }
                    });
                    _saveState();
                    _toast(sender ? 'Отправка удалена' : 'Цель удалена');
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'income', child: Text('Добавить доход')),
                  if (sender) const PopupMenuItem(value: 'sent', child: Text('Отметить отправленным')),
                  if (!sender) const PopupMenuItem(value: 'expense', child: Text('Добавить расход')),
                  const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить', style: TextStyle(color: AppColors.red))),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.panel2,
              valueColor: AlwaysStoppedAnimation(done ? AppColors.green : AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(done ? (sender ? '✅ Готово к отправке!' : '🎉 Цель выполнена!') : 'Осталось: ${_fmt(left, g.originalCurrency)}', style: TextStyle(fontSize: 12, color: done ? AppColors.green : AppColors.muted)),
              if (g.deadline != null)
                Text('До ${g.deadline}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          )
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 3. ВКЛАДКА: ВАЛЮТЫ (КОНВЕРТЕР И КУРСЫ)
  // ─────────────────────────────────────────────
  Widget _buildWalletTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Статус курсов
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: _ratesStatus == 'ok' ? AppColors.green : (_ratesStatus == 'error' ? AppColors.red : AppColors.orange), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_ratesStatus == 'ok' && _ratesUpdated != null ? 'Обновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_ratesUpdated!))}' : 'Курсы по умолчанию', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14, color: AppColors.accent),
                label: const Text('Обновить', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _fetchRates(true),
              )
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Карточка конвертера
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ИЗ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _convFromCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        final rub = _toRub(val, _convFrom);
                        _convToCtrl.text = _fromRub(rub, _convTo).toStringAsFixed(2);
                      },
                      decoration: _inputDeco('0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _convFrom,
                    dropdownColor: AppColors.panel2,
                    underline: const SizedBox(),
                    items: AppConstants.currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _convFrom = v);
                        final val = double.tryParse(_convFromCtrl.text) ?? 0.0;
                        _convToCtrl.text = _fromRub(_toRub(val, _convFrom), _convTo).toStringAsFixed(2);
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                  icon: const Icon(Icons.swap_vert, size: 20),
                  onPressed: () {
                    setState(() {
                      final t = _convFrom;
                      _convFrom = _convTo;
                      _convTo = t;
                    });
                    final val = double.tryParse(_convFromCtrl.text) ?? 0.0;
                    _convToCtrl.text = _fromRub(_toRub(val, _convFrom), _convTo).toStringAsFixed(2);
                  },
                ),
              ),
              const SizedBox(height: 10),
              const Text('В', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _convToCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) {
                        final val = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
                        final rub = _toRub(val, _convTo);
                        _convFromCtrl.text = _fromRub(rub, _convFrom).toStringAsFixed(2);
                      },
                      decoration: _inputDeco('0'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _convTo,
                    dropdownColor: AppColors.panel2,
                    underline: const SizedBox(),
                    items: AppConstants.currencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _convTo = v);
                        final val = double.tryParse(_convFromCtrl.text) ?? 0.0;
                        _convToCtrl.text = _fromRub(_toRub(val, _convFrom), _convTo).toStringAsFixed(2);
                      }
                    },
                  )
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text('КУРСЫ К РУБЛЮ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        ...['USD', 'EUR', 'CNY', 'TJS'].map((c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(AppConstants.flags[c]!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppConstants.names[c]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('1 $c = ${_rates[c]?.toStringAsFixed(2)} ₽', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  )
                ],
              ),
              Text('${_rates[c]?.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        )),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 4. ВКЛАДКА: ОТЧЁТ (ДЕНЬГИ, ИСТОРИЯ, АРХИВ)
  // ─────────────────────────────────────────────
  Widget _buildReportTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              _subTabBtn('💰 О деньгах', 'money'),
              _subTabBtn('📜 История (${_transactions.length})', 'history'),
              _subTabBtn('📦 Архив (${_archivedGoals.length})', 'archive'),
            ],
          ),
        ),
        Expanded(
          child: _reportTab == 'money'
            ? _buildMoneyReport()
            : (_reportTab == 'history' ? _buildHistoryReport() : _buildArchiveReport()),
        )
      ],
    );
  }

  Widget _subTabBtn(String title, String key) {
    final active = _reportTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _reportTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.muted)),
          ),
        ),
      ),
    );
  }

  Widget _buildMoneyReport() {
    double earned = 0, spent = 0;
    for (var t in _transactions) {
      if (t.type == 'income') earned += t.rub;
      else spent += t.rub;
    }
    final net = earned - spent;
    final totalInGoals = _goals.fold(0.0, (s, g) => s + g.current);
    final totalArchived = _archivedGoals.fold(0.0, (s, g) => s + g.target);
    final totalInSenders = _senders.fold(0.0, (s, g) => s + g.current);
    final totalSent = _sentArchive.fold(0.0, (s, g) => s + g.current);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0x264F7CFF), Color(0x1422C55E)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x404F7CFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ОБЩИЙ БАЛАНС', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted)),
              const SizedBox(height: 6),
              Text(_fmt(net), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: net >= 0 ? AppColors.green : AppColors.red)),
              const SizedBox(height: 4),
              Text('Заработано ${_fmt(earned)} · потрачено ${_fmt(spent)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.8,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _statTile('🎯 В активных целях', _fmt(totalInGoals), AppColors.text),
            _statTile('📦 В архиве', _fmt(totalArchived), AppColors.text),
            _statTile('+ Заработано', _fmt(earned), AppColors.green),
            _statTile('- Потрачено', _fmt(spent), AppColors.red),
            _statTile('📤 В отправителе', _fmt(totalInSenders), AppColors.text),
            _statTile('✈️ Отправлено', _fmt(totalSent), AppColors.text),
          ],
        ),
        const SizedBox(height: 16),
        if (_goals.isNotEmpty) ...[
          const Text('РАЗБИВКА ПО ЦЕЛЯМ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
          const SizedBox(height: 10),
          ..._goals.map((g) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
            child: Row(
              children: [
                Icon(getGoalIconData(g.icon), color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Text(_fmt(g.current, g.originalCurrency), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ))
        ]
      ],
    );
  }

  Widget _statTile(String title, String val, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
      ],
    ),
  );

  Widget _buildHistoryReport() {
    if (_transactions.isEmpty) {
      return _emptyState('Операций пока нет', 'Добавьте доход или расход через меню.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transactions.length,
      itemBuilder: (_, i) {
        final t = _transactions[i];
        final isInc = t.type == 'income';
        final sym = AppConstants.symbols[t.cur] ?? t.cur;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: isInc ? AppColors.greenSoft : AppColors.redSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(isInc ? Icons.add : Icons.remove, color: isInc ? AppColors.green : AppColors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.note.isNotEmpty ? t.note : (t.goalTitle != null ? t.goalTitle! : (isInc ? 'Пополнение' : 'Расход')), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(t.date)), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isInc ? '+' : '-'}${t.amount.toStringAsFixed(0)} $sym', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isInc ? AppColors.green : AppColors.red)),
                  if (t.cur != _defaultCurrency)
                    Text(_fmt(t.rub), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                onPressed: () {
                  setState(() => _transactions.removeAt(i));
                  _saveState();
                  _toast('Операция удалена');
                },
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchiveReport() {
    if (_archivedGoals.isEmpty) {
      return _emptyState('Архив пуст', 'Здесь появятся завершённые цели.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _archivedGoals.length,
      itemBuilder: (_, i) {
        final g = _archivedGoals[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Icon(getGoalIconData(g.icon), color: AppColors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${_fmt(g.target, g.originalCurrency)} · Закрыто', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(6)),
                child: const Text('Готово', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 11)),
              )
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // 5. ВКЛАДКА: ПРОФИЛЬ И НАСТРОЙКИ
  // ─────────────────────────────────────────────
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 10),
              const Text('Мой профиль', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${_goals.length} целей · ${_senders.length} отправок · ${_archivedGoals.length} в архиве', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('НАСТРОЙКИ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppColors.panel,
          title: const Text('Учитывать расходы в целях', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(_expensesFromGoals ? 'Включено · списывается с цели' : 'Выключено · расходы отдельно', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          value: _expensesFromGoals,
          activeColor: AppColors.accent,
          onChanged: (v) {
            setState(() => _expensesFromGoals = v);
            _saveState();
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: AppColors.panel,
          title: const Text('Отправитель в авто-распределении', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(_senderAuto ? 'Включено · доход делится на цели и отправки' : 'Выключено · доход делится только на цели', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          value: _senderAuto,
          activeColor: AppColors.accent,
          onChanged: (v) {
            setState(() => _senderAuto = v);
            _saveState();
          },
        ),
        const SizedBox(height: 8),
        _menuTile(Icons.language, 'Валюта по умолчанию', '$_defaultCurrency — ${AppConstants.names[_defaultCurrency]}', _showCurrencyPicker),
        _menuTile(Icons.add_circle_outline, 'Создать цель', 'Добавить новую финансовую цель', () => _openGoalModal()),
        _menuTile(Icons.send_rounded, 'Создать отправку', 'Деньги, которые нужно кому-то отправить', () => _openGoalModal(null, true)),
        _menuTile(Icons.arrow_downward, 'Добавить доход', 'Распределить деньги по целям', () => _openTxModal('income')),
        _menuTile(Icons.arrow_upward, 'Добавить расход', 'Записать трату', () => _openTxModal('expense')),
        _menuTile(Icons.delete_forever, 'Сбросить всё', 'Удалить все данные и очистить базу', () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Сбросить всё?'),
              content: const Text('Это удалит все ваши цели и транзакции.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: () async {
                    final p = await SharedPreferences.getInstance();
                    await p.clear();
                    if (!mounted) return;
                    setState(() {
                      _goals.clear();
                      _archivedGoals.clear();
                      _transactions.clear();
                      _senders.clear();
                      _sentArchive.clear();
                    });
                    Navigator.pop(context);
                    _toast('Все данные очищены');
                  },
                  child: const Text('Сбросить', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }, color: AppColors.red),
      ],
    );
  }

  Widget _menuTile(IconData icon, String title, String sub, VoidCallback onTap, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: AppColors.panel,
        leading: Icon(icon, color: color ?? AppColors.accent),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? AppColors.text)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _emptyState(String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

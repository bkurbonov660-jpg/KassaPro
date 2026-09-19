import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models/models.dart';
import 'services/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bg,
  ));
  runApp(const KassaproApp());
}

class AppTheme {
  static const bg = Color(0xFF0D0F14);
  static const surface = Color(0xFF161922);
  static const card = Color(0xFF1E2330);
  static const border = Color(0xFF2A3142);

  static const green = Color(0xFF10B981);
  static const coral = Color(0xFFF43F5E);
  static const yellow = Color(0xFFF59E0B);
  static const blue = Color(0xFF38BDF8);
  static const purple = Color(0xFFA855F7);

  static const textPri = Color(0xFFF8FAFC);
  static const textSec = Color(0xFF94A3B8);

  static final fmt = NumberFormat("#,##0.##", "ru_RU");

  static const noteColors = [
    Color(0xFF1E2330),
    Color(0xFF132E27),
    Color(0xFF2F1D26),
    Color(0xFF1E283A),
    Color(0xFF2A2035),
  ];
}

class KassaproApp extends StatelessWidget {
  const KassaproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kassapro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppTheme.surface,
          primary: AppTheme.blue,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// ---------------- PIN-КОД ЗАЩИТА ----------------
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  String _savedPin = '';
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkPin();
  }

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPin = prefs.getString('kp_pin') ?? '';
      _ready = true;
      if (_savedPin.isEmpty) _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: AppTheme.bg);
    if (!_unlocked) {
      return PinLockScreen(
        savedPin: _savedPin,
        onSuccess: () => setState(() => _unlocked = true),
      );
    }
    return const MainDashboardScreen();
  }
}

class PinLockScreen extends StatefulWidget {
  final String savedPin;
  final VoidCallback onSuccess;
  const PinLockScreen({super.key, required this.savedPin, required this.onSuccess});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entered = '';
  bool _error = false;

  void _pressKey(String digit) {
    if (_entered.length < 4) {
      setState(() {
        _entered += digit;
        _error = false;
      });
      if (_entered.length == 4) {
        if (_entered == widget.savedPin) {
          widget.onSuccess();
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _error = true;
            _entered = '';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 64, color: AppTheme.blue),
            const SizedBox(height: 20),
            const Text('Kassapro Защита', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPri)),
            const SizedBox(height: 8),
            Text(
              _error ? 'Неверный PIN! Попробуйте снова' : 'Введите 4-значный PIN-код',
              style: TextStyle(color: _error ? AppTheme.coral : AppTheme.textSec, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _entered.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.blue : Colors.transparent,
                    border: Border.all(color: _error ? AppTheme.coral : AppTheme.border, width: 2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  ...List.generate(9, (i) => _numBtn('${i + 1}')),
                  IconButton(
                    icon: const Icon(Icons.fingerprint, size: 36, color: AppTheme.textSec),
                    onPressed: widget.onSuccess,
                  ),
                  _numBtn('0'),
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, size: 28, color: AppTheme.textSec),
                    onPressed: () {
                      if (_entered.isNotEmpty) setState(() => _entered = _entered.substring(0, _entered.length - 1));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numBtn(String text) => ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.card,
      foregroundColor: AppTheme.textPri,
      shape: const CircleBorder(),
      elevation: 0,
    ),
    onPressed: () => _pressKey(text),
    child: Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
  );
}

// ---------------- ОСНОВНОЙ ДАШБОРД ----------------
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});
  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _navIndex = 0;
  int _debtFilter = 0; // 0: Все активные, 1: Мне должны, 2: Я должен, 3: Закрытые
  String _currency = 'сом.';
  List<Debt> _debts = [];
  List<NoteItem> _notes = [];
  String _noteSearch = '';
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  Future<void> _loadStorage() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _currency = p.getString('kp_currency') ?? 'сом.';
      _debts = (p.getStringList('kp_debts') ?? []).map((e) => Debt.fromJson(jsonDecode(e))).toList();
      _notes = (p.getStringList('kp_notes') ?? []).map((e) => NoteItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveStorage() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('kp_debts', _debts.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('kp_notes', _notes.map((e) => jsonEncode(e.toJson())).toList());
    await p.setString('kp_currency', _currency);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIndex,
        children: [_buildDebtsPage(), _buildNotesPage(), _buildSettingsPage()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _navIndex,
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.card,
          onDestinationSelected: (i) => setState(() => _navIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.blue), label: 'Долги'),
            NavigationDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt, color: AppTheme.yellow), label: 'Заметки'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune, color: AppTheme.purple), label: 'Опции'),
          ],
        ),
      ),
      floatingActionButton: _navIndex < 2
          ? FloatingActionButton.extended(
              backgroundColor: _navIndex == 0 ? AppTheme.blue : AppTheme.yellow,
              foregroundColor: Colors.black,
              onPressed: _navIndex == 0 ? _addDebtDialog : _addNoteDialog,
              icon: const Icon(Icons.add, weight: 700),
              label: Text(_navIndex == 0 ? 'Запись' : 'Заметка', style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ---------------- 1. СТРАНИЦА ДОЛГОВ ----------------
  Widget _buildDebtsPage() {
    double theyOwe = 0;
    double iOwe = 0;
    List<Debt> alertDebts = [];

    for (var d in _debts) {
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;

        if (d.dueDate != null) {
          final days = d.dueDate!.difference(DateTime.now()).inDays;
          if (days <= 3) alertDebts.add(d);
        }
      }
    }
    double net = theyOwe - iOwe;

    List<Debt> filtered = _debts.where((d) {
      if (_debtFilter == 0) return !d.isPaid;
      if (_debtFilter == 1) return !d.isPaid && d.type == 'they_owe';
      if (_debtFilter == 2) return !d.isPaid && d.type == 'i_owe';
      return d.isPaid;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ВЕРХНЯЯ СТРОКА: ИИ + PDF
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kassapro', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPri)),
              Row(
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.purple.withOpacity(0.15)),
                    icon: const Icon(Icons.auto_awesome, color: AppTheme.purple, size: 20),
                    onPressed: _runAIAnalysis,
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.blue.withOpacity(0.15)),
                    icon: const Icon(Icons.picture_as_pdf, color: AppTheme.blue, size: 20),
                    onPressed: () => PdfReportService.generateAndExport(_debts, _currency),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),

          // 🔔 ПУШ-УВЕДОМЛЕНИЯ / СМАРТ-БАННЕР НАПОМИНАНИЙ
          if (alertDebts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notification_important, color: AppTheme.coral, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Внимание: ${alertDebts.length} долг(а) с истекающим сроком или просрочкой!',
                      style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // СВОДНЫЙ БАЛАНС
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Чистый баланс', style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
                    Text(
                      '${net >= 0 ? "+" : ""}${AppTheme.fmt.format(net)} $_currency',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? AppTheme.green : AppTheme.coral,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppTheme.border, height: 24),
                Row(
                  children: [
                    Expanded(child: _balanceTile('Мне должны', theyOwe, AppTheme.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _balanceTile('Я должен', iOwe, AppTheme.coral)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ФИЛЬТРЫ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Все активные', 0),
                _filterChip('Мне должны', 1),
                _filterChip('Я должен', 2),
                _filterChip('Закрытые', 3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // СПИСОК
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(50),
              alignment: Alignment.center,
              child: const Text('Записей нет', style: TextStyle(color: AppTheme.textSec)),
            )
          else
            ...filtered.map((d) => _buildDebtCard(d)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _balanceTile(String label, double val, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${AppTheme.fmt.format(val)} $_currency', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPri)),
      ],
    ),
  );

  Widget _filterChip(String title, int idx) {
    final active = _debtFilter == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: active,
        onSelected: (_) => setState(() => _debtFilter = idx),
        selectedColor: AppTheme.card,
        backgroundColor: AppTheme.surface,
        labelStyle: TextStyle(color: active ? AppTheme.blue : AppTheme.textSec, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 12),
        side: BorderSide(color: active ? AppTheme.blue : AppTheme.border),
      ),
    );
  }

  // 🚦 СВЕТОФОР ДЕДЛАЙНОВ
  Widget _deadlineBadge(Debt d) {
    if (d.isPaid) {
      return _badge('Погашен', AppTheme.textSec, Icons.check_circle_outline);
    }
    if (d.dueDate == null) {
      return const SizedBox.shrink();
    }
    final days = d.dueDate!.difference(DateTime.now()).inDays;
    if (days < 0) {
      return _badge('Просрочено на ${-days} дн.', AppTheme.coral, Icons.error_outline);
    } else if (days <= 3) {
      return _badge('Осталось $days дн.', AppTheme.yellow, Icons.warning_amber_rounded);
    } else {
      return _badge('Срок через $days дн.', AppTheme.green, Icons.event_available);
    }
  }

  Widget _badge(String text, Color c, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.3))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _buildDebtCard(Debt d) {
    final isThey = d.type == 'they_owe';
    final accent = d.isPaid ? AppTheme.textSec : (isThey ? AppTheme.green : AppTheme.coral);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accent.withOpacity(0.15),
          child: Icon(isThey ? Icons.arrow_downward : Icons.arrow_upward, color: accent, size: 20),
        ),
        title: Row(
          children: [
            Expanded(child: Text(d.personName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: d.isPaid ? TextDecoration.lineThrough : null))),
            Text('${AppTheme.fmt.format(d.amount)} $_currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isThey ? 'Должен вам' : 'Вы должны', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500)),
                _deadlineBadge(d),
              ],
            ),
            if (d.payments.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Выплат: ${d.payments.length} | Изначально: ${AppTheme.fmt.format(d.initialAmount)}', style: const TextStyle(fontSize: 11, color: AppTheme.blue)),
            ],
            if (d.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(d.note, style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
            ]
          ],
        ),
        onTap: () => _openDebtTimelineDetails(d),
      ),
    );
  }

  // 📜 1. ИСТОРИЯ ЧАСТИЧНЫХ ВЫПЛАТ (ТАЙМЛАЙН)
  void _openDebtTimelineDetails(Debt d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.personName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    _deadlineBadge(d),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Текущий остаток: ${AppTheme.fmt.format(d.amount)} $_currency', style: const TextStyle(color: AppTheme.blue, fontSize: 16, fontWeight: FontWeight.w600)),
                const Divider(color: AppTheme.border, height: 28),

                const Text('Таймлайн операций:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSec)),
                const SizedBox(height: 12),

                // Начальная сумма
                _timelineItem(
                  date: DateFormat('dd.MM.yyyy').format(d.createdAt),
                  title: d.type == 'they_owe' ? 'Выдано в долг' : 'Взято в долг',
                  amount: '+${AppTheme.fmt.format(d.initialAmount)} $_currency',
                  isRepayment: false,
                ),

                // История погашений
                ...d.payments.map((p) => _timelineItem(
                  date: DateFormat('dd.MM.yyyy HH:mm').format(p.date),
                  title: 'Частичное погашение',
                  amount: '-${AppTheme.fmt.format(p.amount)} $_currency',
                  isRepayment: true,
                )),

                const SizedBox(height: 24),
                if (!d.isPaid) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Внести частичную выплату', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _partialPayDialog(d, () => setSheetState(() {})),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPri,
                      side: const BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Погасить полностью'),
                    onPressed: () {
                      setState(() {
                        d.payments.add(PaymentRecord(id: _uuid.v4(), amount: d.amount, date: DateTime.now(), comment: 'Полное закрытие'));
                        d.amount = 0;
                        d.isPaid = true;
                      });
                      _saveStorage();
                      Navigator.pop(context);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppTheme.coral),
                  onPressed: () {
                    setState(() => _debts.removeWhere((x) => x.id == d.id));
                    _saveStorage();
                    Navigator.pop(context);
                  },
                  child: const Text('Удалить запись'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timelineItem({required String date, required String title, required String amount, required bool isRepayment}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isRepayment ? Icons.subdirectory_arrow_right : Icons.fiber_manual_record, size: 16, color: isRepayment ? AppTheme.green : AppTheme.blue),
          const SizedBox(width: 8),
          Expanded(child: Text('$date — $title', style: const TextStyle(fontSize: 13, color: AppTheme.textPri))),
          Text(amount, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isRepayment ? AppTheme.green : AppTheme.textPri)),
        ],
      ),
    );
  }

  void _partialPayDialog(Debt d, VoidCallback refreshSheet) {
    final aCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Частичный возврат'),
        content: TextField(
          controller: aCtrl,
          keyboardType: TextInputType.number,
          decoration: _inputDeco('Сумма выплаты'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.green, foregroundColor: Colors.black),
            onPressed: () {
              final paid = double.tryParse(aCtrl.text) ?? 0;
              if (paid > 0) {
                setState(() {
                  final payVal = paid > d.amount ? d.amount : paid;
                  d.payments.add(PaymentRecord(id: _uuid.v4(), amount: payVal, date: DateTime.now()));
                  d.amount -= payVal;
                  if (d.amount <= 0) d.isPaid = true;
                });
                _saveStorage();
                refreshSheet();
              }
              Navigator.pop(context);
            },
            child: const Text('Внести'),
          )
        ],
      ),
    );
  }

  void _addDebtDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'they_owe';
    DateTime? chosenDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Добавить долг', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'they_owe', label: Text('Мне должны')),
                  ButtonSegment(value: 'i_owe', label: Text('Я должен')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setLocal(() => type = v.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: type == 'they_owe' ? AppTheme.green : AppTheme.coral,
                  selectedForegroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: _inputDeco('Имя заемщика / кредитора')),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма ($_currency)')),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppTheme.border)),
                title: Text(
                  chosenDate == null ? 'Указать дату возврата (дедлайн)' : 'Дедлайн: ${DateFormat('dd.MM.yyyy').format(chosenDate!)}',
                  style: TextStyle(color: chosenDate == null ? AppTheme.textSec : AppTheme.blue, fontSize: 13),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18, color: AppTheme.textSec),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now.add(const Duration(days: 7)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 3650)),
                  );
                  if (picked != null) setLocal(() => chosenDate = picked);
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: _inputDeco('Комментарий / заметка')),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (nameCtrl.text.trim().isNotEmpty && amount > 0) {
                    setState(() {
                      _debts.insert(0, Debt(
                        id: _uuid.v4(),
                        personName: nameCtrl.text.trim(),
                        amount: amount,
                        initialAmount: amount,
                        type: type,
                        createdAt: DateTime.now(),
                        dueDate: chosenDate,
                        note: noteCtrl.text.trim(),
                      ));
                    });
                    _saveStorage();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🤖 4. ИИ АНАЛИЗАТОР ПОРТФЕЛЯ
  void _runAIAnalysis() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => FutureBuilder<String>(
        future: AIService.analyzePortfolio(_debts, _currency),
        builder: (context, snap) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: AppTheme.purple),
                    SizedBox(width: 8),
                    Text('ИИ Финансовый Анализ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: AppTheme.border, height: 24),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.purple)),
                  )
                else
                  Text(snap.data ?? 'Ошибка', style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPri)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.purple, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- 2. СТРАНИЦА ЗАМЕТОК ----------------
  Widget _buildNotesPage() {
    final filteredNotes = _notes.where((n) {
      return n.title.toLowerCase().contains(_noteSearch.toLowerCase()) ||
             n.content.toLowerCase().contains(_noteSearch.toLowerCase());
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Заметки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPri)),
              Text('${_notes.length} шт.', style: const TextStyle(color: AppTheme.textSec)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _noteSearch = v),
            decoration: _inputDeco('Поиск по заметкам...').copyWith(prefixIcon: const Icon(Icons.search, color: AppTheme.textSec)),
          ),
          const SizedBox(height: 14),
          if (filteredNotes.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Text('Заметок нет', style: TextStyle(color: AppTheme.textSec)),
            )
          else
            ...filteredNotes.map((n) => _buildNoteCard(n)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteItem n) {
    final color = AppTheme.noteColors[n.colorIndex % AppTheme.noteColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(n.title.isEmpty ? 'Без темы' : n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(n.content, style: const TextStyle(color: AppTheme.textSec, fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Text(DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt), style: const TextStyle(color: AppTheme.border, fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.textSec, size: 20),
          onPressed: () {
            setState(() => _notes.removeWhere((x) => x.id == n.id));
            _saveStorage();
          },
        ),
        onTap: () => _addNoteDialog(editing: n),
      ),
    );
  }

  void _addNoteDialog({NoteItem? editing}) {
    final tCtrl = TextEditingController(text: editing?.title ?? '');
    final cCtrl = TextEditingController(text: editing?.content ?? '');
    int color = editing?.colorIndex ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing == null ? 'Новая заметка' : 'Редактировать', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(controller: tCtrl, decoration: _inputDeco('Заголовок')),
              const SizedBox(height: 10),
              TextField(controller: cCtrl, maxLines: 5, decoration: _inputDeco('Текст заметки...')),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(AppTheme.noteColors.length, (i) {
                  return GestureDetector(
                    onTap: () => setLocal(() => color = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.noteColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: color == i ? AppTheme.yellow : AppTheme.border, width: 2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.yellow,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (tCtrl.text.trim().isNotEmpty || cCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      if (editing != null) {
                        editing.title = tCtrl.text.trim();
                        editing.content = cCtrl.text.trim();
                        editing.colorIndex = color;
                      } else {
                        _notes.insert(0, NoteItem(
                          id: _uuid.v4(),
                          title: tCtrl.text.trim(),
                          content: cCtrl.text.trim(),
                          createdAt: DateTime.now(),
                          colorIndex: color,
                        ));
                      }
                    });
                    _saveStorage();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 3. СТРАНИЦА НАСТРОЕК ----------------
  Widget _buildSettingsPage() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Опции и Защита', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppTheme.card,
            leading: const Icon(Icons.currency_exchange, color: AppTheme.blue),
            title: const Text('Валюта расчетов'),
            subtitle: Text('Текущая: $_currency', style: const TextStyle(color: AppTheme.textSec)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                if (_currency == 'сом.') _currency = '₽';
                else if (_currency == '₽') _currency = '\$';
                else _currency = 'сом.';
              });
              _saveStorage();
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppTheme.card,
            leading: const Icon(Icons.lock_outline, color: AppTheme.yellow),
            title: const Text('Установить / Сменить PIN-код'),
            subtitle: const Text('Блокировка экрана при входе', style: TextStyle(color: AppTheme.textSec)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _setPinDialog,
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppTheme.card,
            leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.coral),
            title: const Text('Очистить все долги и заметки', style: TextStyle(color: AppTheme.coral)),
            onTap: () {
              setState(() {
                _debts.clear();
                _notes.clear();
              });
              _saveStorage();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Данные очищены')));
            },
          ),
        ],
      ),
    );
  }

  void _setPinDialog() {
    final pCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Установка PIN-кода'),
        content: TextField(
          controller: pCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: _inputDeco('Введите 4 цифры (пусто = отключить)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.yellow, foregroundColor: Colors.black),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('kp_pin', pCtrl.text.trim());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN сохранен')));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.textSec, fontSize: 13),
    filled: true,
    fillColor: AppTheme.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );
}

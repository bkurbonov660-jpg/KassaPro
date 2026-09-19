import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppStyle.bg,
  ));
  runApp(const DebtApp());
}

class AppStyle {
  static const bg = Color(0xFF0F1115);
  static const surface = Color(0xFF171B24);
  static const card = Color(0xFF202532);
  static const border = Color(0xFF2C3345);
  
  static const green = Color(0xFF10B981);
  static const coral = Color(0xFFF43F5E);
  static const blue = Color(0xFF38BDF8);
  static const amber = Color(0xFFF59E0B);

  static const textPri = Color(0xFFF8FAFC);
  static const textSec = Color(0xFF94A3B8);

  static final currencyFmt = NumberFormat("#,##0.##", "ru_RU");
}

class DebtApp extends StatelessWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kassapro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppStyle.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppStyle.surface,
          primary: AppStyle.blue,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  List<Debt> _debts = [];
  List<NoteItem> _notes = [];
  String _currency = 'сом.';
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final dList = prefs.getStringList('kp_debts') ?? [];
    final nList = prefs.getStringList('kp_notes') ?? [];
    setState(() {
      _currency = prefs.getString('kp_currency') ?? 'сом.';
      _debts = dList.map((e) => Debt.fromJson(jsonDecode(e))).toList();
      _notes = nList.map((e) => NoteItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('kp_debts', _debts.map((e) => jsonEncode(e.toJson())).toList());
    await prefs.setStringList('kp_notes', _notes.map((e) => jsonEncode(e.toJson())).toList());
    await prefs.setString('kp_currency', _currency);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDebtsView(),
      _buildNotesView(),
      _buildSettingsView(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppStyle.surface,
          border: Border(top: BorderSide(color: AppStyle.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          indicatorColor: AppStyle.card,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: AppStyle.textSec),
              selectedIcon: Icon(Icons.account_balance_wallet, color: AppStyle.blue),
              label: 'Долги',
            ),
            NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined, color: AppStyle.textSec),
              selectedIcon: Icon(Icons.sticky_note_2, color: AppStyle.amber),
              label: 'Заметки',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined, color: AppStyle.textSec),
              selectedIcon: Icon(Icons.tune, color: AppStyle.textPri),
              label: 'Опции',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex < 2
          ? FloatingActionButton.extended(
              backgroundColor: _currentIndex == 0 ? AppStyle.blue : AppStyle.amber,
              foregroundColor: Colors.black,
              onPressed: _currentIndex == 0 ? _openAddDebtDialog : _openAddNoteDialog,
              icon: const Icon(Icons.add, weight: 700),
              label: Text(
                _currentIndex == 0 ? 'Новый долг' : 'Заметка',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  // ===================== ЭКРАН ДОЛГОВ =====================
  int _debtFilter = 0; // 0: все активные, 1: мне должны, 2: я должен, 3: закрытые

  Widget _buildDebtsView() {
    double theyOwe = 0;
    double iOwe = 0;
    for (var d in _debts) {
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }
    double netBalance = theyOwe - iOwe;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Учет долгов', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppStyle.textPri)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppStyle.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppStyle.border)),
                child: Text('Валюта: $_currency', style: const TextStyle(fontSize: 12, color: AppStyle.textSec)),
              )
            ],
          ),
          const SizedBox(height: 16),

          // СВОДКА БАЛАНСА
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppStyle.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppStyle.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Чистый баланс', style: TextStyle(color: AppStyle.textSec, fontSize: 14)),
                    Text(
                      '${netBalance >= 0 ? "+" : ""}${AppStyle.currencyFmt.format(netBalance)} $_currency',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: netBalance >= 0 ? AppStyle.green : AppStyle.coral,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppStyle.border, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppStyle.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppStyle.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Мне должны', style: TextStyle(color: AppStyle.green, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${AppStyle.currencyFmt.format(theyOwe)} $_currency',
                              style: const TextStyle(color: AppStyle.textPri, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppStyle.coral.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppStyle.coral.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Я должен', style: TextStyle(color: AppStyle.coral, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${AppStyle.currencyFmt.format(iOwe)} $_currency',
                              style: const TextStyle(color: AppStyle.textPri, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
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
          const SizedBox(height: 14),

          // СПИСОК ДОЛГОВ
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Text('Записей нет', style: TextStyle(color: AppStyle.textSec)),
            )
          else
            ...filtered.map((d) => _buildDebtCard(d)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _filterChip(String title, int index) {
    final active = _debtFilter == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(title),
        selected: active,
        onSelected: (_) => setState(() => _debtFilter = index),
        selectedColor: AppStyle.card,
        backgroundColor: AppStyle.surface,
        labelStyle: TextStyle(
          color: active ? AppStyle.blue : AppStyle.textSec,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        side: BorderSide(color: active ? AppStyle.blue : AppStyle.border),
      ),
    );
  }

  Widget _buildDebtCard(Debt d) {
    final isTheyOwe = d.type == 'they_owe';
    final accentColor = d.isPaid ? AppStyle.textSec : (isTheyOwe ? AppStyle.green : AppStyle.coral);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyle.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accentColor.withOpacity(0.15),
          child: Icon(
            isTheyOwe ? Icons.arrow_downward : Icons.arrow_upward,
            color: accentColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                d.personName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: d.isPaid ? TextDecoration.lineThrough : null,
                  color: d.isPaid ? AppStyle.textSec : AppStyle.textPri,
                ),
              ),
            ),
            Text(
              '${AppStyle.currencyFmt.format(d.amount)} $_currency',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTheyOwe ? 'Должен вам' : 'Вы должны',
                  style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  DateFormat('dd.MM.yyyy').format(d.createdAt),
                  style: const TextStyle(color: AppStyle.textSec, fontSize: 11),
                ),
              ],
            ),
            if (d.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(d.note, style: const TextStyle(color: AppStyle.textSec, fontSize: 12)),
            ]
          ],
        ),
        onTap: () => _openDebtActions(d),
      ),
    );
  }

  void _openDebtActions(Debt d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(d.personName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Остаток: ${AppStyle.currencyFmt.format(d.amount)} $_currency', style: const TextStyle(color: AppStyle.textSec)),
            const SizedBox(height: 20),
            if (!d.isPaid) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Погасить полностью', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() => d.isPaid = true);
                  _saveData();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppStyle.textPri,
                  side: const BorderSide(color: AppStyle.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Частичная выплата'),
                onPressed: () {
                  Navigator.pop(context);
                  _openPartialPaymentDialog(d);
                },
              ),
              const SizedBox(height: 10),
            ],
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppStyle.coral),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить запись'),
              onPressed: () {
                setState(() => _debts.removeWhere((item) => item.id == d.id));
                _saveData();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPartialPaymentDialog(Debt d) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppStyle.surface,
        title: const Text('Частичный возврат'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Сумма выплаты',
            filled: true,
            fillColor: AppStyle.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppStyle.blue, foregroundColor: Colors.black),
            onPressed: () {
              final paid = double.tryParse(ctrl.text) ?? 0;
              if (paid > 0) {
                setState(() {
                  if (paid >= d.amount) {
                    d.amount = 0;
                    d.isPaid = true;
                  } else {
                    d.amount -= paid;
                  }
                });
                _saveData();
              }
              Navigator.pop(context);
            },
            child: const Text('Внести'),
          ),
        ],
      ),
    );
  }

  void _openAddDebtDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'they_owe';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Добавить долг', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'they_owe', label: Text('Мне должны')),
                  ButtonSegment(value: 'i_owe', label: Text('Я должен')),
                ],
                selected: {type},
                onSelectionChanged: (val) => setModalState(() => type = val.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: type == 'they_owe' ? AppStyle.green : AppStyle.coral,
                  selectedForegroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 14),
              TextField(controller: nameCtrl, decoration: _inputDeco('Имя человека / Контакт')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: _inputDeco('Телефон (необязательно)')),
              const SizedBox(height: 10),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма ($_currency)')),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: _inputDeco('Комментарий / Заметка')),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.blue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text) ?? 0;
                  if (nameCtrl.text.trim().isNotEmpty && amount > 0) {
                    setState(() {
                      _debts.insert(
                        0,
                        Debt(
                          id: _uuid.v4(),
                          personName: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          amount: amount,
                          initialAmount: amount,
                          type: type,
                          createdAt: DateTime.now(),
                          note: noteCtrl.text.trim(),
                        ),
                      );
                    });
                    _saveData();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== ЭКРАН ЗАМЕТОК =====================
  Widget _buildNotesView() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Заметки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppStyle.textPri)),
              Text('${_notes.length} записей', style: const TextStyle(color: AppStyle.textSec)),
            ],
          ),
          const SizedBox(height: 16),
          if (_notes.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: const Text('Заметок пока нет. Нажмите "+ Заметка"', style: TextStyle(color: AppStyle.textSec)),
            )
          else
            ..._notes.map((n) => _buildNoteCard(n)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildNoteCard(NoteItem n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyle.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          n.title.isEmpty ? 'Без заголовка' : n.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppStyle.textPri),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(n.content, style: const TextStyle(color: AppStyle.textSec, fontSize: 14), maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt),
              style: const TextStyle(color: AppStyle.border, fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppStyle.textSec, size: 20),
          onPressed: () {
            setState(() => _notes.removeWhere((item) => item.id == n.id));
            _saveData();
          },
        ),
        onTap: () => _openAddNoteDialog(editing: n),
      ),
    );
  }

  void _openAddNoteDialog({NoteItem? editing}) {
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final contentCtrl = TextEditingController(text: editing?.content ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing == null ? 'Новая заметка' : 'Редактировать', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: _inputDeco('Заголовок')),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, maxLines: 5, decoration: _inputDeco('Текст заметки...')),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (titleCtrl.text.trim().isNotEmpty || contentCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    if (editing != null) {
                      editing.title = titleCtrl.text.trim();
                      editing.content = contentCtrl.text.trim();
                    } else {
                      _notes.insert(
                        0,
                        NoteItem(
                          id: _uuid.v4(),
                          title: titleCtrl.text.trim(),
                          content: contentCtrl.text.trim(),
                          createdAt: DateTime.now(),
                        ),
                      );
                    }
                  });
                  _saveData();
                  Navigator.pop(context);
                }
              },
              child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== НАСТРОЙКИ =====================
  Widget _buildSettingsView() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Настройки', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppStyle.card,
            leading: const Icon(Icons.currency_exchange, color: AppStyle.blue),
            title: const Text('Валюта расчетов'),
            subtitle: Text('Текущая: $_currency', style: const TextStyle(color: AppStyle.textSec)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                if (_currency == 'сом.') _currency = '₽';
                else if (_currency == '₽') _currency = '\$';
                else _currency = 'сом.';
              });
              _saveData();
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppStyle.card,
            leading: const Icon(Icons.delete_sweep_outlined, color: AppStyle.coral),
            title: const Text('Очистить все данные', style: TextStyle(color: AppStyle.coral)),
            onTap: () {
              setState(() {
                _debts.clear();
                _notes.clear();
              });
              _saveData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('База данных очищена')));
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppStyle.textSec),
    filled: true,
    fillColor: AppStyle.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
  );
}

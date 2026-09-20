import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
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
    systemNavigationBarColor: ClassicStyle.bg,
  ));
  runApp(const KassaproApp());
}

// Строгий, солидный классический деловой стиль (Без неона)
class ClassicStyle {
  static const bg = Color(0xFF0C0E14);
  static const surface = Color(0xFF141720);
  static const card = Color(0xFF1A1E29);
  static const border = Color(0xFF262C3A);

  static const textPri = Color(0xFFFFFFFF);
  static const textSec = Color(0xFF8E9AA8);

  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF2563EB);
  static const amber = Color(0xFFD97706);

  static final numFmt = NumberFormat("#,##0.##", "ru_RU");
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
        scaffoldBackgroundColor: ClassicStyle.bg,
        colorScheme: const ColorScheme.dark(
          surface: ClassicStyle.surface,
          primary: ClassicStyle.blue,
        ),
      ),
      home: const SecurityGate(),
    );
  }
}

// ---------------- БИОМЕТРИЯ / ЗАЩИТА ----------------
class SecurityGate extends StatefulWidget {
  const SecurityGate({super.key});
  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate> {
  bool _ready = false;
  bool _unlocked = false;
  String _savedPin = '';
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final p = await SharedPreferences.getInstance();
    _savedPin = p.getString('kp_pin') ?? '';
    setState(() => _ready = true);

    if (_savedPin.isEmpty) {
      setState(() => _unlocked = true);
    } else {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (canAuth) {
        final ok = await _auth.authenticate(
          localizedReason: 'Подтвердите личность для входа в Kassapro',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        if (ok) setState(() => _unlocked = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: ClassicStyle.bg);
    if (!_unlocked) {
      return Scaffold(
        backgroundColor: ClassicStyle.bg,
        body: SafeArea(
          child: PinKeypadView(
            savedPin: _savedPin,
            onBioTap: _tryBiometric,
            onSuccess: () => setState(() => _unlocked = true),
          ),
        ),
      );
    }
    return const MainClassicScreen();
  }
}

class PinKeypadView extends StatefulWidget {
  final String savedPin;
  final VoidCallback onBioTap;
  final VoidCallback onSuccess;
  const PinKeypadView({super.key, required this.savedPin, required this.onBioTap, required this.onSuccess});

  @override
  State<PinKeypadView> createState() => _PinKeypadViewState();
}

class _PinKeypadViewState extends State<PinKeypadView> {
  String _input = '';
  bool _error = false;

  void _press(String d) {
    if (_input.length < 4) {
      setState(() { _input += d; _error = false; });
      if (_input.length == 4) {
        if (_input == widget.savedPin) {
          widget.onSuccess();
        } else {
          HapticFeedback.vibrate();
          setState(() { _error = true; _input = ''; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shield_outlined, size: 54, color: ClassicStyle.textPri),
        const SizedBox(height: 16),
        const Text('Kassapro Защита', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_error ? 'Неверный PIN' : 'Отпечаток пальца или 4-значный код', style: TextStyle(color: _error ? ClassicStyle.red : ClassicStyle.textSec, fontSize: 13)),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14, height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _input.length ? ClassicStyle.textPri : Colors.transparent,
              border: Border.all(color: _error ? ClassicStyle.red : ClassicStyle.border, width: 2),
            ),
          )),
        ),
        const SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: GridView.count(
            shrinkWrap: true, crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14,
            children: [
              ...List.generate(9, (i) => _kBtn('${i + 1}')),
              IconButton(icon: const Icon(Icons.fingerprint, size: 30, color: ClassicStyle.textSec), onPressed: widget.onBioTap),
              _kBtn('0'),
              IconButton(icon: const Icon(Icons.backspace_outlined, size: 24, color: ClassicStyle.textSec), onPressed: () {
                if (_input.isNotEmpty) setState(() => _input = _input.substring(0, _input.length - 1));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kBtn(String text) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: ClassicStyle.card, shape: const CircleBorder(), elevation: 0),
    onPressed: () => _press(text),
    child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ClassicStyle.textPri)),
  );
}

// ---------------- ОСНОВНОЙ ЭКРАН ----------------
class MainClassicScreen extends StatefulWidget {
  const MainClassicScreen({super.key});
  @override
  State<MainClassicScreen> createState() => _MainClassicScreenState();
}

class _MainClassicScreenState extends State<MainClassicScreen> {
  int _tab = 0;
  String _currency = 'сом.';
  List<Debt> _debts = [];
  List<NoteItem> _notes = [];
  List<ChatMessage> _chat = [];
  String _aiModel = 'openrouter/free';
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
    _chat.add(ChatMessage(
      text: 'Здравствуйте! Я ваш финансовый ассистент. Могу выполнить аудит задолженностей, составить график выплат или текст напоминания. Работаю как с интернетом, так и офлайн.',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _loadData() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _currency = p.getString('kp_currency') ?? 'сом.';
      _debts = (p.getStringList('kp_debts') ?? []).map((e) => Debt.fromJson(jsonDecode(e))).toList();
      _notes = (p.getStringList('kp_notes') ?? []).map((e) => NoteItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveData() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('kp_debts', _debts.map((e) => jsonEncode(e.toJson())).toList());
    await p.setStringList('kp_notes', _notes.map((e) => jsonEncode(e.toJson())).toList());
    await p.setString('kp_currency', _currency);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _buildDebtsLedger(),
          _buildAIChatTab(),
          _buildNotesTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: ClassicStyle.surface,
          border: Border(top: BorderSide(color: ClassicStyle.border, width: 0.8)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          backgroundColor: Colors.transparent,
          selectedItemColor: ClassicStyle.textPri,
          unselectedItemColor: ClassicStyle.textSec,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Долги'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'ИИ Консультант'),
            BottomNavigationBarItem(icon: Icon(Icons.note_alt_outlined), activeIcon: Icon(Icons.note_alt), label: 'Заметки'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Опции'),
          ],
        ),
      ),
      floatingActionButton: (_tab == 0 || _tab == 2)
          ? FloatingActionButton(
              backgroundColor: ClassicStyle.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onPressed: _tab == 0 ? _openAddDebtDialog : _openAddNoteDialog,
              child: const Icon(Icons.add, size: 24),
            )
          : null,
    );
  }

  // ---------------- 1. ДОЛГИ: ГРУППИРОВКА ПО ЛЮДЯМ В 1 КАРТОЧКУ ----------------
  int _filter = 0; // 0: все активные, 1: мне должны, 2: я должен, 3: архив

  Widget _buildDebtsLedger() {
    double theyOwe = 0;
    double iOwe = 0;
    for (var d in _debts) {
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }
    double net = theyOwe - iOwe;

    // Группируем долги по имени человека (без учета регистра и лишних пробелов)
    Map<String, PersonGroup> groupMap = {};
    for (var d in _debts) {
      final key = d.personName.trim().toLowerCase();
      if (!groupMap.containsKey(key)) {
        groupMap[key] = PersonGroup(personName: d.personName.trim(), phone: d.phone, debts: []);
      }
      groupMap[key]!.debts.add(d);
    }
    List<PersonGroup> allGroups = groupMap.values.toList();

    // Фильтрация групп
    List<PersonGroup> filteredGroups = allGroups.where((g) {
      if (_filter == 0) return g.hasActiveDebts;
      if (_filter == 1) return g.totalTheyOwe > 0;
      if (_filter == 2) return g.totalIOwe > 0;
      return !g.hasActiveDebts; // Архив
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kassapro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClassicStyle.textPri,
                      side: const BorderSide(color: ClassicStyle.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    onPressed: () => ReportExporter.exportPdf(_debts, _currency),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClassicStyle.textPri,
                      side: const BorderSide(color: ClassicStyle.border),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.html, size: 18),
                    label: const Text('HTML', style: TextStyle(fontSize: 12)),
                    onPressed: () => ReportExporter.exportHtml(_debts, _currency),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 14),

          // СТРОГИЙ ДЕЛОВОЙ БАЛАНС (БЕЗ НЕОНА)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ClassicStyle.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ClassicStyle.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ЧИСТОЕ САЛЬДО', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ClassicStyle.textSec, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(
                  '${net >= 0 ? "+" : ""}${ClassicStyle.numFmt.format(net)} $_currency',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: net >= 0 ? ClassicStyle.green : ClassicStyle.red),
                ),
                const Divider(color: ClassicStyle.border, height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Мне должны', style: TextStyle(color: ClassicStyle.textSec, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('+${ClassicStyle.numFmt.format(theyOwe)} $_currency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ClassicStyle.green)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Я должен', style: TextStyle(color: ClassicStyle.textSec, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text('-${ClassicStyle.numFmt.format(iOwe)} $_currency', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ClassicStyle.red)),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ФИЛЬТРЫ
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _tabChip('Все активные', 0),
                _tabChip('Мне должны', 1),
                _tabChip('Я должен', 2),
                _tabChip('Архив', 3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // СПИСОК ГРУПП (ДАВЛАТ: ВСЕ ЗАЙМЫ ВНУТРИ 1 КАРТОЧКИ)
          if (filteredGroups.isEmpty)
            Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: const Text('Записей нет', style: TextStyle(color: ClassicStyle.textSec)))
          else
            ...filteredGroups.map((g) => _buildPersonGroupCard(g)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _tabChip(String title, int idx) {
    final act = _filter == idx;
    return GestureDetector(
      onTap: () => setState(() => _filter = idx),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: act ? ClassicStyle.textPri : ClassicStyle.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: act ? ClassicStyle.textPri : ClassicStyle.border),
        ),
        child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: act ? Colors.black : ClassicStyle.textSec)),
      ),
    );
  }

  // ЕДИНАЯ КАРТОЧКА ЧЕЛОВЕКА СО ВСЕМИ ЕГО ЗАЙМАМИ ВНУТРИ
  Widget _buildPersonGroupCard(PersonGroup group) {
    final net = group.netBalance;
    final isTheyNet = net >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ClassicStyle.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClassicStyle.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ВЕРХ КАРТОЧКИ: ИМЯ, ОБЩИЙ ИТОГ И КНОПКА "+ ЗАЙМ"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: ClassicStyle.surface,
                  foregroundColor: ClassicStyle.textPri,
                  radius: 18,
                  child: Text(group.personName.isNotEmpty ? group.personName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.personName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${group.debts.length} займ(а)', style: const TextStyle(fontSize: 12, color: ClassicStyle.textSec)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isTheyNet ? "+" : ""}${ClassicStyle.numFmt.format(net)} $_currency',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isTheyNet ? ClassicStyle.green : ClassicStyle.red),
                    ),
                    Text(isTheyNet ? 'Вам должны' : 'Вы должны', style: TextStyle(fontSize: 11, color: isTheyNet ? ClassicStyle.green : ClassicStyle.red)),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: ClassicStyle.blue),
                  onPressed: () => _openAddDebtDialog(presetName: group.personName),
                ),
              ],
            ),
          ),
          const Divider(color: ClassicStyle.border, height: 1),

          // СПИСОК ВСЕХ ЗАЙМОВ ВНУТРИ ЭТОЙ ЖЕ КАРТОЧКИ
          ...group.debts.map((d) => _buildSubDebtItem(d)),
        ],
      ),
    );
  }

  Widget _buildSubDebtItem(Debt d) {
    final isThey = d.type == 'they_owe';
    final accent = d.isPaid ? ClassicStyle.textSec : (isThey ? ClassicStyle.green : ClassicStyle.red);

    return InkWell(
      onTap: () => _openDebtDetails(d),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E2330), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(isThey ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${ClassicStyle.numFmt.format(d.amount)} $_currency',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: accent, decoration: d.isPaid ? TextDecoration.lineThrough : null),
                      ),
                      if (d.photoPath != null && d.photoPath!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.image, size: 14, color: ClassicStyle.amber),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(d.createdAt)}${d.dueDate != null ? ' • До: ' + DateFormat('dd.MM.yyyy').format(d.dueDate!) : ''}${d.note.isNotEmpty ? ' • ' + d.note : ''}',
                    style: const TextStyle(fontSize: 11, color: ClassicStyle.textSec),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!d.isPaid)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ClassicStyle.border),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _partialPayDialog(d),
                child: const Text('Погасить', style: TextStyle(fontSize: 11, color: ClassicStyle.textPri)),
              )
            else
              const Text('Закрыт', style: TextStyle(fontSize: 11, color: ClassicStyle.textSec)),
          ],
        ),
      ),
    );
  }

  // ДЕТАЛИ ЗАЙМА, ФОТО ЧЕКА И ИСТОРИЯ ВЫПЛАТ
  void _openDebtDetails(Debt d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClassicStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(d.personName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('${ClassicStyle.numFmt.format(d.amount)} $_currency', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ClassicStyle.blue)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Начальная сумма: ${ClassicStyle.numFmt.format(d.initialAmount)} $_currency', style: const TextStyle(color: ClassicStyle.textSec, fontSize: 12)),
                const Divider(color: ClassicStyle.border, height: 24),

                // ФОТО ЧЕКА / РАСПИСКИ
                if (d.photoPath != null && d.photoPath!.isNotEmpty) ...[
                  const Text('Прикрепленный чек / расписка:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showFullImage(d.photoPath!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(d.photoPath!),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Text('Ошибка загрузки фото', style: TextStyle(color: ClassicStyle.red)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text('История выплат (Таймлайн):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('• Выдано: ${DateFormat('dd.MM.yyyy').format(d.createdAt)} (${ClassicStyle.numFmt.format(d.initialAmount)} $_currency)'),
                ...d.payments.map((p) => Text('• ${DateFormat('dd.MM.yyyy HH:mm').format(p.date)}: -${ClassicStyle.numFmt.format(p.amount)} $_currency', style: const TextStyle(color: ClassicStyle.green))),

                const SizedBox(height: 20),
                if (!d.isPaid) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ClassicStyle.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      _partialPayDialog(d);
                    },
                    child: const Text('Внести частичную выплату'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: ClassicStyle.red),
                  onPressed: () {
                    setState(() => _debts.removeWhere((x) => x.id == d.id));
                    _saveData();
                    Navigator.pop(context);
                  },
                  child: const Text('Удалить этот займ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.file(File(path)),
        ),
      ),
    );
  }

  void _partialPayDialog(Debt d) {
    final a = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ClassicStyle.surface,
        title: const Text('Внесение выплаты'),
        content: TextField(
          controller: a,
          keyboardType: TextInputType.number,
          decoration: _inputDeco('Сумма погашения'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ClassicStyle.blue, foregroundColor: Colors.white),
            onPressed: () {
              final paid = double.tryParse(a.text) ?? 0;
              if (paid > 0) {
                setState(() {
                  final actual = paid > d.amount ? d.amount : paid;
                  d.payments.add(PaymentRecord(id: _uuid.v4(), amount: actual, date: DateTime.now()));
                  d.amount -= actual;
                  if (d.amount <= 0) d.isPaid = true;
                });
                _saveData();
              }
              Navigator.pop(context);
            },
            child: const Text('Внести'),
          )
        ],
      ),
    );
  }

  void _openAddDebtDialog({String? presetName}) {
    final n = TextEditingController(text: presetName ?? '');
    final a = TextEditingController();
    final c = TextEditingController();
    String type = 'they_owe';
    DateTime? pickedDate;
    String? localPhotoPath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClassicStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Новый займ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'they_owe', label: Text('Мне должны')),
                    ButtonSegment(value: 'i_owe', label: Text('Я должен')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setLocal(() => type = v.first),
                ),
                const SizedBox(height: 10),
                TextField(controller: n, decoration: _inputDeco('Имя человека (например: Давлат)')),
                const SizedBox(height: 8),
                TextField(controller: a, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма ($_currency)')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tileColor: ClassicStyle.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(pickedDate == null ? 'Указать дедлайн' : 'Срок: ${DateFormat('dd.MM.yyyy').format(pickedDate!)}', style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.event, size: 20),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d != null) setLocal(() => pickedDate = d);
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: c, decoration: _inputDeco('Заметка / комментарий')),
                const SizedBox(height: 10),

                // КНОПКА ДОБАВЛЕНИЯ ФОТО
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: ClassicStyle.border), foregroundColor: ClassicStyle.textPri),
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        label: Text(localPhotoPath == null ? 'Прикрепить фото' : 'Фото прикреплено', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (photo != null) setLocal(() => localPhotoPath = photo.path);
                        },
                      ),
                    ),
                    if (localPhotoPath != null)
                      IconButton(icon: const Icon(Icons.close, color: ClassicStyle.red), onPressed: () => setLocal(() => localPhotoPath = null)),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ClassicStyle.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    final sum = double.tryParse(a.text) ?? 0;
                    if (n.text.trim().isNotEmpty && sum > 0) {
                      setState(() {
                        _debts.insert(0, Debt(
                          id: _uuid.v4(),
                          personName: n.text.trim(),
                          amount: sum,
                          initialAmount: sum,
                          type: type,
                          createdAt: DateTime.now(),
                          dueDate: pickedDate,
                          note: c.text.trim(),
                          photoPath: localPhotoPath,
                        ));
                      });
                      _saveData();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 2. ИИ ЧАТ: ОФЛАЙН И ОНЛАЙН С ШАБЛОНАМИ ----------------
  final _aiCtrl = TextEditingController();
  bool _aiLoading = false;

  Widget _buildAIChatTab() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: ClassicStyle.surface, border: Border(bottom: BorderSide(color: ClassicStyle.border))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ИИ Консультант', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ClassicStyle.border),
                    foregroundColor: ClassicStyle.textPri,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.bookmark_outline, size: 16),
                  label: const Text('Шаблоны', style: TextStyle(fontSize: 12)),
                  onPressed: _openOfflineTemplatesSheet,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _chat.length,
              itemBuilder: (_, i) {
                final m = _chat[i];
                return Align(
                  alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: m.isUser ? ClassicStyle.blue : ClassicStyle.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: m.isUser ? Colors.transparent : ClassicStyle.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.isOffline)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('[ОФЛАЙН РЕЖИМ]', style: TextStyle(color: ClassicStyle.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        Text(m.text, style: TextStyle(color: m.isUser ? Colors.white : ClassicStyle.textPri, fontSize: 13, height: 1.4)),
                        if (!m.isUser) ...[
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _notes.insert(0, NoteItem(id: _uuid.v4(), title: 'ИИ Анализ', content: m.text, updatedAt: DateTime.now()));
                              });
                              _saveData();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в Заметки!')));
                            },
                            child: const Text('Сохранить в заметки 📝', style: TextStyle(color: ClassicStyle.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_aiLoading) const LinearProgressIndicator(color: ClassicStyle.blue, minHeight: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: ClassicStyle.surface, border: Border(top: BorderSide(color: ClassicStyle.border))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aiCtrl,
                    decoration: _inputDeco('Вопрос или расчет (работает и офлайн)...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: ClassicStyle.blue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _sendAIMessage,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _sendAIMessage() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty || _aiLoading) return;
    _aiCtrl.clear();
    setState(() {
      _chat.add(ChatMessage(text: text, isUser: true, time: DateTime.now()));
      _aiLoading = true;
    });

    final promptContext = '''
Вопрос: "$text"
Текущие данные долгов:
${_debts.map((d) => "- ${d.personName}: ${d.amount} $_currency (${d.type == 'they_owe' ? 'должен мне' : 'я должен'})").join("\n")}
''';

    final res = await AIService.sendSmartMessage(
      prompt: promptContext,
      modelId: _aiModel,
      debts: _debts,
      currency: _currency,
    );

    setState(() {
      _aiLoading = false;
      _chat.add(ChatMessage(text: res['text'], isUser: false, time: DateTime.now(), isOffline: res['isOffline']));
    });
  }

  void _openOfflineTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ClassicStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Готовые офлайн-шаблоны', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...AIService.offlineTemplates.map((tpl) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tpl['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(tpl['text']!, style: const TextStyle(color: ClassicStyle.textSec, fontSize: 12)),
              trailing: const Icon(Icons.copy, size: 18),
              onTap: () {
                Clipboard.setData(ClipboardData(text: tpl['text']!));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Шаблон скопирован!')));
              },
            )),
          ],
        ),
      ),
    );
  }

  // ---------------- 3. ЗАМЕТКИ ----------------
  Widget _buildNotesTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Заметки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _openAddNoteDialog,
              )
            ],
          ),
          const SizedBox(height: 12),
          if (_notes.isEmpty)
            Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: const Text('Заметок нет', style: TextStyle(color: ClassicStyle.textSec)))
          else
            ..._notes.map((n) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ClassicStyle.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ClassicStyle.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(n.title.isEmpty ? 'Заметка' : n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: ClassicStyle.textSec),
                        onPressed: () { setState(() => _notes.removeWhere((x) => x.id == n.id)); _saveData(); },
                      )
                    ],
                  ),
                  if (n.content.isNotEmpty) Text(n.content, style: const TextStyle(color: ClassicStyle.textSec, fontSize: 13)),
                  if (n.photoPath != null && n.photoPath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(n.photoPath!), height: 90, width: double.infinity, fit: BoxFit.cover)),
                  ],
                  const SizedBox(height: 6),
                  Text(DateFormat('dd.MM.yyyy HH:mm').format(n.updatedAt), style: const TextStyle(color: ClassicStyle.border, fontSize: 10)),
                ],
              ),
            )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _openAddNoteDialog() {
    final t = TextEditingController(), c = TextEditingController();
    String? notePhoto;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ClassicStyle.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setL) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новая заметка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: t, decoration: _inputDeco('Заголовок')),
              const SizedBox(height: 8),
              TextField(controller: c, maxLines: 4, decoration: _inputDeco('Текст заметки...')),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: ClassicStyle.border), foregroundColor: ClassicStyle.textPri),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(notePhoto == null ? 'Прикрепить фото к заметке' : 'Фото выбрано'),
                onPressed: () async {
                  final p = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (p != null) setL(() => notePhoto = p.path);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ClassicStyle.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  if (t.text.isNotEmpty || c.text.isNotEmpty) {
                    setState(() {
                      _notes.insert(0, NoteItem(id: _uuid.v4(), title: t.text.trim(), content: c.text.trim(), updatedAt: DateTime.now(), photoPath: notePhoto));
                    });
                    _saveData();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Сохранить'),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 4. ОПЦИИ И НАСТРОЙКИ ----------------
  Widget _buildSettingsTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Опции и безопасность', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: ClassicStyle.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Валюта расчетов'),
            subtitle: Text(_currency),
            onTap: () {
              setState(() {
                if (_currency == 'сом.') _currency = '₽';
                else if (_currency == '₽') _currency = '\$';
                else _currency = 'сом.';
              });
              _saveData();
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: ClassicStyle.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.lock_outline),
            title: const Text('PIN-код и Биометрия'),
            subtitle: const Text('Безопасность входа'),
            onTap: () {
              final c = TextEditingController();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: ClassicStyle.surface,
                  title: const Text('Установка PIN'),
                  content: TextField(controller: c, keyboardType: TextInputType.number, maxLength: 4, decoration: _inputDeco('4 цифры (пусто = отключить)')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                    ElevatedButton(
                      onPressed: () async {
                        final p = await SharedPreferences.getInstance();
                        await p.setString('kp_pin', c.text.trim());
                        Navigator.pop(context);
                      },
                      child: const Text('Сохранить'),
                    )
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: ClassicStyle.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.delete_forever, color: ClassicStyle.red),
            title: const Text('Очистить всю базу', style: TextStyle(color: ClassicStyle.red)),
            onTap: () {
              setState(() { _debts.clear(); _notes.clear(); });
              _saveData();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String h) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(color: ClassicStyle.textSec, fontSize: 13),
    filled: true,
    fillColor: ClassicStyle.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ClassicStyle.border)),
  );
}

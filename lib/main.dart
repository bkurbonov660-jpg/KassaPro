import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    systemNavigationBarColor: NeoTheme.bg,
  ));
  runApp(const KassaproNeoApp());
}

class NeoTheme {
  static const bg = Color(0xFF07090E);
  static const surface = Color(0xFF10141F);
  static const card = Color(0xFF161C2C);
  static const border = Color(0xFF222B42);

  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF10B981);
  static const rose = Color(0xFFF43F5E);
  static const amber = Color(0xFFF59E0B);

  static const textPri = Color(0xFFF8FAFC);
  static const textSec = Color(0xFF94A3B8);

  static const hyperCardColors = [
    Color(0xFF161C2C), // Default Deep
    Color(0xFF1E293B), // Slate
    Color(0xFF132A24), // Sage / HyperOS Green
    Color(0xFF2D1F2D), // Berry Violet
    Color(0xFF292218), // Warm Amber
  ];

  static final numFmt = NumberFormat("#,##0.##", "ru_RU");
}

class KassaproNeoApp extends StatelessWidget {
  const KassaproNeoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kassapro Neo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: NeoTheme.bg,
        colorScheme: const ColorScheme.dark(surface: NeoTheme.surface, primary: NeoTheme.cyan),
      ),
      home: const NeoGate(),
    );
  }
}

// ---------------- БИОМЕТРИЯ ИЛИ PIN ----------------
class NeoGate extends StatefulWidget {
  const NeoGate({super.key});
  @override
  State<NeoGate> createState() => _NeoGateState();
}

class _NeoGateState extends State<NeoGate> {
  bool _ready = false;
  bool _unlocked = false;
  String _savedPin = '';
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    final p = await SharedPreferences.getInstance();
    _savedPin = p.getString('kp_pin') ?? '';
    final hasBiometrics = p.getBool('kp_biometric_enabled') ?? true;

    if (_savedPin.isEmpty) {
      setState(() { _ready = true; _unlocked = true; });
      return;
    }

    setState(() => _ready = true);

    if (hasBiometrics) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    try {
      final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (canAuth) {
        final ok = await _auth.authenticate(
          localizedReason: 'Подтвердите вход в Kassapro (отпечаток или лицо)',
          options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
        );
        if (ok) setState(() => _unlocked = true);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(backgroundColor: NeoTheme.bg);
    if (!_unlocked) {
      return Scaffold(
        body: SafeArea(
          child: PinPadScreen(
            savedPin: _savedPin,
            onBiometricTap: _tryBiometric,
            onSuccess: () => setState(() => _unlocked = true),
          ),
        ),
      );
    }
    return const NeoMainDashboard();
  }
}

class PinPadScreen extends StatefulWidget {
  final String savedPin;
  final VoidCallback onBiometricTap;
  final VoidCallback onSuccess;
  const PinPadScreen({super.key, required this.savedPin, required this.onBiometricTap, required this.onSuccess});

  @override
  State<PinPadScreen> createState() => _PinPadScreenState();
}

class _PinPadScreenState extends State<PinPadScreen> {
  String _code = '';
  bool _err = false;

  void _key(String s) {
    if (_code.length < 4) {
      setState(() { _code += s; _err = false; });
      if (_code.length == 4) {
        if (_code == widget.savedPin) {
          widget.onSuccess();
        } else {
          HapticFeedback.vibrate();
          setState(() { _err = true; _code = ''; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.fingerprint, size: 68, color: NeoTheme.cyan),
        const SizedBox(height: 16),
        const Text('Kassapro Neo Lock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(_err ? 'Неверный код!' : 'Приложите палец или введите PIN', style: TextStyle(color: _err ? NeoTheme.rose : NeoTheme.textSec)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16, height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _code.length ? NeoTheme.cyan : Colors.transparent,
              border: Border.all(color: _err ? NeoTheme.rose : NeoTheme.border, width: 2),
            ),
          )),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50),
          child: GridView.count(
            shrinkWrap: true, crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14,
            children: [
              ...List.generate(9, (i) => _btn('${i + 1}')),
              IconButton(icon: const Icon(Icons.face_unlock_outlined, size: 32, color: NeoTheme.cyan), onPressed: widget.onBiometricTap),
              _btn('0'),
              IconButton(icon: const Icon(Icons.backspace_outlined, size: 26), onPressed: () {
                if (_code.isNotEmpty) setState(() => _code = _code.substring(0, _code.length - 1));
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _btn(String t) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.card, shape: const CircleBorder(), elevation: 0),
    onPressed: () => _key(t),
    child: Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NeoTheme.textPri)),
  );
}

// ---------------- ОСНОВНОЙ ЭКРАН ----------------
class NeoMainDashboard extends StatefulWidget {
  const NeoMainDashboard({super.key});
  @override
  State<NeoMainDashboard> createState() => _NeoMainDashboardState();
}

class _NeoMainDashboardState extends State<NeoMainDashboard> {
  int _tab = 0;
  String _currency = 'сом.';
  List<Debt> _debts = [];
  List<NoteItem> _notes = [];
  List<ChatMessage> _messages = [];
  String _selectedModel = 'openrouter/free';
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _messages.add(ChatMessage(
      text: 'Салам! Я ваш персональный финансовый ИИ. Могу рассчитать план закрытия долгов, составить текст напоминания или написать структурированную заметку.',
      isUser: false,
      time: DateTime.now(),
    ));
  }

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _currency = p.getString('kp_currency') ?? 'сом.';
      _debts = (p.getStringList('kp_debts') ?? []).map((e) => Debt.fromJson(jsonDecode(e))).toList();
      _notes = (p.getStringList('kp_notes') ?? []).map((e) => NoteItem.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveAll() async {
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
          _buildHyperNotesTab(),
          _buildSettingsHub(),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        height: 64,
        decoration: BoxDecoration(
          color: NeoTheme.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: NeoTheme.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.blur_on, 'Долги'),
            _navItem(1, Icons.auto_awesome, 'ИИ Чат'),
            _navItem(2, Icons.dashboard_customize_outlined, 'Заметки'),
            _navItem(3, Icons.layers_outlined, 'Центр'),
          ],
        ),
      ),
      floatingActionButton: (_tab == 0 || _tab == 2)
          ? FloatingActionButton(
              backgroundColor: _tab == 0 ? NeoTheme.cyan : NeoTheme.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _tab == 0 ? _openNewDebtModal : _openNewHyperNote,
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? NeoTheme.cyan : NeoTheme.textSec, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? NeoTheme.cyan : NeoTheme.textSec)),
        ],
      ),
    );
  }

  // ---------------- 1. РЕЕСТР ДОЛГОВ И РАДАР СВОБОДЫ ----------------
  int _debtFilter = 0; // 0: все, 1: мне, 2: я, 3: закрытые

  Widget _buildDebtsLedger() {
    double theyOwe = 0;
    double iOwe = 0;
    double totalBorrowedEver = 0;
    double totalRepaidEver = 0;

    for (var d in _debts) {
      totalBorrowedEver += d.initialAmount;
      totalRepaidEver += (d.initialAmount - d.amount);
      if (!d.isPaid) {
        if (d.type == 'they_owe') theyOwe += d.amount;
        if (d.type == 'i_owe') iOwe += d.amount;
      }
    }
    double net = theyOwe - iOwe;
    double progress = totalBorrowedEver > 0 ? (totalRepaidEver / totalBorrowedEver).clamp(0.0, 1.0) : 1.0;

    final filtered = _debts.where((d) {
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
              const Text('Kassapro Neo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              Row(
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: NeoTheme.card),
                    icon: const Icon(Icons.picture_as_pdf, color: NeoTheme.cyan, size: 20),
                    onPressed: () => ReportExporter.exportPdf(_debts, _currency),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(backgroundColor: NeoTheme.card),
                    icon: const Icon(Icons.html, color: NeoTheme.amber, size: 22),
                    onPressed: () => ReportExporter.exportHtml(_debts, _currency),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 14),

          // 🌟 НОВАЯ ИДЕЯ: РАДАР ФИНАНСОВОЙ СВОБОДЫ (NEO HERO CARD)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF131B2E), Color(0xFF1A162B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: NeoTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Радар свободы от долгов', style: TextStyle(color: NeoTheme.textSec, fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${(progress * 100).toInt()}% закрыто', style: const TextStyle(color: NeoTheme.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: NeoTheme.border, valueColor: const AlwaysStoppedAnimation(NeoTheme.cyan)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Чистый баланс', style: TextStyle(color: NeoTheme.textSec, fontSize: 12)),
                        Text('${net >= 0 ? "+" : ""}${NeoTheme.numFmt.format(net)} $_currency', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: net >= 0 ? NeoTheme.green : NeoTheme.rose)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Мне: +${NeoTheme.numFmt.format(theyOwe)}', style: const TextStyle(color: NeoTheme.green, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Я: -${NeoTheme.numFmt.format(iOwe)}', style: const TextStyle(color: NeoTheme.rose, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    )
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
                _pillFilter('Все активные', 0),
                _pillFilter('Мне должны', 1),
                _pillFilter('Я должен', 2),
                _pillFilter('Архив', 3),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(padding: const EdgeInsets.all(50), alignment: Alignment.center, child: const Text('В этом разделе пусто', style: TextStyle(color: NeoTheme.textSec)))
          else
            ...filtered.map((d) => _debtNeoCard(d)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _pillFilter(String t, int idx) {
    final act = _debtFilter == idx;
    return GestureDetector(
      onTap: () => setState(() => _debtFilter = idx),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: act ? NeoTheme.cyan.withOpacity(0.15) : NeoTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: act ? NeoTheme.cyan : NeoTheme.border),
        ),
        child: Text(t, style: TextStyle(color: act ? NeoTheme.cyan : NeoTheme.textSec, fontSize: 12, fontWeight: act ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _debtNeoCard(Debt d) {
    final isThey = d.type == 'they_owe';
    final accent = d.isPaid ? NeoTheme.textSec : (isThey ? NeoTheme.green : NeoTheme.rose);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NeoTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NeoTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accent.withOpacity(0.15),
          child: Icon(isThey ? Icons.south_west : Icons.north_east, color: accent, size: 20),
        ),
        title: Row(
          children: [
            Expanded(child: Text(d.personName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: d.isPaid ? TextDecoration.lineThrough : null))),
            Text('${NeoTheme.numFmt.format(d.amount)} $_currency', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isThey ? 'Должен вам' : 'Вы должны', style: TextStyle(color: accent, fontSize: 12)),
                if (d.dueDate != null) _deadlineTag(d.dueDate!),
              ],
            ),
            if (d.payments.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Внесено выплат: ${d.payments.length} поз.', style: const TextStyle(fontSize: 11, color: NeoTheme.cyan)),
            ]
          ],
        ),
        onTap: () => _openDebtTimelineModal(d),
      ),
    );
  }

  Widget _deadlineTag(DateTime dt) {
    final diff = dt.difference(DateTime.now()).inDays;
    Color c = NeoTheme.green;
    String txt = 'через $diff дн.';
    if (diff < 0) { c = NeoTheme.rose; txt = 'просрочено на ${-diff} дн.'; }
    else if (diff <= 3) { c = NeoTheme.amber; txt = 'осталось $diff дн.'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(txt, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _openDebtTimelineModal(Debt d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeoTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d.personName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Остаток долга: ${NeoTheme.numFmt.format(d.amount)} $_currency', style: const TextStyle(color: NeoTheme.cyan, fontSize: 15)),
              const Divider(color: NeoTheme.border, height: 24),
              const Text('Таймлайн:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: NeoTheme.textSec)),
              const SizedBox(height: 8),
              Text('• Создано: ${DateFormat('dd.MM.yyyy').format(d.createdAt)} — ${NeoTheme.numFmt.format(d.initialAmount)} $_currency'),
              ...d.payments.map((p) => Text('• ${DateFormat('dd.MM.yyyy HH:mm').format(p.date)}: -${NeoTheme.numFmt.format(p.amount)} $_currency', style: const TextStyle(color: NeoTheme.green))),
              const SizedBox(height: 20),
              if (!d.isPaid) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.cyan, foregroundColor: Colors.black),
                  onPressed: () {
                    final c = TextEditingController();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: NeoTheme.surface,
                        title: const Text('Внести возврат'),
                        content: TextField(controller: c, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                          ElevatedButton(
                            onPressed: () {
                              final v = double.tryParse(c.text) ?? 0;
                              if (v > 0) {
                                setState(() {
                                  final p = v > d.amount ? d.amount : v;
                                  d.payments.add(PaymentRecord(id: _uuid.v4(), amount: p, date: DateTime.now()));
                                  d.amount -= p;
                                  if (d.amount <= 0) d.isPaid = true;
                                });
                                _saveAll();
                                setModal(() {});
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Внести'),
                          )
                        ],
                      ),
                    );
                  },
                  child: const Text('Внести часть суммы'),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                style: TextButton.styleFrom(foregroundColor: NeoTheme.rose),
                onPressed: () {
                  setState(() => _debts.removeWhere((x) => x.id == d.id));
                  _saveAll();
                  Navigator.pop(context);
                },
                child: const Text('Удалить долг'),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openNewDebtModal() {
    final n = TextEditingController(), a = TextEditingController(), c = TextEditingController();
    String type = 'they_owe';
    DateTime? pickedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeoTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Новая запись', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'they_owe', label: Text('Мне должны')),
                  ButtonSegment(value: 'i_owe', label: Text('Я должен')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setM(() => type = v.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: n, decoration: _inputDeco('Имя человека')),
              const SizedBox(height: 10),
              TextField(controller: a, keyboardType: TextInputType.number, decoration: _inputDeco('Сумма ($_currency)')),
              const SizedBox(height: 10),
              ListTile(
                tileColor: NeoTheme.card,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text(pickedDate == null ? 'Указать срок возврата' : 'Дедлайн: ${DateFormat('dd.MM.yyyy').format(pickedDate!)}', style: const TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.event, color: NeoTheme.cyan),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)));
                  if (d != null) setM(() => pickedDate = d);
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: c, decoration: _inputDeco('Заметка / основание')),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.cyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () {
                  final sum = double.tryParse(a.text) ?? 0;
                  if (n.text.isNotEmpty && sum > 0) {
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
                      ));
                    });
                    _saveAll();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 2. ЧАТ С ИИ (ВСЕ БЕСПЛАТНЫЕ МОДЕЛИ) ----------------
  final _chatCtrl = TextEditingController();
  bool _aiLoading = false;

  Widget _buildAIChatTab() {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: NeoTheme.surface, border: Border(bottom: BorderSide(color: NeoTheme.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Kassapro AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NeoTheme.cyan)),
                    Icon(Icons.hub_outlined, color: NeoTheme.cyan, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedModel,
                    isExpanded: true,
                    dropdownColor: NeoTheme.card,
                    items: AIService.freeModels.map((m) => DropdownMenuItem(value: m['id'], child: Text(m['name']!, style: const TextStyle(fontSize: 12, color: NeoTheme.textPri)))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedModel = v); },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: m.isUser ? NeoTheme.cyan : NeoTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: m.isUser ? Colors.transparent : NeoTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.text, style: TextStyle(color: m.isUser ? Colors.black : NeoTheme.textPri, fontSize: 13, height: 1.4)),
                        if (!m.isUser) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _notes.insert(0, NoteItem(id: _uuid.v4(), title: 'ИИ Анализ', content: m.text, updatedAt: DateTime.now()));
                              });
                              _saveAll();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ответ сохранен в Заметки!')));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bookmark_add_outlined, size: 14, color: NeoTheme.cyan),
                                SizedBox(width: 4),
                                Text('В заметки', style: TextStyle(color: NeoTheme.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_aiLoading) const LinearProgressIndicator(color: NeoTheme.cyan, minHeight: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: NeoTheme.surface, border: Border(top: BorderSide(color: NeoTheme.border))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    decoration: _inputDeco('Спросите ИИ о долгах, напишите заметку...'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: NeoTheme.cyan, foregroundColor: Colors.black),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: _sendToAI,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _sendToAI() async {
    final t = _chatCtrl.text.trim();
    if (t.isEmpty || _aiLoading) return;
    _chatCtrl.clear();
    setState(() {
      _messages.add(ChatMessage(text: t, isUser: true, time: DateTime.now()));
      _aiLoading = true;
    });

    final promptWithDebts = '''
Пользователь спрашивает: "$t"

Контекст активных долгов в приложении:
${_debts.map((d) => "- ${d.personName}: ${d.amount} $_currency (${d.type == 'they_owe' ? 'должен мне' : 'я должен'})").join("\n")}
''';

    final ans = await AIService.sendMessage(prompt: promptWithDebts, modelId: _selectedModel);
    setState(() {
      _aiLoading = false;
      _messages.add(ChatMessage(text: ans, isUser: false, time: DateTime.now()));
    });
  }

  // ---------------- 3. ЗАМЕТКИ В СТИЛЕ XIAOMI HYPEROS ----------------
  Widget _buildHyperNotesTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HyperOS Заметки', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton.filledTonal(
                icon: const Icon(Icons.auto_awesome, color: NeoTheme.amber, size: 20),
                onPressed: () => _askAiToWriteNote(),
              )
            ],
          ),
          const SizedBox(height: 14),
          if (_notes.isEmpty)
            Container(padding: const EdgeInsets.all(40), alignment: Alignment.center, child: const Text('Заметок пока нет', style: TextStyle(color: NeoTheme.textSec)))
          else
            ..._notes.map((n) => _hyperNoteCard(n)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _hyperNoteCard(NoteItem n) {
    final bg = NeoTheme.hyperCardColors[n.colorIndex % NeoTheme.hyperCardColors.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: n.isPinned ? NeoTheme.amber : NeoTheme.border, width: n.isPinned ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(n.title.isEmpty ? 'Заметка' : n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  GestureDetector(
                    onTap: () { setState(() => n.isPinned = !n.isPinned); _saveAll(); },
                    child: Icon(n.isPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18, color: n.isPinned ? NeoTheme.amber : NeoTheme.textSec),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () { setState(() => _notes.removeWhere((x) => x.id == n.id)); _saveAll(); },
                    child: const Icon(Icons.delete_outline, size: 18, color: NeoTheme.textSec),
                  ),
                ],
              )
            ],
          ),
          if (n.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(n.content, style: const TextStyle(color: NeoTheme.textSec, fontSize: 13), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          if (n.checklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...n.checklist.map((c) => Row(
              children: [
                Checkbox(
                  value: c.done,
                  activeColor: NeoTheme.cyan,
                  onChanged: (v) { setState(() => c.done = v ?? false); _saveAll(); },
                ),
                Expanded(child: Text(c.text, style: TextStyle(fontSize: 13, decoration: c.done ? TextDecoration.lineThrough : null, color: c.done ? NeoTheme.textSec : NeoTheme.textPri))),
              ],
            )),
          ],
          const SizedBox(height: 8),
          Text(DateFormat('dd.MM.yyyy HH:mm').format(n.updatedAt), style: const TextStyle(fontSize: 10, color: NeoTheme.border)),
        ],
      ),
    );
  }

  void _askAiToWriteNote() {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NeoTheme.surface,
        title: const Text('✨ ИИ Генератор Заметки'),
        content: TextField(controller: c, decoration: _inputDeco('О чем составить заметку?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.amber, foregroundColor: Colors.black),
            onPressed: () async {
              final topic = c.text.trim();
              Navigator.pop(context);
              if (topic.isNotEmpty) {
                final gen = await AIService.sendMessage(prompt: 'Напиши четкую заметку на тему: $topic. Сделай заголовок и краткий план.', modelId: _selectedModel);
                setState(() {
                  _notes.insert(0, NoteItem(id: _uuid.v4(), title: topic, content: gen, updatedAt: DateTime.now(), colorIndex: 2));
                });
                _saveAll();
              }
            },
            child: const Text('Создать'),
          )
        ],
      ),
    );
  }

  void _openNewHyperNote() {
    final t = TextEditingController(), c = TextEditingController(), checkItemCtrl = TextEditingController();
    int colorIdx = 0;
    List<ChecklistItem> items = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: NeoTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Новая HyperOS Заметка', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: t, decoration: _inputDeco('Заголовок')),
                const SizedBox(height: 10),
                TextField(controller: c, maxLines: 4, decoration: _inputDeco('Текст...')),
                const SizedBox(height: 10),
                ...items.map((it) => Text('☑ ${it.text}', style: const TextStyle(color: NeoTheme.cyan))),
                Row(
                  children: [
                    Expanded(child: TextField(controller: checkItemCtrl, decoration: _inputDeco('+ Пункт чеклиста'))),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: NeoTheme.cyan),
                      onPressed: () {
                        if (checkItemCtrl.text.isNotEmpty) {
                          setM(() => items.add(ChecklistItem(text: checkItemCtrl.text.trim())));
                          checkItemCtrl.clear();
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(NeoTheme.hyperCardColors.length, (i) => GestureDetector(
                    onTap: () => setM(() => colorIdx = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: NeoTheme.hyperCardColors[i], shape: BoxShape.circle, border: Border.all(color: colorIdx == i ? NeoTheme.cyan : NeoTheme.border, width: 2)),
                    ),
                  )),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: NeoTheme.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () {
                    if (t.text.isNotEmpty || c.text.isNotEmpty || items.isNotEmpty) {
                      setState(() {
                        _notes.insert(0, NoteItem(id: _uuid.v4(), title: t.text.trim(), content: c.text.trim(), updatedAt: DateTime.now(), checklist: items, colorIndex: colorIdx));
                      });
                      _saveAll();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 4. ЦЕНТР НАСТРОЕК ----------------
  Widget _buildSettingsHub() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Центр управления', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            tileColor: NeoTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.currency_exchange, color: NeoTheme.cyan),
            title: const Text('Валюта расчетов'),
            subtitle: Text(_currency),
            onTap: () {
              setState(() {
                if (_currency == 'сом.') _currency = '₽';
                else if (_currency == '₽') _currency = '\$';
                else _currency = 'сом.';
              });
              _saveAll();
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: NeoTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.fingerprint, color: NeoTheme.green),
            title: const Text('PIN-код и Биометрия'),
            subtitle: const Text('Управление безопасностью'),
            onTap: () {
              final c = TextEditingController();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: NeoTheme.surface,
                  title: const Text('Установка PIN'),
                  content: TextField(controller: c, keyboardType: TextInputType.number, maxLength: 4, decoration: _inputDeco('4 цифры (пусто = снять)')),
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
            tileColor: NeoTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.delete_sweep_outlined, color: NeoTheme.rose),
            title: const Text('Сбросить базу данных', style: TextStyle(color: NeoTheme.rose)),
            onTap: () {
              setState(() { _debts.clear(); _notes.clear(); });
              _saveAll();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String h) => InputDecoration(
    hintText: h,
    hintStyle: const TextStyle(color: NeoTheme.textSec, fontSize: 13),
    filled: true,
    fillColor: NeoTheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models/models.dart';
import 'services/api_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
  ));

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  runApp(const SmartAiNotifyApp());
}

class AppColors {
  static const bg = Color(0xFF0D0F12);
  static const surface = Color(0xFF161920);
  static const card = Color(0xFF1E222D);
  static const border = Color(0xFF2A3040);
  static const accent = Color(0xFF00E5FF);
  static const primary = Color(0xFF6366F1);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const textPri = Color(0xFFF9FAFB);
  static const textSec = Color(0xFF94A3B8);
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class SmartAiNotifyApp extends StatelessWidget {
  const SmartAiNotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AI Notify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.accent,
          secondary: AppColors.primary,
        ),
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
  int _tab = 0;
  final _uuid = const Uuid();

  // Состояние таймера и уведомлений
  bool _autoNotifyEnabled = true;
  int _intervalSeconds = 20;
  int _secondsLeft = 20;
  Timer? _ticker;
  bool _isGenerating = false;

  // Модели OpenRouter
  List<String> _freeModels = ApiService.fallbackFreeModels;
  String _selectedModel = 'meta-llama/llama-3.2-3b-instruct:free';

  // Категории и Характер ИИ
  final List<String> _defaultCategories = [
    '🌌 Парадоксы и физика',
    '🧠 Наука и мозг',
    '🏛 Стоицизм и мудрость',
    '💻 IT и код',
    '🇬🇧 English Idioms',
    '⚡ Продуктивность',
    '🎲 Случайный микс',
  ];
  List<String> _categories = [];
  String _selectedCategory = '🌌 Парадоксы и физика';

  final List<String> _tones = [
    '🔬 Строгий учёный',
    '🏛 Мудрец-стоик',
    '🚀 Футурист и визионер',
    '💡 Лаконичный гений',
  ];
  String _selectedTone = '🔬 Строгий учёный';

  // Списки данных
  List<NotificationItem> _notifications = [];
  List<ChatMessage> _chatMessages = [];
  bool _onlyFavoritesInFeed = false;

  // Контроллеры чата
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _categories = List.from(_defaultCategories);
    _loadState();
    _startTicker();
    _refreshFreeModels();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_autoNotifyEnabled) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        setState(() => _secondsLeft = _intervalSeconds);
        _triggerNotification();
      }
    });
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoNotifyEnabled = prefs.getBool('auto_notify') ?? true;
      _intervalSeconds = prefs.getInt('interval_sec') ?? 20;
      _secondsLeft = _intervalSeconds;
      _selectedCategory = prefs.getString('category') ?? _categories[0];
      _selectedModel = prefs.getString('selected_model') ?? _selectedModel;
      _selectedTone = prefs.getString('selected_tone') ?? _tones[0];

      final customCats = prefs.getStringList('custom_categories') ?? [];
      for (var c in customCats) {
        if (!_categories.contains(c)) _categories.add(c);
      }

      final notifStrings = prefs.getStringList('saved_notifications') ?? [];
      _notifications = notifStrings
          .map((s) => NotificationItem.fromJson(jsonDecode(s)))
          .toList();

      final chatStrings = prefs.getStringList('saved_chat') ?? [];
      _chatMessages = chatStrings
          .map((s) => ChatMessage.fromJson(jsonDecode(s)))
          .toList();
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_notify', _autoNotifyEnabled);
    await prefs.setInt('interval_sec', _intervalSeconds);
    await prefs.setString('category', _selectedCategory);
    await prefs.setString('selected_model', _selectedModel);
    await prefs.setString('selected_tone', _selectedTone);

    final customCats =
        _categories.where((c) => !_defaultCategories.contains(c)).toList();
    await prefs.setStringList('custom_categories', customCats);

    final notifStrings =
        _notifications.map((n) => jsonEncode(n.toJson())).toList();
    await prefs.setStringList('saved_notifications', notifStrings);

    final chatStrings =
        _chatMessages.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList('saved_chat', chatStrings);
  }

  Future<void> _refreshFreeModels() async {
    final list = await ApiService.fetchFreeModels();
    if (list.isNotEmpty && mounted) {
      setState(() {
        _freeModels = list;
        if (!_freeModels.contains(_selectedModel)) {
          _selectedModel = _freeModels.first;
        }
      });
    }
  }

  Future<void> _triggerNotification({bool manual = false}) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final res = await ApiService.generateSmartNotification(
        category: _selectedCategory,
        model: _selectedModel,
        tone: _selectedTone,
      );

      final item = NotificationItem(
        id: _uuid.v4(),
        title: res['title'] ?? '💡 Умное уведомление',
        body: res['body'] ?? 'Новая мысль от ИИ.',
        timestamp: DateTime.now(),
        model: _selectedModel,
        category: _selectedCategory,
      );

      setState(() {
        _notifications.insert(0, item);
        _isGenerating = false;
        if (manual) _secondsLeft = _intervalSeconds;
      });
      await _saveState();

      final notifId = (DateTime.now().millisecondsSinceEpoch % 100000);
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'smart_ai_channel',
        'Smart AI Notifications',
        channelDescription: 'Периодические микро-уведомления от ИИ',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'AI Notification',
        styleInformation: BigTextStyleInformation(item.body),
      );
      final NotificationDetails notifDetails =
          NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.show(
        notifId,
        item.title,
        item.body,
        notifDetails,
        payload: item.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚡ ${item.title}: ${item.body}'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Скопировано в буфер обмена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addNewCustomCategory() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Добавить тему для ИИ'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Напр., Квантовая физика или Психология',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textSec)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                final formatted = '✨ $val';
                setState(() {
                  _categories.add(formatted);
                  _selectedCategory = formatted;
                });
                _saveState();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _sendChat(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: query,
      timestamp: DateTime.now(),
      model: _selectedModel,
    );

    setState(() {
      _chatMessages.add(userMsg);
      _chatController.clear();
      _isChatLoading = true;
    });
    _saveState();
    _scrollToBottom();

    final reply = await ApiService.sendChatMessage(
      history: _chatMessages,
      userPrompt: query,
      model: _selectedModel,
    );

    final aiMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content: reply,
      timestamp: DateTime.now(),
      model: _selectedModel,
    );

    if (mounted) {
      setState(() {
        _chatMessages.add(aiMsg);
        _isChatLoading = false;
      });
      _saveState();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _discussInChat(NotificationItem item) {
    setState(() => _tab = 2);
    _sendChat('Расскажи подробнее про: "${item.title}". Суть: ${item.body}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 75,
            child: IndexedStack(
              index: _tab,
              children: [
                _buildRadarTab(),
                _buildFeedTab(),
                _buildChatTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
          Positioned(left: 16, right: 16, bottom: 12, child: _buildNavBar()),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    const items = [
      NavItem(Icons.radar, 'Радар'),
      NavItem(Icons.notifications_active_outlined, 'Лента'),
      NavItem(Icons.chat_bubble_outline, 'AI Чат'),
      NavItem(Icons.tune, 'Настройки'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (i) {
              final active = _tab == i;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].icon,
                        color: active ? AppColors.accent : AppColors.textSec,
                        size: active ? 26 : 22),
                    const SizedBox(height: 3),
                    Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: 11,
                        color: active ? AppColors.accent : AppColors.textSec,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      ),
                    )
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // 1. ВКЛАДКА РАДАР (ГЛАВНАЯ)
  Widget _buildRadarTab() {
    final progress = _intervalSeconds > 0
        ? (_intervalSeconds - _secondsLeft) / _intervalSeconds
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart AI Notify',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedModel.split('/').last,
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: AppColors.warn, size: 16),
                  SizedBox(width: 4),
                  Text('FREE AI',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),

        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 170,
                height: 170,
                child: CircularProgressIndicator(
                  value: _autoNotifyEnabled ? progress : 0,
                  strokeWidth: 8,
                  backgroundColor: AppColors.card,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _autoNotifyEnabled ? AppColors.accent : AppColors.textSec,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isGenerating) ...[
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Генерация...',
                        style: TextStyle(fontSize: 13, color: AppColors.accent)),
                  ] else ...[
                    Text(
                      _autoNotifyEnabled ? '$_secondsLeft' : 'PAUSE',
                      style: TextStyle(
                        fontSize: _autoNotifyEnabled ? 42 : 26,
                        fontWeight: FontWeight.bold,
                        color: _autoNotifyEnabled ? Colors.white : AppColors.textSec,
                      ),
                    ),
                    Text(
                      _autoNotifyEnabled ? 'сек до пуша' : 'Остановлено',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSec),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  _autoNotifyEnabled ? Icons.pause : Icons.play_arrow,
                  size: 20,
                ),
                label: Text(_autoNotifyEnabled ? 'Пауза' : 'Включить авто'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _autoNotifyEnabled ? AppColors.surface : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _autoNotifyEnabled ? AppColors.border : Colors.transparent,
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _autoNotifyEnabled = !_autoNotifyEnabled;
                    _secondsLeft = _intervalSeconds;
                  });
                  _saveState();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, size: 20),
                label: const Text('Получить сейчас'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _triggerNotification(manual: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Интервал рассылки:',
                style: TextStyle(fontSize: 13, color: AppColors.textSec)),
            Row(
              children: [20, 30, 60, 300].map((sec) {
                final label = sec < 60 ? '${sec}с' : '${sec ~/ 60}м';
                final active = _intervalSeconds == sec;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _intervalSeconds = sec;
                        _secondsLeft = sec;
                      });
                      _saveState();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : AppColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: active ? Colors.black : AppColors.textPri,
                        ),
                      ),
                    ),
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
            const Text('Тематика озарений:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text('Своя тема', style: TextStyle(fontSize: 12, color: AppColors.accent)),
              onPressed: _addNewCustomCategory,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final active = _selectedCategory == cat;
            return ChoiceChip(
              label: Text(cat, style: const TextStyle(fontSize: 12)),
              selected: active,
              selectedColor: AppColors.accent.withOpacity(0.2),
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                color: active ? AppColors.accent : AppColors.textSec,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: active ? AppColors.accent : AppColors.border,
              ),
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedCategory = cat);
                  _saveState();
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        if (_notifications.isNotEmpty) ...[
          const Text('Последнее озарение:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildNotificationCard(_notifications.first),
        ],
      ],
    );
  }

  // 2. ВКЛАДКА ЛЕНТА УВЕДОМЛЕНИЙ (С ФИЛЬТРОМ ИЗБРАННОГО)
  Widget _buildFeedTab() {
    final displayList = _onlyFavoritesInFeed
        ? _notifications.where((n) => n.isFavorite).toList()
        : _notifications;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Лента (${displayList.length})',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _onlyFavoritesInFeed ? Icons.star : Icons.star_border,
                      color: _onlyFavoritesInFeed ? AppColors.warn : AppColors.textSec,
                    ),
                    tooltip: 'Только избранные',
                    onPressed: () => setState(() => _onlyFavoritesInFeed = !_onlyFavoritesInFeed),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: AppColors.danger),
                    tooltip: 'Очистить ленту',
                    onPressed: () {
                      setState(() => _notifications.clear());
                      _saveState();
                    },
                  ),
                ],
              )
            ],
          ),
        ),
        Expanded(
          child: displayList.isEmpty
              ? Center(
                  child: Text(
                    _onlyFavoritesInFeed
                        ? 'В избранном пока ничего нет ⭐'
                        : 'Пока нет уведомлений.\nТаймер сгенерирует их каждые 20 секунд!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSec),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: displayList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _buildNotificationCard(displayList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final timeStr =
        '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Text(timeStr,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSec)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => item.isFavorite = !item.isFavorite);
                      _saveState();
                    },
                    child: Icon(
                      item.isFavorite ? Icons.star : Icons.star_border,
                      size: 22,
                      color: item.isFavorite ? AppColors.warn : AppColors.textSec,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body,
              style: const TextStyle(fontSize: 14, color: AppColors.textPri)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category.split(' ').first,
                  style: const TextStyle(fontSize: 11, color: AppColors.accent),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppColors.textSec),
                    tooltip: 'Скопировать',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _copyToClipboard('${item.title}\n${item.body}'),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline,
                        size: 14, color: AppColors.accent),
                    label: const Text('В чат',
                        style: TextStyle(fontSize: 12, color: AppColors.accent)),
                    onPressed: () => _discussInChat(item),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. ВКЛАДКА ИНТЕРАКТИВНЫЙ AI ЧАТ
  Widget _buildChatTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AI Ассистент',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_selectedModel.split('/').last,
                      style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.textSec),
                tooltip: 'Очистить чат',
                onPressed: () {
                  setState(() => _chatMessages.clear());
                  _saveState();
                },
              ),
            ],
          ),
        ),

        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              'Парадокс близнецов',
              'Идея для мобильной игры',
              'Как работает Flutter в Termux?',
              'Объясни квантовую механику',
            ].map((p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(p, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => _sendChat(p),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _chatMessages.isEmpty
              ? const Center(
                  child: Text('Задайте любой вопрос или обсудите уведомление!',
                      style: TextStyle(color: AppColors.textSec)),
                )
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length,
                  itemBuilder: (_, i) {
                    final msg = _chatMessages[i];
                    final isUser = msg.role == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          msg.content,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
        ),

        if (_isChatLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
                SizedBox(width: 8),
                Text('ИИ формулирует ответ...',
                    style: TextStyle(fontSize: 12, color: AppColors.textSec)),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Спросите у нейросети...',
                    hintStyle: const TextStyle(color: AppColors.textSec),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _sendChat,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.accent),
                onPressed: () => _sendChat(_chatController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. ВКЛАДКА НАСТРОЙКИ
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 30),
      children: [
        const Text('Настройки системы',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        _buildSectionHeader('СТИЛЬ И ХАРАКТЕР ИИ'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Тональность озарений:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTone,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _tones.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedTone = v);
                    _saveState();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('АКТИВНАЯ МОДЕЛЬ OPENROUTER'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Бесплатные модели (:free):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.accent),
                    tooltip: 'Обновить модели с сервера',
                    onPressed: () async {
                      await _refreshFreeModels();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Найдено ${_freeModels.length} бесплатных моделей')),
                        );
                      }
                    },
                  )
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _freeModels.contains(_selectedModel) ? _selectedModel : _freeModels.first,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _freeModels.map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedModel = v);
                    _saveState();
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('БЕЗОПАСНОСТЬ И API-КЛЮЧ'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('OpenRouter API Key:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Встроен рабочий ключ по умолчанию (закодирован Base64). Вы также можете использовать собственный:',
                style: TextStyle(fontSize: 12, color: AppColors.textSec),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.key, size: 18),
                label: const Text('Сменить / Ввести свой API-ключ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showApiKeyDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader('СБОРКА APK (GITHUB ACTIONS)'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Репозиторий: bkurbonov660-jpg/KassaPro',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                'GitHub Actions автоматически скомпилирует app-release.apk и опубликует его во вкладке Releases.',
                style: TextStyle(fontSize: 12, color: AppColors.textSec),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: AppColors.accent,
          ),
        ),
      );

  void _showApiKeyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final ctrl = TextEditingController(text: prefs.getString('custom_openrouter_key') ?? '');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('OpenRouter API-ключ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Вставьте ваш OpenRouter ключ...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.remove('custom_openrouter_key');
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сброшено на встроенный ключ')),
                );
              }
            },
            child: const Text('Сброс к дефолту', style: TextStyle(color: AppColors.warn)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await prefs.setString('custom_openrouter_key', ctrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ключ сохранён локально')),
                );
              }
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

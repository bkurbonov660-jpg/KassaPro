import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'store.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/report_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';

final notifPlugin = FlutterLocalNotificationsPlugin();
final uuid = const Uuid();

class AppColors {
  static const bg = Color(0xFF0f1115);
  static const panel = Color(0xFF171a21);
  static const panel2 = Color(0xFF1e222b);
  static const line = Color(0xFF272b35);
  static const text = Color(0xFFe8eaed);
  static const muted = Color(0xFF8a8f9c);
  static const accent = Color(0xFF4f7cff);
  static const accentSoft = Color(0x264f7cff);
  static const red = Color(0xFFef4444);
  static const redSoft = Color(0x1Fef4444);
  static const green = Color(0xFF22c55e);
  static const greenSoft = Color(0x1F22c55e);
  static const orange = Color(0xFFf59e0b);
}

Future<void> initNotifs() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const init = InitializationSettings(android: android, iOS: ios);
  try { await notifPlugin.initialize(init); } catch(_){}
}

Future<void> showNotif(String title, String body) async {
  const android = AndroidNotificationDetails('goalflow','GoalFlow',
    channelDescription:'Уведомления',importance:Importance.high,priority:Priority.high);
  const ios = DarwinNotificationDetails();
  const details = NotificationDetails(android:android,iOS:ios);
  try { await notifPlugin.show(0,title,body,details); } catch(_){}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
  ));
  await initNotifs();
  runApp(const GoalFlowApp());
}

class GoalFlowApp extends StatelessWidget {
  const GoalFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore()..load(),
      child: MaterialApp(
        title: 'GoalFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: const ColorScheme.dark(surface: AppColors.panel, primary: AppColors.accent),
          fontFamily: 'Roboto',
        ),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    if (s.defaultCurrency == null) return const OnboardingScreen();
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  static const titles = [
    ('Главная','Обзор целей'),
    ('Мои цели','Управление целями'),
    ('Валюты','Конвертер и курсы'),
    ('Отчёт','Деньги · История · Архив'),
    ('Профиль','Настройки'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = context.read<AppStore>();
      if (s.ratesUpdated == null || DateTime.now().millisecondsSinceEpoch - s.ratesUpdated! > 86400000) {
        s.fetchRates();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = titles[_tab];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16,16,16,16),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text(t.$2, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  )),
                  _CurBadge(),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(child: IndexedStack(index: _tab, children: const [
              HomeScreen(), GoalsScreen(), WalletScreen(), ReportScreen(), ProfileScreen(),
            ])),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xF5171a21),
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: List.generate(5, (i) {
                final items = [
                  (Icons.home_outlined, Icons.home, 'Главная'),
                  (Icons.track_changes_outlined, Icons.track_changes, 'Цели'),
                  (Icons.credit_card_outlined, Icons.credit_card, 'Валюты'),
                  (Icons.show_chart_outlined, Icons.show_chart, 'Отчёт'),
                  (Icons.person_outline, Icons.person, 'Профиль'),
                ];
                final it = items[i];
                final on = _tab == i;
                return Expanded(child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(on ? it.$2 : it.$1, size: 22, color: on ? AppColors.accent : AppColors.muted),
                      const SizedBox(height: 3),
                      Text(it.$3, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: on ? AppColors.accent : AppColors.muted)),
                    ],
                  ),
                ));
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.language, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(s.defaultCurrency ?? 'RUB', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      ]),
    );
  }
}

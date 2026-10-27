import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'autowipe_page.dart';
import 'power_page.dart';
import 'theme.dart';
import 'traffic_page.dart';
import 'usage_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.s1,
  ));
  runApp(const AegisRootApp());
  appState.init();
}

class AegisRootApp extends StatelessWidget {
  const AegisRootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'AegisRoot',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: C.bg,
        textTheme: base.textTheme.apply(bodyColor: C.tx, displayColor: C.tx),
        colorScheme: const ColorScheme.dark(
          primary: C.jd,
          onPrimary: C.bg,
          secondary: C.pk,
          surface: C.s1,
          onSurface: C.tx,
          onSurfaceVariant: C.tx2,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: C.s2,
          contentTextStyle: TextStyle(color: C.tx),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: C.s1,
          indicatorColor: C.jd,
          height: 68,
        ),
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appState.refreshData(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          UsagePage(),
          TrafficPage(),
          PowerPage(),
          AutoWipePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded, color: C.bg),
            label: 'Время',
          ),
          NavigationDestination(
            icon: Icon(Icons.data_usage_outlined),
            selectedIcon: Icon(Icons.data_usage_rounded, color: C.bg),
            label: 'Трафик',
          ),
          NavigationDestination(
            icon: Icon(Icons.power_settings_new_rounded),
            selectedIcon: Icon(Icons.power_settings_new_rounded, color: C.bg),
            label: 'Питание',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded, color: C.bg),
            label: 'Защита',
          ),
        ],
      ),
    );
  }
}

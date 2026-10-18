import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'catalog_page.dart';
import 'config.dart';
import 'home_page.dart';
import 'mine_page.dart';
import 'profile_page.dart';
import 'store.dart';
import 'ui_common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.s1,
  ));
  store.init();
  runApp(const DoramaApp());
}

class DoramaApp extends StatelessWidget {
  const DoramaApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: Cfg.appName,
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: C.bg,
        textTheme: base.textTheme.apply(bodyColor: C.tx, displayColor: C.tx),
        colorScheme: const ColorScheme.dark(
          primary: C.pk, onPrimary: C.onPk,
          secondary: C.pk, secondaryContainer: C.pk, onSecondaryContainer: C.onPk,
          surface: C.s1, onSurface: C.tx, onSurfaceVariant: C.tx2),
        snackBarTheme: const SnackBarThemeData(backgroundColor: C.s2, contentTextStyle: TextStyle(color: C.tx)),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: C.s1, indicatorColor: C.pk, height: 68),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final s = mq.textScaler.scale(1.0).clamp(0.9, 1.1).toDouble();
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(s)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final lu = store.lastUpdate;
      if (lu == null || DateTime.now().difference(lu).inMinutes >= 5) store.refresh();
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: tab, children: const [
        HomePage(), CatalogPage(), MinePage(), ProfilePage(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_rounded), label: 'Эфир'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Каталог'),
          NavigationDestination(icon: Icon(Icons.bookmark_rounded), label: 'Мои'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Профиль'),
        ]),
      );
  }
}

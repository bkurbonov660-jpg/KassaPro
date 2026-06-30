import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

import 'providers/download_provider.dart';
import 'screens/main_navigation_holder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await _requestPermissions();

  final provider = DownloadProvider();
  await provider.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => provider,
      child: const MyApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    await [
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.videos,
      Permission.audio,
      Permission.photos
    ].request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    return MaterialApp(
      title: 'CyberDownloader',
      debugShowCheckedModeBanner: false,
      themeMode: provider.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru', 'RU')],
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A12),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const MainNavigationHolder(),
    );
  }
}

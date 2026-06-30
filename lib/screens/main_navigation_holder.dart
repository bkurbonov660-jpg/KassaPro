import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../widgets/bottom_navbar.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainNavigationHolder extends StatelessWidget {
  const MainNavigationHolder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<DownloadProvider>().currentTabIndex;
    const screens = [HomeScreen(), HistoryScreen(), SettingsScreen()];

    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false, child: IndexedStack(index: currentIndex, children: screens)),
      bottomNavigationBar: const BottomNavbar(),
    );
  }
}

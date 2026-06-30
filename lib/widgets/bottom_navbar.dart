import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';

class BottomNavbar extends StatelessWidget {
  const BottomNavbar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF00E5FF);

    return Container(
      height: 70,
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: isDark ? Colors.black45 : Colors.grey.shade300, blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(Icons.home_rounded, 'Главная', 0, provider, isDark, accent),
          _navItem(Icons.history_rounded, 'Медиатека', 1, provider, isDark, accent),
          _navItem(Icons.settings_rounded, 'Настройки', 2, provider, isDark, accent),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, DownloadProvider provider, bool isDark, Color accent) {
    final selected = provider.currentTabIndex == index;
    return InkWell(
      onTap: () => provider.setTab(index),
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? accent : (isDark ? Colors.grey.shade500 : Colors.grey.shade600), size: 26),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
          ],
        ),
      ),
    );
  }
}

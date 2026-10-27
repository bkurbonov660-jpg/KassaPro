import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF16111D);
  static const s1 = Color(0xFF1F1829);
  static const s2 = Color(0xFF2A2137);
  static const line = Color(0xFF38304A);
  static const tx = Color(0xFFF5EEE6);
  static const tx2 = Color(0xFFA99FB8);
  static const pk = Color(0xFFFF7A9C);
  static const jd = Color(0xFF5FD9B4);
  static const gd = Color(0xFFFFC857);
  static const rd = Color(0xFFFF6B6B);
  static const onPk = Color(0xFF2A0D18);
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtDurationMs(int ms, {bool showSeconds = false}) {
  if (ms <= 0) return showSeconds ? '00:00:00' : '0 мин';
  final totalSec = ms ~/ 1000;
  final days = totalSec ~/ 86400;
  final hours = (totalSec % 86400) ~/ 3600;
  final mins = (totalSec % 3600) ~/ 60;
  final secs = totalSec % 60;
  if (showSeconds) {
    if (days > 0) {
      return '${days}д ${two(hours)}:${two(mins)}:${two(secs)}';
    }
    return '${two(hours)}:${two(mins)}:${two(secs)}';
  }
  final parts = <String>[];
  if (days > 0) parts.add('$days д');
  if (hours > 0) parts.add('$hours ч');
  if (mins > 0 || parts.isEmpty) parts.add('$mins мин');
  return parts.join(' ');
}

String fmtBytes(int bytes) {
  if (bytes <= 0) return '0 Б';
  const kb = 1024.0;
  const mb = kb * 1024.0;
  const gb = mb * 1024.0;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} ГБ';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} КБ';
  return '$bytes Б';
}

String fmtDateTime(int ts) {
  if (ts <= 0) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const SectionHeader(this.title, this.icon, {this.trailing, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: C.jd),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: C.tx,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PeriodPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const PeriodPill(this.label, this.active, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? C.tx : C.s1,
          border: Border.all(color: active ? C.tx : C.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? C.bg : C.tx2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  const StatBox({
    required this.value,
    required this.label,
    required this.icon,
    this.accent = C.jd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: C.s1,
        border: Border.all(color: C.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.tx2, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: C.tx,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

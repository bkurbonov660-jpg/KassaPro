import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'config.dart';
import 'models.dart';
import 'store.dart';

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
  static const shade = Color(0xD916111D);
  static const onPk = Color(0xFF2A0D18);
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(String iso) {
  if (iso.length < 10) return iso;
  final y = int.tryParse(iso.substring(0, 4));
  final m = int.tryParse(iso.substring(5, 7));
  final d = int.tryParse(iso.substring(8, 10));
  if (y == null || m == null || d == null || m < 1 || m > 12) return iso;
  return '$d ${Cfg.months[m - 1]} $y';
}
String ruStatus(String s) => Cfg.statuses[s] ?? s;
String ruGenre(String g) => Cfg.genres[g] ?? g;

class SourceBadge extends StatelessWidget {
  final String source;
  const SourceBadge(this.source, {super.key});

  @override
  Widget build(BuildContext context) {
    String asset; Color color;
    switch (source) {
      case 'kinopoisk': asset = 'assets/icons/kp.svg'; color = C.gd; break;
      case 'wiki': asset = 'assets/icons/wiki.svg'; color = C.jd; break;
      case 'ai': asset = 'assets/icons/ai.svg'; color = C.pk; break;
      case 'mt':
      case 'local': asset = 'assets/icons/mt.svg'; color = C.tx2; break;
      case 'user': asset = 'assets/icons/user.svg'; color = C.pk; break;
      default: asset = 'assets/icons/dict.svg'; color = C.jd;
    }
    return SvgPicture.asset(asset, width: 14, height: 14,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
  }
}

class Poster extends StatelessWidget {
  final Drama d;
  const Poster(this.d, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = store.ruTitle(d);
    final ph = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [C.s2, C.s1], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center, padding: const EdgeInsets.all(8),
      child: Text(t.isEmpty ? '?' : t.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: C.pk, fontSize: 38, fontWeight: FontWeight.w800)),
    );
    if (d.poster.isEmpty) return ph;
    return Image.network(d.poster, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ph,
      loadingBuilder: (c, child, p) => p == null ? child : ph);
  }
}

class Pill extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const Pill(this.icon, this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: C.shade, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        if (text.isNotEmpty) const SizedBox(width: 4),
        if (text.isNotEmpty) Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class FilterPill extends StatelessWidget {
  final String label; final bool on; final VoidCallback onTap;
  const FilterPill(this.label, this.on, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? C.tx : Colors.transparent,
          border: Border.all(color: on ? C.tx : C.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: TextStyle(color: on ? C.bg : C.tx2, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  final List<Widget> children;
  const ChipRow(this.children, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: children));
}

class SectionTitle extends StatelessWidget {
  final String text; final bool live;
  const SectionTitle(this.text, {this.live = false, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(children: [
        if (live) Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(color: C.jd, shape: BoxShape.circle)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.tx))),
      ]),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final IconData icon; final String title; final String text;
  const EmptyBox(this.icon, this.title, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 44, color: C.pk),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.tx2)),
      ]),
    );
  }
}

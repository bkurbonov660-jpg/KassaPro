import 'dart:async';
import 'package:flutter/material.dart';
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
  static const rd = Color(0xFFFF6B6B);
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

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

String _plural(int n, String one, String few, String many) {
  final m100 = n.abs() % 100;
  final m10 = n.abs() % 10;
  if (m100 >= 11 && m100 <= 19) return many;
  if (m10 == 1) return one;
  if (m10 >= 2 && m10 <= 4) return few;
  return many;
}

String fmtCountdownLong(Duration diff, int epNum, {bool isPremiere = false}) {
  if (diff.isNegative) return '';
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  final mins = diff.inMinutes % 60;
  final prefix = isPremiere ? 'До премьеры осталось: ' : 'До $epNum-й серии осталось: ';
  final parts = <String>[];
  if (days > 0) parts.add('$days ${_plural(days, "день", "дня", "дней")}');
  if (hours > 0 || days > 0) parts.add('$hours ${_plural(hours, "час", "часа", "часов")}');
  if (days == 0) parts.add('$mins мин');
  return '$prefix${parts.join(" ")}';
}

String fmtCountdownShort(Duration diff, int epNum, {bool isPremiere = false}) {
  if (diff.isNegative) return '';
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  final mins = diff.inMinutes % 60;
  final label = isPremiere ? 'Премьера' : 'До $epNum-й с.';
  if (days > 0) return '$label: $daysд $hoursч';
  if (hours > 0) return '$label: $hoursч $minsм';
  return '$label: $mins мин';
}

class EpisodeCountdownBadge extends StatefulWidget {
  final Drama drama;
  final bool compact;
  final bool banner;
  const EpisodeCountdownBadge(this.drama, {this.compact = false, this.banner = false, super.key});
  @override
  State<EpisodeCountdownBadge> createState() => _EpisodeCountdownBadgeState();
}

class _EpisodeCountdownBadgeState extends State<EpisodeCountdownBadge> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    store.requestEpIfNeeded(widget.drama);
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant EpisodeCountdownBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drama.id != widget.drama.id) {
      store.requestEpIfNeeded(widget.drama);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = store.nextEpInfo(widget.drama);
    if (info == null) return const SizedBox.shrink();
    final diff = info.target.difference(DateTime.now());
    if (diff.isNegative || diff.inDays > 120) return const SizedBox.shrink();

    if (widget.banner) {
      final txt = fmtCountdownLong(diff, info.number, isPremiere: info.isPremiere);
      if (txt.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0x335FD9B4), Color(0x26FF7A9C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: C.jd),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.timer_rounded, color: C.jd, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txt, style: const TextStyle(color: C.tx, fontWeight: FontWeight.w800, fontSize: 13.5)),
              Text(
                'Дата выхода: ${fmtDate(info.airdate)}${info.time.isNotEmpty ? " · ${info.time} (KST)" : ""}',
                style: const TextStyle(color: C.tx2, fontSize: 11.5),
              ),
            ]),
          ),
        ]),
      );
    }

    final shortTxt = fmtCountdownShort(diff, info.number, isPremiere: info.isPremiere);
    if (shortTxt.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 7 : 8, vertical: widget.compact ? 3 : 4),
      decoration: BoxDecoration(
        color: C.shade,
        border: Border.all(color: const Color(0x805FD9B4), width: 0.8),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_rounded, size: widget.compact ? 11 : 12, color: C.jd),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            shortTxt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: C.jd, fontSize: widget.compact ? 10.5 : 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

class DubBadge extends StatelessWidget {
  final String dub;
  final bool small;
  const DubBadge(this.dub, {this.small = false, super.key});
  @override
  Widget build(BuildContext context) {
    if (dub.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: const Color(0x26FF7A9C),
        border: Border.all(color: C.pk, width: 0.9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.mic_rounded, size: small ? 11 : 13, color: C.pk),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Озвучка: $dub',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: C.pk, fontSize: small ? 10.5 : 12, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

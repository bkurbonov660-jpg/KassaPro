import 'package:flutter/material.dart';

class SvgNoticeIcon extends StatelessWidget {
  final Color color;
  const SvgNoticeIcon({this.color = const Color(0xFFFFC857), super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(26, 26), painter: _P(color));
}

class _P extends CustomPainter {
  final Color c;
  _P(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(2, 13)..lineTo(6.5, 13)..lineTo(9, 6)..lineTo(13, 20)..lineTo(15.5, 11)..lineTo(17.5, 13)..lineTo(24, 13);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

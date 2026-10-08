import 'package:flutter/material.dart';

/// The Tawla product mark: three QR finder corners and a coffee cup, seen from above.
///
/// It is the system's own brand, so it keeps the same colours whatever theme a cafe picks.
/// Below 24 px the inner squares and the handle are dropped so the shape stays readable.
class TawlaMark extends StatelessWidget {
  const TawlaMark({super.key, this.size = 28, this.color = const Color(0xFF1B3A4B), this.accent = const Color(0xFFBA5333)});

  final double size;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: Size.square(size), painter: _TawlaMarkPainter(color, accent, size < 24)),
    );
  }
}

class _TawlaMarkPainter extends CustomPainter {
  _TawlaMarkPainter(this.color, this.accent, this.simple);

  final Color color;
  final Color accent;
  final bool simple;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 120 × 120 grid.
    canvas.scale(size.width / 120);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = simple ? 12 : 9
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    for (final origin in const [Offset(8, 8), Offset(76, 8), Offset(8, 76)]) {
      canvas.drawRRect(RRect.fromRectAndRadius(origin & const Size(36, 36), const Radius.circular(10)), stroke);
      if (!simple) {
        canvas.drawRRect(RRect.fromRectAndRadius((origin + const Offset(11, 11)) & const Size(14, 14), const Radius.circular(4)), fill);
      }
    }
    if (simple) {
      canvas.drawCircle(const Offset(90, 90), 16, Paint()..color = accent);
      return;
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(55, 55, 10, 10), const Radius.circular(3)), fill);
    canvas.drawCircle(const Offset(90, 90), 17, stroke);
    canvas.drawCircle(const Offset(90, 90), 8, Paint()..color = accent);
    canvas.drawLine(const Offset(103, 103), const Offset(110, 110), stroke);
  }

  @override
  bool shouldRepaint(_TawlaMarkPainter old) => old.color != color || old.accent != accent || old.simple != simple;
}

/// Mark plus the "Tawla" word, for headers.
class TawlaLockup extends StatelessWidget {
  const TawlaLockup({super.key, this.color = const Color(0xFF1B3A4B), this.size = 26});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tawla',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TawlaMark(size: size, color: color),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Text(
              'Tawla',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: size * 0.72, letterSpacing: -0.8, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

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
  _TawlaMarkPainter(this.color, this.accent, this.simple, {this.build = 1, this.fade = 1});

  final Color color;
  final Color accent;
  final bool simple;

  /// How far the mark has drawn itself in, 0 to 1; 1 is the finished mark.
  final double build;

  /// Opacity of the whole mark, for the loader's fade between loops.
  final double fade;

  /// When each part starts to appear during [build], and how long it takes.
  static const _cornerStarts = [0.0, 0.15, 0.3];
  static const _partLength = 0.3;

  /// 0 before the part starts, 1 once it is in place.
  double _shown(double start) => ((build - start) / _partLength).clamp(0.0, 1.0);

  /// Draws [draw] scaled up from [center] and faded in as the part appears.
  void _part(Canvas canvas, double start, Offset center, void Function(double opacity) draw) {
    final shown = _shown(start);
    if (shown <= 0) return;
    final scale = build >= 1 ? 1.0 : Curves.easeOutBack.transform(shown);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale)
      ..translate(-center.dx, -center.dy);
    draw(shown * fade);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 120 × 120 grid.
    canvas.scale(size.width / 120);
    Paint stroke(double opacity) => Paint()
      ..color = color.withValues(alpha: color.a * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = simple ? 12 : 9
      ..strokeCap = StrokeCap.round;
    Paint fill(double opacity) => Paint()..color = color.withValues(alpha: color.a * opacity);
    Paint dot(double opacity) => Paint()..color = accent.withValues(alpha: accent.a * opacity);
    const origins = [Offset(8, 8), Offset(76, 8), Offset(8, 76)];
    for (var i = 0; i < origins.length; i++) {
      final origin = origins[i];
      _part(canvas, _cornerStarts[i], origin + const Offset(18, 18), (opacity) {
        canvas.drawRRect(RRect.fromRectAndRadius(origin & const Size(36, 36), const Radius.circular(10)), stroke(opacity));
        if (!simple) {
          canvas.drawRRect(RRect.fromRectAndRadius((origin + const Offset(11, 11)) & const Size(14, 14), const Radius.circular(4)), fill(opacity));
        }
      });
    }
    if (simple) {
      _part(canvas, 0.45, const Offset(90, 90), (opacity) => canvas.drawCircle(const Offset(90, 90), 16, dot(opacity)));
      return;
    }
    _part(canvas, 0.4, const Offset(60, 60), (opacity) {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(55, 55, 10, 10), const Radius.circular(3)), fill(opacity));
    });
    _part(canvas, 0.5, const Offset(90, 90), (opacity) {
      canvas.drawCircle(const Offset(90, 90), 17, stroke(opacity));
      canvas.drawLine(const Offset(103, 103), const Offset(110, 110), stroke(opacity));
    });
    _part(canvas, 0.65, const Offset(90, 90), (opacity) => canvas.drawCircle(const Offset(90, 90), 8, dot(opacity)));
  }

  @override
  bool shouldRepaint(_TawlaMarkPainter old) =>
      old.color != color || old.accent != accent || old.simple != simple || old.build != build || old.fade != fade;
}

/// The mark drawing itself in on a loop (corners, then the cup), shown while the app opens.
/// It holds still as the finished mark when the system asks for less motion.
class TawlaLoader extends StatefulWidget {
  const TawlaLoader({super.key, this.size = 72, this.color = const Color(0xFF1B3A4B), this.accent = const Color(0xFFBA5333)});

  final double size;
  final Color color;
  final Color accent;

  @override
  State<TawlaLoader> createState() => _TawlaLoaderState();
}

class _TawlaLoaderState extends State<TawlaLoader> with SingleTickerProviderStateMixin {
  /// One loop: draw in, hold the finished mark, fade out.
  static const _loop = Duration(milliseconds: 2000);
  static const _builtAt = 0.55;
  static const _fadeFrom = 0.85;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _loop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = _builtAt;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final build = (t / _builtAt).clamp(0.0, 1.0);
          final fade = t <= _fadeFrom ? 1.0 : 1 - (t - _fadeFrom) / (1 - _fadeFrom);
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _TawlaMarkPainter(widget.color, widget.accent, widget.size < 24, build: build, fade: fade),
          );
        },
      ),
    );
  }
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
          SizedBox(width: size * 0.4),
          ExcludeSemantics(
            child: Text(
              'Tawla',
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w800, fontSize: size * 0.67, letterSpacing: -0.9, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

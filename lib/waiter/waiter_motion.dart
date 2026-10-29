import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/cafe_theme.dart';
import 'waiter_state.dart';

/// Small moving parts of the waiter app. Each one shows its end state at once when the phone
/// asks for reduced motion.
bool _still(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Fades and lifts [child] in once, a little later for each [index], so a list arrives in a wave.
class EntranceRise extends StatefulWidget {
  const EntranceRise({super.key, required this.index, required this.child, this.animate = true});

  final int index;
  final Widget child;

  /// False shows [child] at once, for lists the waiter reshuffles often (a category tap).
  final bool animate;

  /// Later items start together, so a long list never waits.
  static const _maxStagger = 8;

  @override
  State<EntranceRise> createState() => _EntranceRiseState();
}

class _EntranceRiseState extends State<EntranceRise> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.animate) {
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 30 * widget.index.clamp(0, EntranceRise._maxStagger));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still(context)) return widget.child;
    final curved = CurvedAnimation(parent: _controller, curve: CafeMotion.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Shrinks [child] a touch while a finger is on it, so a tap feels pressed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !_still(context) ? 0.95 : 1,
        duration: CafeMotion.quick,
        curve: CafeMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// A dot that breathes, for "waiting for the cashier".
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stops when the phone asks for reduced motion.
    if (_still(context)) {
      _controller.stop();
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
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Container(
                width: widget.size * (1 + 1.2 * t),
                height: widget.size * (1 + 1.2 * t),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          dot,
        ],
      ),
    );
  }
}

/// Shakes [child] now and then and draws a glowing outline around it while [color] is set, to call
/// the waiter to a table. The outline fades in and out; with reduced motion it stays still.
class ShakeAlert extends StatefulWidget {
  const ShakeAlert({super.key, required this.color, required this.radius, required this.child});

  /// The outline colour; null means no alert.
  final Color? color;
  final double radius;
  final Widget child;

  @override
  State<ShakeAlert> createState() => _ShakeAlertState();
}

class _ShakeAlertState extends State<ShakeAlert> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _fade = AnimationController(vsync: this, duration: CafeMotion.quick);

  /// Kept after the alert ends, so the outline fades out in its own colour.
  Color? _color;

  @override
  void initState() {
    super.initState();
    _color = widget.color;
    if (_color != null) _fade.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShakeAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final active = widget.color != null;
    if (active) {
      _color = widget.color;
      _fade.animateTo(1, curve: CafeMotion.easeOut, duration: _still(context) ? Duration.zero : CafeMotion.quick);
    } else {
      _fade.animateBack(0, curve: CafeMotion.easeOut, duration: _still(context) ? Duration.zero : CafeMotion.quick);
    }
    if (active && !_still(context)) {
      if (!_shake.isAnimating) _shake.repeat();
    } else {
      _shake.stop();
      _shake.value = 0;
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shake, _fade]),
      child: widget.child,
      builder: (context, child) {
        final t = _shake.value;
        // A burst of wobbles in the first third of each cycle, then a rest.
        final burst = t < 0.3 ? t / 0.3 : 1.0;
        final wobble = t < 0.3 ? sin(burst * pi * 6) * 5 * (1 - burst) : 0.0;
        final color = _color;
        final visible = color != null && _fade.value > 0;
        return Transform.translate(
          offset: Offset(wobble, 0),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              border: visible ? Border.all(color: color.withValues(alpha: _fade.value), width: 3.5) : null,
              // A fixed glow: only the colour fades, so nothing is re-blurred between shakes.
              boxShadow: visible
                  ? [BoxShadow(color: color.withValues(alpha: 0.3 * _fade.value), blurRadius: 18, spreadRadius: 2)]
                  : null,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// A number that pops when it changes (cart counts, totals).
class BumpText extends StatelessWidget {
  const BumpText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _still(context) ? Duration.zero : const Duration(milliseconds: 260),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// The header colour as a soft diagonal gradient, for app bars and hero panels.
BoxDecoration brandGradient(CafeSurfaces surfaces, {BorderRadius? radius}) {
  final hsl = HSLColor.fromColor(surfaces.header);
  final lighter = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0)).toColor();
  final deeper = hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
  return BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: AlignmentDirectional.topStart,
      end: AlignmentDirectional.bottomEnd,
      colors: [lighter, deeper],
    ),
  );
}

/// Globe button with the waiter's language; opens a sheet to pick another. The waiter's choice
/// stays on this phone and never changes the till's language.
class WaiterLanguageButton extends StatelessWidget {
  const WaiterLanguageButton({super.key, this.color});

  /// Text and icon colour; the app bar's own colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final locale = context.select<WaiterController, String>((waiter) => waiter.locale);
    final ink = color ?? CafeSurfaces.of(context).onHeader;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 44),
          shape: StadiumBorder(side: BorderSide(color: ink.withValues(alpha: 0.35))),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => showWaiterLanguageSheet(context),
        icon: const Icon(Icons.language, size: 18),
        label: Text(locale.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
  }
}

Future<void> showWaiterLanguageSheet(BuildContext context) {
  final waiter = context.read<WaiterController>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) {
      final surfaces = CafeSurfaces.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in WaiterController.languages.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LanguageOption(
                    label: entry.value,
                    code: entry.key,
                    selected: waiter.locale == entry.key,
                    accent: surfaces.button,
                    onTap: () {
                      waiter.setLocale(entry.key);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.code,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: PressScale(
        child: AnimatedContainer(
          duration: CafeMotion.medium,
          curve: CafeMotion.easeOut,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : CafeColors.key,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? accent : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Text(
                    code.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: CafeMotion.quick,
                    child: Icon(Icons.check_circle, color: accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

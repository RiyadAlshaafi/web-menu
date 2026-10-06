import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../report_error.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';

class CafeLogo extends StatelessWidget {
  const CafeLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.compact = false,
    this.subtitle,
    this.light = false,
    this.mark,
  });

  final double size;
  final bool showWordmark;
  final bool compact;
  final String? subtitle;
  final bool light;
  final IconData? mark;

  @override
  Widget build(BuildContext context) {
    CafeStore? store;
    try {
      store = Provider.of<CafeStore>(context);
    } on ProviderNotFoundException {
      store = null;
    }
    final title = store?.cafeName ?? 'Café Italiano';
    final logo = store?.logoUrl ?? '';
    final titleColor = light ? Colors.white : CafeColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (size > 0)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: light ? Colors.white24 : const Color(0x1ABA5333),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: logo.isEmpty
                ? Icon(mark ?? Icons.local_cafe, color: light ? Colors.white : CafeColors.terracottaDark, size: size * 0.52)
                : ClipOval(
                    child: Image.network(
                      logo,
                      width: size,
                      height: size,
                      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(mark ?? Icons.local_cafe, color: light ? Colors.white : CafeColors.terracottaDark, size: size * 0.52),
                    ),
                  ),
          ),
        if (showWordmark) ...[
          if (size > 0) SizedBox(width: compact ? 8 : 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CafeTheme.brand.copyWith(
                  fontSize: compact ? 16 : 20,
                  color: titleColor,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: light ? Colors.white70 : CafeColors.inkMuted,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
            ],
          ),
          ),
        ],
      ],
    );
  }
}

/// Keeps a wide table readable and scrolls sideways when the window is narrow.
class WideTable extends StatelessWidget {
  const WideTable({super.key, required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        return Scrollbar(
          thumbVisibility: constraints.maxWidth < minWidth,
          notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: width, height: constraints.maxHeight, child: child),
          ),
        );
      },
    );
  }
}

class TerracottaButton extends StatelessWidget {
  const TerracottaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.height = 52,
    this.showArrow = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final double height;
  final bool showArrow;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: CafeSurfaces.of(context).onButton),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (showArrow) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ],
          );
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: height,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CafeSurfaces.of(context).button,
          foregroundColor: CafeSurfaces.of(context).onButton,
          disabledBackgroundColor: CafeColors.terracottaSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: child,
      ),
    );
  }
}

class SoftCard extends StatefulWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = CafeColors.paper,
    this.onTap,
    this.radius = 24,
    this.selected = false,
    this.hoverable = false,
    this.lightShadow = false,
    this.ink = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final bool selected;
  final bool hoverable;
  final bool lightShadow;
  final bool ink;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.hoverable;
    final borderColor = widget.selected
        ? CafeSurfaces.of(context).button
        : hover
            ? CafeSurfaces.of(context).button.withValues(alpha: 0.35)
            : CafeColors.line;
    final body = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: borderColor, width: widget.selected ? 1.6 : 1),
        boxShadow: widget.lightShadow
            ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 2))]
            : const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: widget.child,
    );
    if (!widget.ink) return body;
    if (!interactive && !widget.selected) return body;
    return MouseRegion(
      onEnter: widget.hoverable ? (_) => setState(() => hover = true) : null,
      onExit: widget.hoverable ? (_) => setState(() => hover = false) : null,
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(widget.radius),
          splashColor: CafeColors.terracotta.withValues(alpha: 0.12),
          highlightColor: CafeColors.terracotta.withValues(alpha: 0.06),
          child: body,
        ),
      ),
    );
  }
}

/// Opens a row on tap without joining the scroll gesture arena.
/// Fades and lifts [child] into place once when it first builds. [delay] lets
/// neighbours stagger. With reduced motion the child simply appears.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + CafeMotion.medium;
    final curve = Interval(
      delay.inMilliseconds / total.inMilliseconds,
      1,
      curve: CafeMotion.easeOut,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: curve,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
    );
  }
}

class ScrollFriendlyTap extends StatefulWidget {
  const ScrollFriendlyTap({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  static void claimPointer(BuildContext context) {
    context.findAncestorStateOfType<_ScrollFriendlyTapState>()?.claim();
  }

  @override
  State<ScrollFriendlyTap> createState() => _ScrollFriendlyTapState();
}

class _ScrollFriendlyTapState extends State<ScrollFriendlyTap> {
  var _moved = false;
  var _claimed = false;
  var _travel = 0.0;
  var _pressed = false;

  void claim() => _claimed = true;

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _moved = false;
        _travel = 0;
        if (widget.onTap != null) setState(() => _pressed = true);
      },
      onPointerMove: (event) {
        _travel += event.delta.distance;
        if (_travel > kTouchSlop) {
          _moved = true;
          _release();
        }
      },
      onPointerUp: (_) {
        _release();
        if (!_moved && !_claimed) widget.onTap?.call();
        _claimed = false;
      },
      onPointerCancel: (_) {
        _release();
        _claimed = false;
      },
      // Press state shows on finger-down; with reduced motion the card stays still.
      child: AnimatedScale(
        scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? 0.98 : 1,
        duration: CafeMotion.quick,
        curve: CafeMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

class DishPhoto extends StatelessWidget {
  const DishPhoto({
    super.key,
    required this.path,
    required this.size,
    this.width,
    this.radius = 14,
  });

  final String path;
  final double size;
  final double? width;
  final double radius;

  static final Map<String, Uint8List> _decoded = {};

  double get _w => width ?? size;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _image(cacheWidth: (_w * ratio).round(), cacheHeight: (size * ratio).round()) ?? _placeholder(),
    );
  }

  Widget? _image({required int cacheWidth, required int cacheHeight}) {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) {
      final bytes = _bytesFor(value);
      if (bytes == null) return null;
      return Image.memory(
        bytes,
        width: _w,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
      );
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final thumb = _thumbnailUrl(value, cacheWidth, cacheHeight);
      return Image.network(
        thumb,
        width: _w,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          if (thumb == value) return _placeholder();
          return Image.network(
            value,
            width: _w,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        },
      );
    }
    return null;
  }

  String _thumbnailUrl(String value, int cacheWidth, int cacheHeight) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.host.endsWith('.supabase.co')) return value;
    const marker = '/storage/v1/object/';
    if (!uri.path.contains(marker)) return value;
    return uri.replace(
      path: uri.path.replaceFirst(marker, '/storage/v1/render/image/'),
      queryParameters: {
        ...uri.queryParameters,
        'width': '${cacheWidth.clamp(1, 480)}',
        'height': '${cacheHeight.clamp(1, 480)}',
        'resize': 'cover',
      },
    ).toString();
  }

  Uint8List? _bytesFor(String value) {
    final cached = _decoded[value];
    if (cached != null) return cached;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = Uint8List.fromList(base64Decode(value.substring(comma + 1)));
      if (bytes.isEmpty) return null;
      return _decoded[value] = bytes;
    } catch (error, stackTrace) {
      reportError('menu image', error, stackTrace);
      return null;
    }
  }

  Widget _placeholder() {
    return Container(
      width: _w,
      height: size,
      color: CafeColors.terracottaSoft,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: CafeColors.terracottaDark, size: size * 0.38),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: (style ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        color: CafeColors.terracottaDark,
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CafeColors.inkMuted, fontSize: 15),
        ),
      ),
    );
  }
}

class CafeAuthFrame extends StatelessWidget {
  const CafeAuthFrame({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.background,
  });

  final Widget child;
  final double maxWidth;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.cream,
      body: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GhostChip extends StatelessWidget {
  const GhostChip({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.shield_outlined, size: 16, color: CafeColors.ink),
      label: Text(label, style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        backgroundColor: CafeColors.paper,
        side: const BorderSide(color: CafeColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

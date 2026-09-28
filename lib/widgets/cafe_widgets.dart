import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class TerracottaButton extends StatelessWidget {
  const TerracottaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
    this.height = 52,
    this.showArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final double height;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final child = Row(
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
        onPressed: onPressed,
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
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final bool selected;
  final bool hoverable;

  @override
  State<SoftCard> createState() => _SoftCardState();
}

class _SoftCardState extends State<SoftCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.hoverable;
    final borderColor = widget.selected
        ? CafeColors.terracotta
        : hover
            ? CafeColors.terracotta.withValues(alpha: 0.35)
            : CafeColors.line;
    final body = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: borderColor, width: widget.selected ? 1.6 : 1),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: widget.child,
    );
    if (!interactive && !widget.selected) return body;
    return MouseRegion(
      onEnter: interactive ? (_) => setState(() => hover = true) : null,
      onExit: interactive ? (_) => setState(() => hover = false) : null,
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

  double get _w => width ?? size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _image() ?? _placeholder(),
    );
  }

  Widget? _image() {
    final value = path.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:')) {
      final comma = value.indexOf(',');
      if (comma < 0) return null;
      try {
        final bytes = Uint8List.fromList(base64Decode(value.substring(comma + 1)));
        if (bytes.isEmpty) return null;
        return Image.memory(bytes, width: _w, height: size, fit: BoxFit.cover);
      } catch (_) {
        return null;
      }
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: _w,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return null;
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

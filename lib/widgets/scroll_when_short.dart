import 'package:flutter/material.dart';

/// Gives [child] at least [minHeightOf] of vertical room and scrolls the page when the window is
/// shorter, instead of overflowing. In a tall enough window the child is laid out exactly as before.
///
/// For screens built as a Column with Expanded children: those need a bounded height to share
/// out, and when there is not enough of it their fixed parts overflow and the rest is unreachable.
class ScrollWhenShort extends StatelessWidget {
  const ScrollWhenShort({super.key, required this.child, this.minHeight = 640, this.minHeightOf});

  final Widget child;

  /// Height the content needs, whatever the width.
  final double minHeight;

  /// Height the content needs for the given constraints (use when narrow windows stack more).
  final double Function(BoxConstraints constraints)? minHeightOf;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final needed = minHeightOf?.call(constraints) ?? minHeight;
        if (constraints.maxHeight >= needed) return child;
        return SingleChildScrollView(
          child: SizedBox(height: needed, width: constraints.maxWidth, child: child),
        );
      },
    );
  }
}

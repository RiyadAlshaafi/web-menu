import 'package:flutter/material.dart';

import '../theme/cafe_theme.dart';

/// Small building blocks of the Tawla staff design, so every console page reads the same:
/// white panels on the page colour, white search and select boxes, navy segmented pills,
/// outlined secondary buttons and soft status badges.

class TawlaTokens {
  static const muted = Color(0xFF56606A);
  static const border = Color(0xFFE3DED5);
  static const hairline = Color(0xFFF1EDE7);
  static const rowLine = Color(0xFFF7F3ED);
  static const dangerBorder = Color(0xFFF3C2B3);
}

/// A white panel with rounded corners, the main surface of every console page.
class TawlaPanel extends StatelessWidget {
  const TawlaPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color = Colors.white});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

/// Section heading inside a panel, such as "Recent Sales".
class PanelTitle extends StatelessWidget {
  const PanelTitle(this.text, {super.key, this.size = 17});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: CafeColors.ink, letterSpacing: -0.2));
  }
}

/// Small spaced capitals above a group, such as "TARGET CATEGORY".
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key, this.color = TawlaTokens.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: color));
  }
}

/// The white search box at the top of a page.
class PageSearchField extends StatelessWidget {
  const PageSearchField({super.key, required this.hint, this.controller, this.onChanged, this.filled = Colors.white});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Color filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 16, color: CafeColors.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF6B7A83), fontSize: 16),
          prefixIcon: const Icon(Icons.search, color: TawlaTokens.muted, size: 20),
          filled: true,
          fillColor: filled,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

/// A white select box, 52 px tall, used beside the search box.
class SelectBox<T> extends StatelessWidget {
  const SelectBox({super.key, required this.value, required this.items, required this.onChanged, this.minWidth = 160, this.filled = Colors.white, this.height = 52});

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final double minWidth;
  final Color filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
      decoration: BoxDecoration(color: filled, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.keyboard_arrow_down, color: CafeColors.ink),
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontFamilyFallback: CafeTheme.arabicFallback, fontSize: 15, fontWeight: FontWeight.w600, color: CafeColors.ink),
        ),
      ),
    );
  }
}

/// Mutually exclusive options in a white tray; the chosen one is filled with the header navy.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({super.key, required this.options, required this.selected, required this.onSelected, this.height = 44});

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 2),
              child: Semantics(
                button: true,
                selected: value == selected,
                child: Material(
                  color: value == selected ? surfaces.header : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onSelected(value),
                    child: Container(
                      height: height,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: value == selected ? surfaces.onHeader : CafeColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A rounded filter pill (category chips). Chosen pills are navy, the rest white with a hairline.
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap, this.height = 44});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? surfaces.header : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? surfaces.header : TawlaTokens.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? surfaces.onHeader : CafeColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// White outlined button for secondary actions; [danger] tints the label terracotta.
class OutlineAction extends StatelessWidget {
  const OutlineAction({super.key, required this.label, required this.onPressed, this.icon, this.danger = false, this.height = 40, this.expanded = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? CafeColors.terracottaDark : CafeColors.ink;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: fg,
        minimumSize: Size(height, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(color: danger ? TawlaTokens.dangerBorder : TawlaTokens.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), if (label.isNotEmpty) const SizedBox(width: 8)],
          if (label.isNotEmpty) Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
        ],
      ),
    );
    return SizedBox(width: expanded ? double.infinity : null, height: height, child: button);
  }
}

/// Square outlined icon button, such as edit or delete on a row.
class IconAction extends StatelessWidget {
  const IconAction({super.key, required this.icon, required this.tooltip, required this.onPressed, this.danger = false, this.size = 40});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: danger ? TawlaTokens.dangerBorder : TawlaTokens.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 18, semanticLabel: tooltip, color: danger ? CafeColors.terracottaDark : CafeColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Filled navy button for confirming secondary forms (Save colours, Print stand card).
class NavyButton extends StatelessWidget {
  const NavyButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 44, this.expanded = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return SizedBox(
      height: height,
      width: expanded ? double.infinity : null,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: surfaces.header,
          foregroundColor: surfaces.onHeader,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

enum BadgeTone { success, neutral, terracotta, navy, amber, danger }

/// Small rounded label for a status or kind, such as Active, Paid, Takeout or Table 2.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.dot = false});

  final String label;
  final BadgeTone tone;
  final bool dot;

  static (Color, Color) colors(BadgeTone tone) => switch (tone) {
        BadgeTone.success => (const Color(0xFFE4EEDF), const Color(0xFF2F5228)),
        BadgeTone.neutral => (const Color(0xFFF1EDE7), const Color(0xFF6B6A68)),
        BadgeTone.terracotta => (const Color(0xFFFFDBD1), CafeColors.terracottaDark),
        BadgeTone.navy => (const Color(0xFFE1ECF2), const Color(0xFF1B3A4B)),
        BadgeTone.amber => (const Color(0xFFFBEFD2), const Color(0xFF7A5512)),
        BadgeTone.danger => (const Color(0xFFF6DADA), CafeColors.alert),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(tone);
    if (dot) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
        ],
      );
    }
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg))),
    );
  }
}

/// Header cell text for the console tables.
class TableHead extends StatelessWidget {
  const TableHead(this.text, {super.key, this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: TawlaTokens.muted),
    );
  }
}

/// One headline number on a summary card. [dark] fills the card with the header navy (Net).
class FigureCard extends StatelessWidget {
  const FigureCard({super.key, required this.label, required this.value, this.caption, this.dot, this.valueColor, this.dark = false});

  final String label;
  final String value;
  final String? caption;
  final Color? dot;
  final Color? valueColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    final soft = dark ? const Color(0xFFB9C7CF) : TawlaTokens.muted;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: dark ? surfaces.header : Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (dot != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: soft))),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: dark ? Colors.white : (valueColor ?? surfaces.header),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: TextStyle(fontSize: 13, color: soft)),
          ],
        ],
      ),
    );
  }
}

/// A white "From 10/01/2026" box that opens the date picker.
class DateBox extends StatelessWidget {
  const DateBox({super.key, required this.label, required this.value, required this.onPicked});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  @override
  Widget build(BuildContext context) {
    final shown = value == null ? '—' : MaterialLocalizations.of(context).formatCompactDate(value!);
    return Semantics(
      button: true,
      label: '$label $shown',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDate: value ?? DateTime.now(),
            );
            onPicked(picked);
          },
          child: ExcludeSemantics(
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: TawlaTokens.muted)),
                  const SizedBox(width: 10),
                  Text(shown, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CafeColors.ink)),
                  const SizedBox(width: 14),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: CafeColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A form field with its label above it, as on the settings cards.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CafeColors.ink)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// A setting with a title, a hint and a switch, separated from the next by a hairline.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, required this.hint, required this.value, required this.onChanged, this.divider = true});

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: divider ? const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))) : null,
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                  const SizedBox(height: 2),
                  Text(hint, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

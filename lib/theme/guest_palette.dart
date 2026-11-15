import 'package:flutter/material.dart';

import 'cafe_theme.dart';

class GuestPalette {
  const GuestPalette({
    this.header = CafeColors.defaultHeader,
    this.background = CafeColors.cream,
    this.button = CafeColors.defaultButton,
    this.bottomBar = CafeColors.paper,
    this.card = CafeColors.paper,
  });

  factory GuestPalette.fromCafe(Map<String, dynamic> cafe) {
    final saved = cafe['qrTheme'];
    final map = saved is Map
        ? saved
        : {
            'header': cafe['headerColor'],
            'background': cafe['backgroundColor'],
            'button': cafe['buttonColor'],
          };
    Color read(String key, Color fallback) {
      final value = map[key];
      return CafeColors.parseHex(value is String ? value : null, fallback);
    }
    return GuestPalette(
      header: read('header', CafeColors.defaultHeader),
      background: read('background', CafeColors.cream),
      button: read('button', CafeColors.defaultButton),
      bottomBar: read('bottomBar', CafeColors.paper),
      card: read('card', CafeColors.paper),
    );
  }

  final Color header;
  final Color background;
  final Color button;
  final Color bottomBar;
  final Color card;

  GuestPalette copyWith({
    Color? header,
    Color? background,
    Color? button,
    Color? bottomBar,
    Color? card,
  }) => GuestPalette(
    header: header ?? this.header,
    background: background ?? this.background,
    button: button ?? this.button,
    bottomBar: bottomBar ?? this.bottomBar,
    card: card ?? this.card,
  );

  Map<String, String> toJson() => {
    'header': CafeColors.toHex(header),
    'background': CafeColors.toHex(background),
    'button': CafeColors.toHex(button),
    'bottomBar': CafeColors.toHex(bottomBar),
    'card': CafeColors.toHex(card),
  };

  GuestPalette get readable => GuestPalette(
    header: _readableFill(header),
    background: CafeColors.readableSurface(background),
    button: _readableFill(button),
    bottomBar: CafeColors.readableSurface(bottomBar),
    card: CafeColors.readableSurface(card),
  );

  static Color _readableFill(Color color) =>
      CafeColors.contrastRatio(color, CafeColors.contrastOn(color)) >= 4.5
          ? color
          : CafeColors.readableOn(color, [CafeColors.paper]);
}

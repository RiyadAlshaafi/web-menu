import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';

void main() {
  testWidgets('header, sidebar, background, and button stay independent', (tester) async {
    const surfaces = CafeSurfaces(
      header: Color(0xFF112233),
      sidebar: Color(0xFF445566),
      background: Color(0xFF778899),
      button: Color(0xFFAABBCC),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CafeTheme.forSurfaces(surfaces),
        home: Builder(
          builder: (context) {
            final theme = Theme.of(context);
            expect(theme.appBarTheme.backgroundColor, const Color(0xFF112233));
            expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
            expect(theme.scaffoldBackgroundColor, const Color(0xFF778899));
            expect(theme.colorScheme.surface, isNot(theme.appBarTheme.backgroundColor));
            expect(CafeSurfaces.of(context).sidebar, const Color(0xFF445566));
            expect(CafeSurfaces.of(context).button, const Color(0xFFAABBCC));
            expect(theme.scaffoldBackgroundColor, isNot(theme.appBarTheme.backgroundColor));
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
  });

  for (final entry in {'dark navy': const Color(0xFF0B1F33), 'bright yellow': const Color(0xFFFFE600), 'mid green': const Color(0xFF3FA34D)}.entries) {
    test('every button style follows the ${entry.key} button colour and stays readable', () {
      final surfaces = CafeSurfaces.defaults.copyWith(button: entry.value);
      final theme = CafeTheme.forSurfaces(surfaces);
      final filled = theme.filledButtonTheme.style!;
      final outlined = theme.outlinedButtonTheme.style!;
      final text = theme.textButtonTheme.style!;
      expect(filled.backgroundColor!.resolve({}), entry.value);
      expect(filled.foregroundColor!.resolve({}), surfaces.onButton);
      expect(outlined.foregroundColor!.resolve({}), surfaces.buttonInk);
      expect(outlined.side!.resolve({})!.color, surfaces.buttonInk);
      expect(text.foregroundColor!.resolve({}), surfaces.buttonInk);
      expect(theme.chipTheme.selectedColor, entry.value);
      expect(CafeColors.contrastRatio(entry.value, surfaces.onButton), greaterThanOrEqualTo(4.5));
      expect(CafeColors.contrastRatio(surfaces.buttonInk, CafeColors.paper), greaterThanOrEqualTo(4.5));
      expect(CafeColors.contrastRatio(surfaces.buttonInk, surfaces.background), greaterThanOrEqualTo(4.5));
    });
  }
}

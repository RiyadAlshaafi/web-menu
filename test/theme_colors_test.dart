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
}

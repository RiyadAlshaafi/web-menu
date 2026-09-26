import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CafeColors {
  static const cream = Color(0xFFFDF9F2);
  static const creamDark = Color(0xFFF1EDE7);
  static const paper = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFCF8);
  static const terracotta = Color(0xFFBA5333);
  static const terracottaDark = Color(0xFF9A3C1D);
  static const terracottaSoft = Color(0xFFFFDBD1);
  static const peach = Color(0xFFF6DED1);
  static const ink = Color(0xFF1C1C18);
  static const inkMuted = Color(0xFF56423C);
  static const line = Color(0xFFE8E6DE);
  static const key = Color(0xFFF7F3ED);
  static const success = Color(0xFF4F7A45);
  static const alert = Color(0xFFBA1A1A);
  static const sidebar = Color(0xFFFFFFFF);
}

class CafeTheme {
  static ThemeData get light {
    final textTheme = GoogleFonts.plusJakartaSansTextTheme().apply(
      bodyColor: CafeColors.ink,
      displayColor: CafeColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CafeColors.terracotta,
        surface: CafeColors.cream,
      ),
      scaffoldBackgroundColor: CafeColors.cream,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CafeColors.key,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: CafeColors.terracotta, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    );
  }

  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        color: CafeColors.ink,
        height: 1.15,
        letterSpacing: -0.4,
      );

  static TextStyle get brand => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        color: CafeColors.ink,
        letterSpacing: -0.4,
      );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/printing/pdf_text.dart';
import 'package:menu_web_v1/core/default_locale.dart';

void main() {
  test('brackets are swapped so Arabic prints them the right way round', () {
    expect(pdfMirrorBrackets('الإجمالي (بدون الملغاة): 25'), 'الإجمالي )بدون الملغاة(: 25');
    expect(pdfMirrorBrackets('[x] {y} <z>'), ']x[ }y{ >z<');
  });

  test('an Arabic line is cut into Arabic runs and number runs, with the × on its own', () {
    expect(pdfRuns('  1× قهوة تركية'), ['1', '×', 'قهوة تركية']);
    expect(pdfRuns('نقدا (3)'), ['نقدا', '(3)']);
    expect(pdfRuns('من 2026-11-01 إلى 2026-11-03'), ['من', '2026-11-01', 'إلى', '2026-11-03']);
    expect(pdfRuns('Coffee Latte (3)'), ['Coffee Latte (3)']);
  });

  test('vowel marks are left off printouts', () {
    expect(pdfStripMarks('نقداً'), 'نقدا');
  });

  test('the apps start in Arabic', () {
    expect(appLocale, 'ar');
  });
}

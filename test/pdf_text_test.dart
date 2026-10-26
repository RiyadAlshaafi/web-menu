import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/printing/pdf_text.dart';

void main() {
  test('brackets are swapped so Arabic prints them the right way round', () {
    expect(pdfMirrorBrackets('الإجمالي (بدون الملغاة): 25'), 'الإجمالي )بدون الملغاة(: 25');
    expect(pdfMirrorBrackets('[x] {y} <z>'), ']x[ }y{ >z<');
  });
}

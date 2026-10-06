const _formulaStarts = {'=', '+', '-', '@', '\t', '\r'};

/// Quotes [value] as one RFC 4180 CSV cell and neutralises spreadsheet
/// formulas: a text cell that starts with `= + - @` or a tab/CR gets a leading
/// `'` so Excel and Sheets show it as text instead of running it. Plain numbers
/// (including negatives) are left alone so numeric columns stay numeric.
String csvCell(Object? value) {
  var text = '${value ?? ''}';
  if (text.isNotEmpty && _formulaStarts.contains(text[0]) && double.tryParse(text) == null) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

/// Undoes the guard [csvCell] adds, so an exported file re-imports unchanged.
String csvUnguard(String text) {
  if (text.length > 1 && text[0] == "'" && _formulaStarts.contains(text[1])) {
    return text.substring(1);
  }
  return text;
}

import '../models/models.dart';

/// "No onion" for a removed ingredient, "+ Extra cheese 1.500" for a paid extra.
/// [without] wraps a name in the localized "No …"; [money] formats a price.
String choiceText(
  LineChoice choice,
  String locale, {
  required String Function(String name) without,
  String Function(double amount)? money,
}) {
  final name = choice.displayName(locale);
  if (!choice.on) return without(name);
  if (choice.price > 0 && money != null) return '+ $name ${money(choice.price)}';
  return '+ $name';
}

/// All of a line's choices on one line, removals first.
String choicesText(
  List<LineChoice> choices,
  String locale, {
  required String Function(String name) without,
  String Function(double amount)? money,
}) {
  final ordered = [...choices.where((choice) => !choice.on), ...choices.where((choice) => choice.on)];
  return ordered.map((choice) => choiceText(choice, locale, without: without, money: money)).join(' · ');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/core/choice_labels.dart';
import 'package:menu_web_v1/models/models.dart';

void main() {
  const onion = DishOption(id: 'onion', kind: DishOption.ingredient, nameAr: 'بصل', nameEn: 'Onion', price: 0.25, defaultOn: true);
  const pickles = DishOption(id: 'pickles', kind: DishOption.ingredient, nameAr: 'مخلل', nameEn: 'Pickles');
  const cheese = DishOption(id: 'cheese', kind: DishOption.topping, nameAr: 'جبنة', nameEn: 'Extra cheese', price: 1.5);

  MenuItem burger() => MenuItem(
    id: 'burger',
    nameIt: 'برجر',
    nameEn: 'Burger',
    price: 10,
    categoryId: 'food',
    discountPercent: 20,
    discountApplied: true,
    options: const [onion, pickles, cheese],
  );

  test('the defaults make a plain line at the dish price', () {
    final line = burger().lineWith(locale: 'en');
    expect(line.choices, isEmpty);
    expect(line.unitPrice, 8);
    expect(line.listUnitPrice, 10);
    expect(burger().lineWith(locale: 'en', onIds: burger().defaultOnIds).choices, isEmpty);
  });

  test('extras are charged in full, removals are free and the discount stays on the dish', () {
    final line = burger().lineWith(locale: 'en', onIds: {'pickles', 'cheese'}, qty: 2);
    expect(line.choices.map((choice) => (choice.id, choice.on, choice.price)), [
      ('onion', false, 0.0),
      ('pickles', true, 0.0),
      ('cheese', true, 1.5),
    ]);
    expect(line.unitPrice, 9.5);
    expect(line.listUnitPrice, 11.5);
    expect(line.total, 19);
    expect(line.discountAmount, 4);
  });

  test('unknown option ids are ignored', () {
    expect(burger().lineWith(locale: 'en', onIds: {'onion', 'ghost'}).choices, isEmpty);
  });

  test('lines merge only when their choices match, whatever the order', () {
    final a = burger().lineWith(locale: 'en', onIds: {'cheese', 'pickles', 'onion'});
    final b = burger().lineWith(locale: 'en', onIds: {'onion', 'pickles', 'cheese'});
    final plain = burger().lineWith(locale: 'en');
    expect(a.mergeKey, b.mergeKey);
    expect(a.mergeKey, isNot(plain.mergeKey));
  });

  test('the on set comes back from a line', () {
    final line = burger().lineWith(locale: 'en', onIds: {'cheese'});
    expect(onIdsFor(burger().options, line.choices), {'cheese'});
    expect(onIdsFor(burger().options, const []), {'onion'});
  });

  test('options and choices survive a json round trip', () {
    final item = MenuItem.fromJson(burger().toJson());
    expect(item.options.map((option) => option.syncKey), burger().options.map((option) => option.syncKey));
    expect(item.syncKey, burger().syncKey);

    final line = OrderLine.fromJson(burger().lineWith(locale: 'en', onIds: {'onion', 'cheese'}).toJson());
    expect(line.choices.single.nameEn, 'Extra cheese');
    expect(line.choices.single.price, 1.5);
    expect(line.withQty(3).choices.single.id, 'cheese');
  });

  test('old saved data without options or choices still loads', () {
    final item = MenuItem.fromJson({'id': 'x', 'price': 2, 'categoryId': 'c'});
    expect(item.options, isEmpty);
    final line = OrderLine.fromJson({'menuItemId': 'x', 'name': 'X', 'qty': 1, 'unitPrice': 2});
    expect(line.choices, isEmpty);
    expect(line.toJson().containsKey('choices'), isFalse);
  });

  test('malformed stored options are dropped instead of failing the load', () {
    final item = MenuItem.fromJson({
      'id': 'x',
      'price': 2,
      'categoryId': 'c',
      'options': [
        'nonsense',
        {'kind': 'topping'},
        cheese.toJson(),
      ],
    });
    expect(item.options.single.id, 'cheese');
  });

  test('new option ids are v4 uuids', () {
    expect(DishOption.newId(), matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
  });

  test('choice labels list removals first, then extras with their price', () {
    final line = burger().lineWith(locale: 'en', onIds: {'cheese', 'pickles'});
    final text = choicesText(line.choices, 'en', without: (name) => 'No $name', money: (amount) => amount.toStringAsFixed(3));
    expect(text, 'No Onion · + Pickles · + Extra cheese 1.500');
    expect(choicesText(line.choices, 'ar', without: (name) => 'بدون $name'), 'بدون بصل · + مخلل · + جبنة');
  });
}

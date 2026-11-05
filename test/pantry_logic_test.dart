import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/models.dart';
import 'package:pantrypal/backend/recipe_data_source.dart';
import 'package:pantrypal/features/pantry/pantry_logic.dart';
import 'package:pantrypal/features/pantry/recipe_matching.dart';

PantryItem item(
  String name, {
  DateTime? date,
  String location = 'fridge',
  num quantity = 1,
}) => PantryItem(
  id: name,
  name: name,
  quantity: quantity,
  storageLocationId: location,
  expiresOn: date,
);

void main() {
  test(
    'orders dated inventory before undated inventory without mutating input',
    () {
      final items = [
        item('Milk'),
        item('Rice', date: DateTime(2026, 11, 9)),
        item('Eggs', date: DateTime(2026, 11, 4)),
      ];
      expect(sortedPantry(items).map((item) => item.name), [
        'Eggs',
        'Rice',
        'Milk',
      ]);
      expect(items.first.name, 'Milk');
    },
  );

  test('date reminders use calendar days across daylight saving changes', () {
    expect(daysUntil(DateTime(2026, 11, 2), DateTime(2026, 11, 1, 23)), 1);
    expect(
      isUseSoon(
        item('Milk', date: DateTime(2026, 11, 11)),
        DateTime(2026, 11, 4),
      ),
      isTrue,
    );
    expect(
      isUseSoon(
        item('Milk', date: DateTime(2026, 11, 12)),
        DateTime(2026, 11, 4),
      ),
      isFalse,
    );
    expect(
      isUseSoon(
        item('Milk', date: DateTime(2026, 11, 3)),
        DateTime(2026, 11, 4),
      ),
      isTrue,
    );
    expect(isUseSoon(item('Milk'), DateTime(2026, 11, 4)), isFalse);
  });

  test('rejects empty, zero, negative and nonfinite quantities', () {
    for (final value in ['', '0', '-1', 'NaN', 'Infinity', 'abc']) {
      expect(validatePantryQuantity(value), isNotNull, reason: value);
    }
    expect(validatePantryQuantity('0.5'), isNull);
  });

  test('recipe filters select relevant recipes but count all household ingredients', () {
    const recipe = PantryRecipe(
      id: 'pasta',
      name: 'Pasta',
      ingredients: ['pasta', 'tomatoes', 'cheese', 'olive oil'],
      instructions: ['Cook.'],
    );
    final pantry = [
      item(' Pasta ', location: 'cupboard'),
      item('TOMATOES', date: DateTime(2026, 11, 5)),
      item('cheese'),
    ];
    final result = matchRecipes(
      [recipe],
      pantry,
      location: 'fridge',
      useSoonOnly: true,
      now: DateTime(2026, 11, 4),
    ).single;
    expect(result.matching, ['pasta', 'tomatoes', 'cheese']);
    expect(result.missing, ['olive oil']);
    expect(
      matchRecipes(
        [recipe],
        pantry,
        location: 'freezer',
        now: DateTime(2026, 11, 4),
      ),
      isEmpty,
    );
    expect(
      matchRecipes(
        [recipe],
        [item('pasta', quantity: 0)],
        now: DateTime(2026, 11, 4),
      ),
      isEmpty,
    );
  });
}

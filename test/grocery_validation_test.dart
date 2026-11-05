import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/grocery_data_source.dart';
import 'package:pantrypal/backend/models.dart';

GroceryItem item({
  String name = 'Milk',
  num quantity = 1,
  bool purchased = false,
}) => GroceryItem(
  id: 'milk',
  name: name,
  quantity: quantity,
  createdBy: 'user',
  isPurchased: purchased,
);

void main() {
  test('rejects empty names and invalid numeric quantities', () {
    for (final quantity in [0, -1, double.nan, double.infinity]) {
      expect(() => validateGroceryInput('Milk', quantity), throwsArgumentError);
    }
    expect(() => validateGroceryInput('  ', 1), throwsArgumentError);
    expect(() => validateGroceryInput(' Milk ', 1.5), returnsNormally);
  });
  test(
    'rejects stale edits and deletions after another member changes the item',
    () {
      for (final changed in [
        null,
        item(name: 'Bread'),
        item(quantity: 2),
        item(purchased: true),
      ]) {
        expect(
          () => checkGroceryUnchanged(item(), changed),
          throwsA(isA<GroceryConflict>()),
        );
      }
      expect(() => checkGroceryUnchanged(item(), item()), returnsNormally);
    },
  );
}

import 'models.dart';

/// Household grocery operations shared by the UI and repository.
abstract interface class GroceryDataSource {
  String get currentUserId;
  Stream<List<GroceryItem>> watchGroceryItems(String householdId);
  Future<void> addGroceryItem({
    required String householdId,
    required String name,
    required num quantity,
  });
  Future<void> updateGroceryItem({
    required String householdId,
    required GroceryItem expected,
    required String name,
    required num quantity,
  });
  Future<void> deleteGroceryItem({
    required String householdId,
    required GroceryItem expected,
  });
  Future<void> purchaseToPantry({
    required String householdId,
    required String groceryItemId,
    required String storageLocationId,
    DateTime? expiresOn,
  });
}

class GroceryConflict implements Exception {
  const GroceryConflict();
  @override
  String toString() =>
      'This item changed or was removed. Close this dialog and check the updated list.';
}

void validateGroceryInput(String name, num quantity) {
  if (name.trim().isEmpty || !quantity.isFinite || quantity <= 0) {
    throw ArgumentError(
      'Enter an item name and a finite quantity greater than zero.',
    );
  }
}

/// Prevent an old edit/delete dialog from overwriting a roommate's changes.
void checkGroceryUnchanged(GroceryItem expected, GroceryItem? current) {
  if (current == null ||
      current.name != expected.name ||
      current.quantity != expected.quantity ||
      current.isPurchased != expected.isPurchased) {
    throw const GroceryConflict();
  }
}

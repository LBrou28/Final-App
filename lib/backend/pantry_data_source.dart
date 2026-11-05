import 'models.dart';

/// Shared contract for household inventory screens and their tests.
abstract interface class PantryDataSource {
  Stream<List<PantryItem>> watchPantryItems(String householdId);

  Future<void> updatePantryItem({
    required String householdId,
    required String itemId,
    required num quantity,
    required String storageLocationId,
    DateTime? expiresOn,
  });

  Future<void> useUpPantryItem({
    required String householdId,
    required String itemId,
  });
}

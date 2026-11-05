import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantryRecipe {
  const PantryRecipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
  });
  final String id;
  final String name;
  final List<String> ingredients;
  final List<String> instructions;
}

abstract interface class RecipeDataSource {
  Stream<List<PantryRecipe>> watchRecipes();
  Future<void> addMissingIngredients({
    required String householdId,
    required List<String> ingredients,
  });
}

/// Curated recipes are server-managed, with authenticated read access only.
class FirestoreRecipeDataSource implements RecipeDataSource {
  FirestoreRecipeDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  Stream<List<PantryRecipe>> watchRecipes() => _firestore
      .collection('recipeCatalog')
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return PantryRecipe(
            id: doc.id,
            name: data['name'] as String,
            ingredients: List<String>.from(data['ingredients'] as List),
            instructions: List<String>.from(data['instructions'] as List),
          );
        }).toList(),
      );

  @override
  Future<void> addMissingIngredients({
    required String householdId,
    required List<String> ingredients,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final batch = _firestore.batch();
    for (final name in ingredients.toSet()) {
      batch.set(
        _firestore
            .collection('households')
            .doc(householdId)
            .collection('groceryItems')
            .doc(),
        {
          'name': name,
          'quantity': 1,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'isPurchased': false,
        },
      );
    }
    await batch.commit();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/models.dart';
import 'package:pantrypal/backend/recipe_data_source.dart';
import 'package:pantrypal/features/pantry/recipes_page.dart';

import 'pantry_page_test.dart' show FakePantry;

class FakeRecipes implements RecipeDataSource {
  final controller = StreamController<List<PantryRecipe>>.broadcast();
  bool fail = true;
  List<String>? added;
  String? household;
  @override
  Stream<List<PantryRecipe>> watchRecipes() => controller.stream;
  @override
  Future<void> addMissingIngredients({
    required String householdId,
    required List<String> ingredients,
  }) async {
    if (fail) throw StateError('offline');
    added = ingredients;
    household = householdId;
  }
}

void main() {
  testWidgets(
    'shows matches and missing ingredients, retries failed grocery writes',
    (tester) async {
      final pantry = FakePantry();
      final recipes = FakeRecipes();
      addTearDown(pantry.controller.close);
      addTearDown(recipes.controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: RecipesPage(
            householdId: 'shared-home',
            pantry: pantry,
            recipes: recipes,
          ),
        ),
      );
      pantry.controller.add([
        for (final name in ['pasta', 'tomatoes', 'cheese'])
          PantryItem(
            id: name,
            name: name,
            quantity: 1,
            storageLocationId: 'fridge',
          ),
      ]);
      recipes.controller.add([
        const PantryRecipe(
          id: 'pasta',
          name: 'Tomato pasta',
          ingredients: ['pasta', 'tomatoes', 'cheese', 'olive oil'],
          instructions: ['Cook pasta.', 'Add sauce.'],
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.text('In your pantry: pasta, tomatoes, cheese'),
        findsOneWidget,
      );
      expect(find.text('Missing: olive oil'), findsOneWidget);
      await tester.tap(find.text('Add missing to groceries'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not add ingredients'), findsOneWidget);
      recipes.fail = false;
      await tester.tap(find.text('Add missing to groceries'));
      await tester.pumpAndSettle();
      expect(recipes.added, ['olive oil']);
      expect(recipes.household, 'shared-home');
      expect(find.text('Added to groceries'), findsOneWidget);
    },
  );
}

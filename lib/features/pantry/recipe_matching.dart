import '../../backend/models.dart';
import '../../backend/recipe_data_source.dart';
import 'pantry_logic.dart';

String ingredientKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class RecipeMatch {
  RecipeMatch(this.recipe, Set<String> available)
    : matching = recipe.ingredients
          .where((item) => available.contains(ingredientKey(item)))
          .toList(),
      missing = recipe.ingredients
          .where((item) => !available.contains(ingredientKey(item)))
          .toList();
  final PantryRecipe recipe;
  final List<String> matching;
  final List<String> missing;
}

List<RecipeMatch> matchRecipes(
  List<PantryRecipe> recipes,
  List<PantryItem> pantry, {
  String? location,
  bool useSoonOnly = false,
  required DateTime now,
}) {
  final available = pantry
      .where((item) => item.quantity > 0)
      .map((item) => ingredientKey(item.name))
      .toSet();
  final selected = pantry
      .where(
        (item) =>
            item.quantity > 0 &&
            (location == null ||
                item.storageLocationId.toLowerCase() == location) &&
            (!useSoonOnly || isUseSoon(item, now)),
      )
      .map((item) => ingredientKey(item.name))
      .toSet();
  return recipes
      .map((recipe) => RecipeMatch(recipe, available))
      .where(
        (match) => match.matching.any(
          (name) => selected.contains(ingredientKey(name)),
        ),
      )
      .toList()
    ..sort((a, b) {
      final missing = a.missing.length.compareTo(b.missing.length);
      if (missing != 0) return missing;
      final matching = b.matching.length.compareTo(a.matching.length);
      return matching == 0 ? a.recipe.name.compareTo(b.recipe.name) : matching;
    });
}

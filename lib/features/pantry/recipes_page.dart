import 'package:flutter/material.dart';

import '../../backend/models.dart';
import '../../backend/pantry_data_source.dart';
import '../../backend/recipe_data_source.dart';
import 'pantry_logic.dart';
import 'recipe_matching.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, required this.householdId, required this.pantry, required this.recipes});
  final String householdId;
  final PantryDataSource pantry;
  final RecipeDataSource recipes;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  late Stream<List<PantryItem>> _pantry;
  late Stream<List<PantryRecipe>> _recipes;
  String? _location;
  bool _soon = false;
  final Set<String> _adding = {};
  final Set<String> _added = {};

  @override
  void initState() { super.initState(); _subscribe(); }

  void _subscribe() {
    _pantry = widget.pantry.watchPantryItems(widget.householdId);
    _recipes = widget.recipes.watchRecipes();
  }

  @override
  void didUpdateWidget(covariant RecipesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId || oldWidget.pantry != widget.pantry || oldWidget.recipes != widget.recipes) {
      _subscribe(); _added.clear();
    }
  }

  Future<void> _add(RecipeMatch match) async {
    setState(() => _adding.add(match.recipe.id));
    try {
      await widget.recipes.addMissingIngredients(householdId: widget.householdId, ingredients: match.missing);
      if (mounted) {
        setState(() => _added.add(match.recipe.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing ingredients added to the shared grocery list. Quantities start at 1; adjust them for your recipe.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add ingredients. Please try again.')));
    } finally {
      if (mounted) setState(() => _adding.remove(match.recipe.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('What can we make?')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('All locations'), selected: _location == null, onSelected: (_) => setState(() => _location = null)),
          for (final location in storageLocations) ChoiceChip(label: Text(locationLabel(location)), selected: _location == location, onSelected: (_) => setState(() => _location = location)),
          FilterChip(label: const Text('Use soon items'), selected: _soon, onSelected: (value) => setState(() => _soon = value)),
        ]),
        const Text('Matches use ingredient names, ignoring case and extra spaces. Check quantities before cooking.'),
      ])),
      Expanded(child: StreamBuilder<List<PantryItem>>(stream: _pantry, builder: (context, inventory) =>
        StreamBuilder<List<PantryRecipe>>(stream: _recipes, builder: (context, catalog) {
          if (inventory.hasError || catalog.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load recipe ideas.'), TextButton(onPressed: () => setState(_subscribe), child: const Text('Retry')),
          ]));
          if (!inventory.hasData || !catalog.hasData) return const Center(child: CircularProgressIndicator());
          if (inventory.data!.isEmpty) return const Center(child: Text('Add items to your pantry to find recipe ideas.'));
          if (catalog.data!.isEmpty) return const Center(child: Text('The household recipe catalog is not available yet. Please try again later.'));
          final matches = matchRecipes(catalog.data!, inventory.data!, location: _location, useSoonOnly: _soon, now: DateTime.now());
          if (matches.isEmpty) return const Center(child: Text('No recipe ideas match these items. Try another filter.'));
          return ListView.builder(itemCount: matches.length, padding: const EdgeInsets.all(12), itemBuilder: (context, index) {
            final match = matches[index];
            return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(match.recipe.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('In your pantry: ${match.matching.join(', ')}'),
              Text(match.missing.isEmpty ? 'No missing ingredients' : 'Missing: ${match.missing.join(', ')}'),
              const SizedBox(height: 8),
              for (var step = 0; step < match.recipe.instructions.length; step++) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${step + 1}. ${match.recipe.instructions[step]}')),
              if (match.missing.isNotEmpty) FilledButton.icon(
                onPressed: _adding.contains(match.recipe.id) || _added.contains(match.recipe.id) ? null : () => _add(match),
                icon: const Icon(Icons.playlist_add),
                label: Text(_adding.contains(match.recipe.id) ? 'Adding…' : _added.contains(match.recipe.id) ? 'Added to groceries' : 'Add missing to groceries')),
            ])));
          });
        }))),
    ]),
  );
}

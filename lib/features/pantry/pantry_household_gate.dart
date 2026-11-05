import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../backend/household_repository.dart';
import '../../backend/models.dart';
import '../../backend/recipe_data_source.dart';
import 'pantry_page.dart';
import 'recipes_page.dart';

/// Role 1 can bypass this selector by passing its active household directly to
/// PantryPage or RecipesPage. No household IDs are invented by the UI.
class PantryHouseholdGate extends StatefulWidget {
  const PantryHouseholdGate({super.key, this.showRecipes = false});
  final bool showRecipes;

  @override
  State<PantryHouseholdGate> createState() => _PantryHouseholdGateState();
}

class _PantryHouseholdGateState extends State<PantryHouseholdGate> {
  late final _repository = HouseholdRepository();
  late final _recipes = FirestoreRecipeDataSource();
  late final _auth = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(stream: _auth, builder: (context, auth) {
    if (auth.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (auth.hasError) return const Center(child: Text('Could not check your account. Please reopen this screen.'));
    if (auth.data == null) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Sign in and join a household to see shared pantry items and recipe ideas.')));
    return _HouseholdPicker(key: ValueKey(auth.data!.uid), repository: _repository, recipes: _recipes, showRecipes: widget.showRecipes);
  });
}

class _HouseholdPicker extends StatefulWidget {
  const _HouseholdPicker({super.key, required this.repository, required this.recipes, required this.showRecipes});
  final HouseholdRepository repository;
  final RecipeDataSource recipes;
  final bool showRecipes;
  @override
  State<_HouseholdPicker> createState() => _HouseholdPickerState();
}

class _HouseholdPickerState extends State<_HouseholdPicker> {
  late Stream<List<Household>> _households;
  String? _selected;
  @override
  void initState() { super.initState(); _households = widget.repository.watchHouseholdsForCurrentUser(); }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Household>>(stream: _households, builder: (context, snapshot) {
    if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Could not load households.'), TextButton(onPressed: () => setState(() => _households = widget.repository.watchHouseholdsForCurrentUser()), child: const Text('Retry')),
    ]));
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    final households = snapshot.data!;
    if (households.isEmpty) return const Center(child: Text('Join or create a household to get started.'));
    final id = households.any((household) => household.id == _selected) ? _selected! : households.first.id;
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: DropdownButton<String>(
        value: id, isExpanded: true, hint: const Text('Household'),
        items: households.map((household) => DropdownMenuItem(value: household.id, child: Text(household.name))).toList(),
        onChanged: (value) => setState(() => _selected = value))),
      Expanded(child: widget.showRecipes
        ? RecipesPage(key: ValueKey('recipes-$id'), householdId: id, pantry: widget.repository, recipes: widget.recipes)
        : PantryPage(key: ValueKey('pantry-$id'), householdId: id, source: widget.repository)),
    ]);
  });
}

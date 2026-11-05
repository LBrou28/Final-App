import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/grocery/grocery_list_page.dart';
import 'features/pantry/pantry_household_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PantryPalApp());
}

class PantryPalApp extends StatelessWidget {
  const PantryPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PantryPal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _selected = 0;
  // Keep the existing local grocery list alive when visiting another screen.
  final Widget _groceries = const GroceryListPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Stack(children: [
      Offstage(offstage: _selected != 0, child: _groceries),
      if (_selected != 0) PantryHouseholdGate(key: ValueKey(_selected), showRecipes: _selected == 2),
    ])),
    bottomNavigationBar: NavigationBar(selectedIndex: _selected,
      onDestinationSelected: (value) => setState(() => _selected = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Groceries'),
        NavigationDestination(icon: Icon(Icons.kitchen_outlined), label: 'Pantry'),
        NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Recipes'),
      ]),
  );
}

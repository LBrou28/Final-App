import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../backend/household_repository.dart';
import '../../backend/models.dart';
import '../../backend/recipe_data_source.dart';
import 'pantry_page.dart';
import 'recipes_page.dart';
import '../grocery/grocery_list_page.dart';
import '../account/sign_in_page.dart';
import '../account/household_dialog.dart';

/// Role 1 can bypass this selector by passing its active household directly to
/// PantryPage or RecipesPage. No household IDs are invented by the UI.
class PantryHouseholdGate extends StatefulWidget {
  const PantryHouseholdGate({
    super.key,
    this.showRecipes = false,
    this.showGroceries = false,
  });
  final bool showRecipes;
  final bool showGroceries;

  @override
  State<PantryHouseholdGate> createState() => _PantryHouseholdGateState();
}

class _PantryHouseholdGateState extends State<PantryHouseholdGate> {
  late final _repository = HouseholdRepository();
  late final _recipes = FirestoreRecipeDataSource();
  late final _auth = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _auth,
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (auth.hasError) {
        return const Center(
          child: Text(
            'Could not check your account. Please reopen this screen.',
          ),
        );
      }
      if (auth.data == null) {
        return SignInPage(
          authenticate: (email, password, create) async {
            if (create) {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
            } else {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
            }
          },
          resetPassword: (email) =>
              FirebaseAuth.instance.sendPasswordResetEmail(email: email),
        );
      }
      return _HouseholdPicker(
        key: ValueKey(auth.data!.uid),
        repository: _repository,
        recipes: _recipes,
        showRecipes: widget.showRecipes,
        showGroceries: widget.showGroceries,
      );
    },
  );
}

class _HouseholdPicker extends StatefulWidget {
  const _HouseholdPicker({
    super.key,
    required this.repository,
    required this.recipes,
    required this.showRecipes,
    required this.showGroceries,
  });
  final HouseholdRepository repository;
  final RecipeDataSource recipes;
  final bool showRecipes;
  final bool showGroceries;
  @override
  State<_HouseholdPicker> createState() => _HouseholdPickerState();
}

class _HouseholdPickerState extends State<_HouseholdPicker> {
  late Stream<List<Household>> _households;
  String? _selected;
  bool _signingOut = false;

  Future<void> _household(bool create) async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HouseholdDialog(
        create: create,
        submit: (value) => create
            ? widget.repository.createHousehold(name: value)
            : widget.repository.joinHousehold(inviteCode: value),
      ),
    );
    if (mounted && id != null) setState(() => _selected = id);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Future<void> _details(String id) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Household details'),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: widget.repository.householdInvite(id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Could not load invite code. Reopen to retry.',
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator();
                    }
                    return SelectableText(
                      snapshot.data == null
                          ? 'For an older household, ask its creator for the original invite code.'
                          : 'Invite code: ${snapshot.data}',
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text('Members'),
                StreamBuilder<List<HouseholdMember>>(
                  stream: widget.repository.watchMembers(id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Could not load members. Reopen to retry.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!
                          .map(
                            (member) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${member.userId == widget.repository.currentUserId ? 'You' : 'Member ${member.userId.substring(0, member.userId.length < 6 ? member.userId.length : 6)}'} — ${member.role}',
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _actions() => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => _household(true),
        child: const Text('Create household'),
      ),
      TextButton(
        onPressed: () => _household(false),
        child: const Text('Join household'),
      ),
      TextButton(
        onPressed: _signingOut ? null : _signOut,
        child: const Text('Sign out'),
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    _households = widget.repository.watchHouseholdsForCurrentUser();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Household>>(
    stream: _households,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load households.'),
              _actions(),
              TextButton(
                onPressed: () => setState(
                  () => _households = widget.repository
                      .watchHouseholdsForCurrentUser(),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final households = snapshot.data!;
      if (households.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Join or create a household to get started.'),
              _actions(),
            ],
          ),
        );
      }
      final id = households.any((household) => household.id == _selected)
          ? _selected!
          : households.first.id;
      return Column(
        children: [
          _actions(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: id,
              isExpanded: true,
              hint: const Text('Household'),
              items: households
                  .map(
                    (household) => DropdownMenuItem(
                      value: household.id,
                      child: Text(household.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            ),
          ),
          TextButton(
            onPressed: () => _details(id),
            child: const Text('Invite code & members'),
          ),
          Expanded(
            child: widget.showGroceries
                ? GroceryListPage(
                    key: ValueKey('groceries-$id'),
                    householdId: id,
                    source: widget.repository,
                  )
                : widget.showRecipes
                ? RecipesPage(
                    key: ValueKey('recipes-$id'),
                    householdId: id,
                    pantry: widget.repository,
                    recipes: widget.recipes,
                  )
                : PantryPage(
                    key: ValueKey('pantry-$id'),
                    householdId: id,
                    source: widget.repository,
                  ),
          ),
        ],
      );
    },
  );
}

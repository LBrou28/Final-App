# Role 3: Pantry, Use Soon, and recipes

Implemented from Trello cards 12, 13, 14, and 22.

## Screens

The bottom navigation exposes Pantry and Recipes. Pantry streams the active
household's inventory, filters Fridge/Freezer/Cupboard, and edits quantity,
storage location, and optional date. Used up asks for confirmation and deletes
the item only after the server accepts the request. Failed writes retain the
existing inventory and display a retryable error.

Use Soon sorts dated items by calendar day, puts undated items in a separate
section, and highlights entered dates within seven days, including past dates.
Entered dates are reminders, not food-safety advice. A date picker prevents
malformed dates and allows past dates to be recorded rather than silently
discarding them. Quantities must be finite and greater than zero.

What can we make? streams the server's curated recipe catalog, shows matching
and missing ingredients and text instructions, and atomically adds a recipe's
missing ingredients to household groceryItems. New grocery quantities start at
1 and should be adjusted by the user. Matching ignores case and repeated spaces;
it does not infer quantities, synonyms, substitutions, allergies, or nutrition.
Location and Use soon filters select recipes using those pantry items while
matching ingredients against the entire household inventory.

## Integration dependencies

- Role 1 still needs to implement sign-in and create/join household screens. Until
  signed in, Pantry and Recipes display an account/household explanation. No
  fake household or anonymous account is created by these screens.
- Role 1 can directly construct `PantryPage(householdId: ..., source: repository)`
  and `RecipesPage(householdId: ..., pantry: repository, recipes: ...)` with its
  active household. The current selector uses the existing repository's own-
  membership query; its collection-group rule and index are source-controlled.
- Role 2's current grocery screen holds local in-memory data. It must switch to
  `watchGroceryItems` and `purchaseToPantry` for its purchased items to appear in
  the real pantry, and to display ingredients added by Recipes. Those local
  grocery items are not represented as persisted household pantry data.
- The pantry stream intentionally does not order by expiresOn in Firestore;
  this includes older records without that optional field. Sorting is in Dart.
- Firestore reads/writes, cross-device syncing, and rules need emulator/live
  integration verification. Widget tests use injected data sources and do not
  claim to exercise production Firebase.

## Administrator setup (not executed)

Publish the Firestore rules and indexes through the project's existing Firebase
deployment process. Review the rules before deploying, including the own-
membership collection-group query and authenticated read-only recipeCatalog.

The 12 reviewed recipes live in `data/recipes.json`. To publish them, an
administrator with Firestore write permissions should obtain a short-lived
Google OAuth access token, set `GOOGLE_OAUTH_ACCESS_TOKEN` in their environment,
and run:

```sh
python tools/publish_recipe_catalog.py --project finalapp-cae16
```

The publisher uses only Python's standard library. It sends a single atomic
commit and overwrites the 12 stable recipe IDs, making reruns idempotent. It
does not delete other catalog records. Do not commit tokens or credentials.
The client cannot write catalog records. An empty or inaccessible catalog has
its own empty/error state; the app never substitutes a pretend server response.

## Validation

- Dart formatting and fatal-info analysis pass.
- All 12 Flutter tests pass, covering existing grocery/store behavior plus
  reminder ordering, daylight-saving calendar arithmetic, invalid quantities,
  ingredient filters, empty/error states, save retries, confirmed use-up, and
  missing-ingredient write retries.
- Android build was attempted but this machine has no configured Android SDK.
- Local Flutter is 3.47.2 / Dart 3.13.2; CI specifies Flutter 3.47.7.
- No Firebase deployment, catalog publication, or two-phone test was performed.

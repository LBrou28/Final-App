# Role 2: Shared groceries and purchase flow

The grocery screen now streams household grocery items from Firebase through
the existing repository. Add, edit, and confirmed delete persist through that
repository; Recipes' missing-ingredient writes appear in the same list.
Groceries, Pantry, and Recipes retain the selected household across tab changes.

Purchasing asks for fridge, freezer, or cupboard and an optional date, then uses
the existing transaction to mark the grocery purchased and create pantry stock.
Purchased entries cannot be unchecked or edited: inventory changes belong in
Pantry. Deleting a purchased grocery entry keeps its pantry inventory.

Names must be nonempty and quantities finite and positive. Failed writes retain
dialog input and allow retry. Pending saves disable repeat submission. Editing
and deleting compare the current server record with the opened record inside a
transaction, rejecting changes that would overwrite a roommate's update.
Contributor labels distinguish the current user from other household members;
display names await account/profile integration.

## Verification and handoff

- All 19 Flutter tests pass, including stream changes, input validation, write
  failures and retries, conflicting edits, confirmation, and duplicate taps.
- Tests use injected sources; they do not verify deployed Firestore rules or
  real cross-device behavior.
- Existing CI runs all Flutter tests, formatting, analysis, and an Android debug
  build on every push and pull request. It does not run Firebase emulator tests.
- Role 1 must finish sign-in and create/join household UI. The current gate
  intentionally requires an authenticated user with household membership.
- The Firebase owner must verify deployed rules/indexes and publish the recipe
  catalog using the Role 3 handoff before live testing.

## Required two-device acceptance check

1. Sign in as two different members of one household; verify a nonmember cannot
   read or modify that household.
2. Add and edit groceries on one device and observe them on the other.
3. Open an edit on both devices. Save one; confirm the stale save is rejected.
4. Purchase one grocery, choosing a location and date. Verify exactly one pantry
   item appears and the grocery is purchased on both devices, including when
   both members attempt to purchase it.
5. Add missing recipe ingredients and confirm they appear in Groceries.
6. Confirm canceled actions make no changes, failed requests show errors, and
   deleting a purchased list entry leaves pantry inventory intact.
7. Switch households and tabs, restart the app, and check household isolation
   and persistence.

# Firebase backend contract

PantryPal uses Cloud Firestore in Firebase project `finalapp-cae16` (`us-central1`).
The source of truth for access control is [`../firestore.rules`](../firestore.rules).

## Data layout

```
users/{uid}
inviteCodes/{inviteCode}
households/{householdId}
  members/{uid}
  groceryItems/{itemId}
  pantryItems/{itemId}
  storageLocations/{locationId}
  favoriteStores/{storeId}
```

Households are the security boundary. Every nested collection is readable and
writable only by a user whose `members/{uid}` document exists. An owner creates
the household, their member document, and its invite-code document in one batch.
Invite codes are retrievable only by exact document ID and cannot be listed.

## Integration for Flutter roles

Use `HouseholdRepository` in `lib/backend/household_repository.dart`; do not add
new top-level per-feature collections. It exposes creation/joining plus streams
and writes for grocery and pantry data. Role 2 owns grocery-list UI, Role 3
owns pantry UI, and both should receive an active `householdId` from Role 1's
membership flow.

## Before running the app

1. Register the final Android application ID in Firebase.
2. Run `flutterfire configure` from the repository root to generate
   `lib/firebase_options.dart` and connect the Android app.
3. Initialize Firebase in `main.dart` using `DefaultFirebaseOptions`.
4. Deploy the source-controlled rules with `firebase deploy --only firestore`.

Do not enable test mode or commit credentials, signing keys, or service-account
files. Production rules deny all client access until the membership conditions
are met.

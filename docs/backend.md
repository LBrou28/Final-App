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
and writes for grocery, pantry, and favorite-store data. Role 2 owns
grocery-list UI, Role 3 owns pantry UI, and both should receive an active
`householdId` from Role 1's membership flow.

`StoreRecommendationService` deterministically chooses a household favorite
first, then the closest saved store when a location is available. Its companion
`StoreRecommendationCard` exposes a maps-directions handoff and always shows a
clear reason without making claims about prices or inventory.

## Android configuration

The Android app is registered as `com.lbrou28.pantrypal`. FlutterFire generated
`lib/firebase_options.dart` and `android/app/google-services.json`, and app
startup initializes Firebase with `DefaultFirebaseOptions.currentPlatform`.

When adding another platform, re-run `flutterfire configure` from the
repository root and commit the generated configuration changes.

Do not enable test mode or commit credentials, signing keys, or service-account
files. Production rules deny all client access until the membership conditions
are met.

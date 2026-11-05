# PantryPal

A Flutter Android app that helps roommates manage groceries, track pantry items, and choose where to shop.

> Status: Feature development. Groceries, Pantry, Use Soon, and Recipes now use household-scoped Firebase repositories. Account flow, backend deployment, live integration testing, and release validation remain. See [grocery handoff](docs/role-2.md) and [pantry/recipe handoff](docs/role-3.md).

## Project overview

Household members join with an invite code and share a grocery list and pantry inventory. PantryPal helps prevent duplicate purchases and makes food approaching its entered expiration date easier to find.

## Planned first release

- **Households:** Create a household, join using an invite code, and view members.
- **Shared grocery list:** Add items and quantities, see who added them, and mark purchases.
- **Pantry inventory:** Move purchases into the fridge, freezer, or cupboard; update quantities and mark items used up.
- **Use Soon:** Sort items by optional, user-entered expiration dates. Dates are organizational reminders, not food-safety guarantees.
- **Store suggestions:** Save household favorite stores, suggest nearby options using distance and preferences, and open directions. Live prices and stock availability are outside the initial scope.

Example: A roommate adds milk, another buys it and moves it into the fridge inventory, and everyone can see the household already has milk.

## Technology and architecture

- **Mobile app:** Flutter and Dart, targeting Android first.
- **Server component:** Firebase Authentication and Cloud Firestore. Firestore is configured for the `finalapp-cae16` project in `us-central1`; source-controlled rules live in `firestore.rules`.
- **Automation:** GitHub Actions for formatting, static analysis, tests, and an Android debug APK.
- **Distribution:** Google Play release planned; signing and store publishing will be configured separately.

Household data must be restricted to authorized members. Do not commit passwords, API secrets, signing keys, or service-account credentials.

## Local development

Install Flutter 3.47.7 (matching CI), Android SDK, and Android Studio or another Flutter-compatible editor. Run `flutter doctor` to check your environment.

The Flutter project lives at the repository root. Run the app on an Android emulator or connected phone:

```sh
flutter pub get
flutter run
```

Before pushing changes:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Automated workflow

[`Flutter Android CI`](../../actions) runs on pushes, pull requests, and manual dispatch.

It installs Flutter 3.47.7 and Java 17, resolves dependencies, checks formatting, runs analysis and tests, and builds an Android debug APK. A successful build uploads a `pantrypal-debug-apk` artifact retained for 14 days.

The APK is for development and demos. This workflow does not sign a production release or publish to Google Play.

Flutter references: [Android builds](https://docs.flutter.dev/deployment/android) and [continuous delivery](https://docs.flutter.dev/deployment/cd).

## Initial task list

- [x] Initialize the Flutter Android counter demo.
- [x] Choose the final Android application ID: `com.lbrou28.pantrypal`.
- [x] Agree on backend technology and data model.
- [ ] Implement accounts and household invitations.
- [x] Implement shared grocery lists (live Firebase validation pending).
- [x] Implement purchase-to-pantry flow (live Firebase validation pending).
- [x] Implement pantry inventory editing and Use Soon screens (Firebase integration validation pending).
- [x] Implement recipe suggestions and missing-ingredient writes (catalog deployment and live validation pending).
- [x] Implement favorite-store persistence, recommendation logic, and directions handoff.
- [ ] Publish and validate household access controls on the server.
- [ ] Add meaningful tests and obtain a successful CI APK build.
- [ ] Test household syncing using two phones.
- [ ] Record the demo video and add its link here.
- [ ] Prepare release signing, privacy policy, and Google Play listing.
- [ ] Publish on Google Play and add its link here.

Track assigned work on [Trello](https://trello.com/b/oTiGCUaE/final-app).

## Proposed three-person work split

One member has left the group. Confirm the revised team size with the instructor;
the original assignment specifies four students. This split is a proposal, not a
record of new assignments accepted by teammates.

| Team member | Primary area |
| --- | --- |
| 1 | Accounts and household invitations |
| 2 | Grocery list and purchase flow |
| 3 | Pantry inventory, Use Soon, and recipes |

The member already handling Firebase should retain backend coordination. Divide
the departed member's remaining store UI and release work among the three members
after accounts and the shared grocery-to-pantry flow work on two devices.

All members contribute to integration, code review, testing, and release preparation. Backend tasks should be shared across the related features.

## Class deliverables

| Requirement | Planned evidence |
| --- | --- |
| Team requirement | Three remaining members; instructor approval of revised team size pending |
| Git repository | This repository and contribution history |
| Demo video | Two phones sharing a household and completing a shopping flow |
| Task list | GitHub Issues/project board and checklist above |
| Automated build | Passing GitHub Actions run with downloadable APK |
| Server component | Deployed backend syncing household data |
| Android store release | Google Play listing link |

**Demo video:** Pending  
**Google Play listing:** Pending  
**Team members:** To be added

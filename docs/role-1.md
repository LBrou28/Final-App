# Role 1: Accounts and households

Implemented email/password sign-in, account creation with password confirmation,
password-reset requests, sign-out, create/join household, household switching,
and an invite-code/member details dialog. Firebase Auth restores the Android
session after restart; the app never stores a password itself.

New households keep their invite code on the member-readable household document
so it can be shared again later. Older households still require the original
code from their creator. Members currently show as You or a shortened member ID;
profile display names are not implemented.

Joining validates and normalizes the code, then creates membership in a
transaction only if absent. Joining again preserves the existing owner/member
role. Rules now allow signed-in users to read only their own membership document
before joining, and owner-membership creation requires the caller's own ID.

## Firebase setup and live acceptance

1. Enable Authentication > Sign-in method > Email/Password in `finalapp-cae16`.
2. Deploy the checked-in Firestore rules and indexes. The new join transaction
   requires the updated own-membership get rule. Deployment is not performed by
   the Flutter build or tests.
3. Register on the first phone and create a household. Copy its displayed code.
4. Register a second account on a second phone and join using that code. Confirm
   both memberships are visible; joining again must not change the owner's role.
5. Restart the app and confirm the signed-in session returns. Sign out and check
   that household screens are no longer accessible. Check invalid credentials,
   reset email delivery, invalid invite codes, and access by a nonmember.
6. Complete the grocery/pantry acceptance checks in `role-2.md`. Sign in on both
   phones before recording the class video, and start recording on Groceries.

The four account/household widget tests cover input validation, duplicate-submit
prevention, failed requests, password confirmation/reset, and invite feedback.
They do not claim live authentication, email delivery, or deployed rules coverage.

Reference: https://firebase.google.com/docs/auth/flutter/start

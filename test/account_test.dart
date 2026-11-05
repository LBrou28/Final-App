import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/features/account/sign_in_page.dart';
import 'package:pantrypal/features/account/household_dialog.dart';

void main() {
  testWidgets(
    'sign-in validates, preserves failed input, and prevents duplicate requests',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignInPage(
              authenticate: (email, password, create) async {
                calls++;
                expect(email, 'roommate@example.com');
                expect(password, 'password123');
                expect(create, false);
                await pending.future;
                throw FirebaseAuthException(code: 'invalid-credential');
              },
              resetPassword: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(calls, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'roommate@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.text('roommate@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'registration requires matching passwords; reset does not require a password',
    (tester) async {
      var created = false;
      var resets = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignInPage(
              authenticate: (email, password, create) async {
                created = create;
              },
              resetPassword: (_) async {
                resets++;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'roommate@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.enterText(find.byType(TextFormField).at(2), 'different');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(created, false);
      expect(find.text('Passwords must match.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(created, true);
      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'roommate@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(resets, 1);
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );

  testWidgets(
    'create household retains failed name, then displays shareable invite',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HouseholdDialog(
              create: true,
              submit: (name) async {
                expect(name, 'Our kitchen');
                if (++calls == 1) throw Exception('offline');
                return 'ABCDEFGH23';
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(calls, 0);
      await tester.enterText(find.byType(TextFormField), 'Our kitchen');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Our kitchen'), findsOneWidget);
      expect(find.textContaining('Could not create'), findsOneWidget);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Household created'), findsOneWidget);
      expect(find.text('ABCDEFGH23'), findsOneWidget);
    },
  );

  testWidgets(
    'join validates invite before submitting and displays invalid-code feedback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HouseholdDialog(
              create: false,
              submit: (code) async {
                calls++;
                throw ArgumentError('That invite code is not valid.');
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'bad/code');
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(calls, 0);
      await tester.enterText(find.byType(TextFormField), 'abcdefgh23');
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('That invite code is not valid.'), findsOneWidget);
      expect(find.text('abcdefgh23'), findsOneWidget);
    },
  );
}

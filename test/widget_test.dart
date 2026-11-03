// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantrypal/main.dart';

void main() {
  testWidgets('adds an item to the grocery list', (tester) async {
    await tester.pumpWidget(const PantryPalApp());

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Item name'), 'Milk');
    await tester.enterText(find.bySemanticsLabel('Quantity'), '2');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Quantity: 2'), findsOneWidget);
  });

  testWidgets('moves a purchased item into the pantry', (tester) async {
    await tester.pumpWidget(const PantryPalApp());

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Item name'), 'Milk');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Move Milk to pantry?'), findsOneWidget);

    await tester.tap(find.text('Move item'));
    await tester.pumpAndSettle();

    expect(
      find.text('Quantity: 1 • Fridge • No expiration date'),
      findsOneWidget,
    );
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/models.dart';
import 'package:pantrypal/backend/pantry_data_source.dart';
import 'package:pantrypal/features/pantry/pantry_page.dart';

class FakePantry implements PantryDataSource {
  final controller = StreamController<List<PantryItem>>.broadcast();
  bool fail = false;
  num? savedQuantity;
  String? removed;
  DateTime? savedDate;
  @override
  Stream<List<PantryItem>> watchPantryItems(String householdId) =>
      controller.stream;
  @override
  Future<void> updatePantryItem({
    required String householdId,
    required String itemId,
    required num quantity,
    required String storageLocationId,
    DateTime? expiresOn,
  }) async {
    if (fail) throw StateError('offline');
    savedQuantity = quantity;
    savedDate = expiresOn;
  }

  @override
  Future<void> useUpPantryItem({
    required String householdId,
    required String itemId,
  }) async {
    if (fail) throw StateError('offline');
    removed = itemId;
  }
}

void main() {
  late FakePantry source;
  setUp(() => source = FakePantry());
  tearDown(() => source.controller.close());
  const milk = PantryItem(
    id: 'milk',
    name: 'Milk',
    quantity: 2,
    storageLocationId: 'fridge',
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantryPage(householdId: 'home', source: source),
      ),
    );
  }

  testWidgets('shows loading, useful empty state, and request errors', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.controller.add([]);
    await tester.pump();
    expect(find.textContaining('Your pantry is empty'), findsOneWidget);
    source.controller.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'validates edits and keeps input after failed save, then retries',
    (tester) async {
      await open(tester);
      source.controller.add([milk]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '-2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number greater than zero.'), findsOneWidget);
      expect(source.savedQuantity, isNull);
      await tester.enterText(find.byType(TextFormField), '0.5');
      source.fail = true;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your input is kept'), findsOneWidget);
      source.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(source.savedQuantity, 0.5);
      expect(find.text('Edit Milk'), findsNothing);
    },
  );

  testWidgets(
    'used up requires confirmation and preserves the item on failure',
    (tester) async {
      await open(tester);
      source.controller.add([milk]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Used up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(source.removed, isNull);
      source.fail = true;
      await tester.tap(find.text('Used up'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Used up'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      expect(find.textContaining('Could not remove'), findsOneWidget);
      source.fail = false;
      await tester.tap(find.text('Used up'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Used up'));
      await tester.pumpAndSettle();
      expect(source.removed, 'milk');
    },
  );
}

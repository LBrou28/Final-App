import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/grocery_data_source.dart';
import 'package:pantrypal/backend/models.dart';
import 'package:pantrypal/features/grocery/grocery_list_page.dart';

GroceryItem milk({num quantity = 1, bool purchased = false}) => GroceryItem(
  id: 'milk',
  name: 'Milk',
  quantity: quantity,
  createdBy: 'roommate',
  isPurchased: purchased,
);

class FakeGroceries implements GroceryDataSource {
  final changes = StreamController<List<GroceryItem>>.broadcast();
  List<GroceryItem> items = [];
  String? household;
  String? location;
  DateTime? expiresOn;
  bool fail = false;
  bool conflict = false;
  Completer<void>? pending;
  int writes = 0;
  @override
  String get currentUserId => 'me';
  @override
  Stream<List<GroceryItem>> watchGroceryItems(String householdId) {
    household = householdId;
    return changes.stream;
  }

  void emit(List<GroceryItem> values) {
    items = values;
    changes.add(values);
  }

  Future<void> beforeWrite() async {
    writes++;
    if (pending != null) await pending!.future;
    if (conflict) throw const GroceryConflict();
    if (fail) throw Exception('offline');
  }

  @override
  Future<void> addGroceryItem({
    required String householdId,
    required String name,
    required num quantity,
  }) async {
    await beforeWrite();
    household = householdId;
    emit([
      ...items,
      GroceryItem(
        id: 'new',
        name: name,
        quantity: quantity,
        createdBy: currentUserId,
        isPurchased: false,
      ),
    ]);
  }

  @override
  Future<void> updateGroceryItem({
    required String householdId,
    required GroceryItem expected,
    required String name,
    required num quantity,
  }) async {
    await beforeWrite();
    emit(
      items
          .map(
            (i) => i.id == expected.id
                ? GroceryItem(
                    id: i.id,
                    name: name,
                    quantity: quantity,
                    createdBy: i.createdBy,
                    isPurchased: false,
                  )
                : i,
          )
          .toList(),
    );
  }

  @override
  Future<void> deleteGroceryItem({
    required String householdId,
    required GroceryItem expected,
  }) async {
    await beforeWrite();
    emit(items.where((i) => i.id != expected.id).toList());
  }

  @override
  Future<void> purchaseToPantry({
    required String householdId,
    required String groceryItemId,
    required String storageLocationId,
    DateTime? expiresOn,
  }) async {
    await beforeWrite();
    household = householdId;
    location = storageLocationId;
    this.expiresOn = expiresOn;
    emit([milk(purchased: true)]);
  }
}

Future<FakeGroceries> openPage(
  WidgetTester tester, [
  List<GroceryItem> items = const [],
]) async {
  final source = FakeGroceries();
  addTearDown(source.changes.close);
  await tester.pumpWidget(
    MaterialApp(
      home: GroceryListPage(householdId: 'home-a', source: source),
    ),
  );
  source.emit(items);
  await tester.pumpAndSettle();
  return source;
}

Future<void> openMenu(WidgetTester tester, String action) async {
  await tester.tap(find.byTooltip('Options for Milk'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('live list displays recipe additions and roommate changes', (
    tester,
  ) async {
    final source = await openPage(tester);
    expect(find.textContaining('empty'), findsOneWidget);
    source.emit([milk(quantity: 2)]);
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(
      find.textContaining('Quantity: 2 • Added by household member'),
      findsOneWidget,
    );
    expect(source.household, 'home-a');
    source.emit([]);
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
  });

  testWidgets('validates input, keeps failed draft, and retries a saved item', (
    tester,
  ) async {
    final source = await openPage(tester);
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Item name'), ' Milk ');
    await tester.enterText(find.bySemanticsLabel('Quantity'), 'NaN');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(source.writes, 0);
    expect(find.text('Enter a number greater than zero.'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Quantity'), '1.5');
    source.fail = true;
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text(' Milk '), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(source.items.single.name, 'Milk');
    expect(source.items.single.quantity, 1.5);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'cancel purchase makes no write; pending save prevents duplicate taps',
    (tester) async {
      final source = await openPage(tester, [milk()]);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(source.writes, 0);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Freezer').last);
      await tester.pumpAndSettle();
      source.pending = Completer<void>();
      await tester.tap(find.text('Move item'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(source.writes, 1);
      source.pending!.complete();
      await tester.pumpAndSettle();
      expect(source.location, 'freezer');
      expect(source.household, 'home-a');
      expect(source.expiresOn, isNull);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    },
  );

  testWidgets('failed purchase preserves selected location and can retry', (
    tester,
  ) async {
    final source = await openPage(tester, [milk()]);
    source.fail = true;
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move item'));
    await tester.pumpAndSettle();
    expect(source.items.single.isPurchased, isFalse);
    expect(find.textContaining('Could not save'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('Move item'));
    await tester.pumpAndSettle();
    expect(source.items.single.isPurchased, isTrue);
  });

  testWidgets(
    'edits quantity and reports a concurrent update without closing draft',
    (tester) async {
      final source = await openPage(tester, [milk()]);
      await openMenu(tester, 'Edit');
      await tester.enterText(find.bySemanticsLabel('Quantity'), '3');
      source.conflict = true;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This item changed'), findsOneWidget);
      expect(source.items.single.quantity, 1);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      source.conflict = false;
      await openMenu(tester, 'Edit');
      await tester.enterText(find.bySemanticsLabel('Quantity'), '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(source.items.single.quantity, 3);
    },
  );

  testWidgets('requires deletion confirmation and retains item on failure', (
    tester,
  ) async {
    final source = await openPage(tester, [milk()]);
    await openMenu(tester, 'Delete');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(source.writes, 0);
    await openMenu(tester, 'Delete');
    source.fail = true;
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(source.items, hasLength(1));
    expect(find.textContaining('Could not save'), findsOneWidget);
    source.fail = false;
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(source.items, isEmpty);
  });

  testWidgets('stream errors offer retry and recover', (tester) async {
    final source = await openPage(tester);
    source.changes.addError(Exception('denied'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load groceries.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    source.emit([milk()]);
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
  });
}

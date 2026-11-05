import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'grocery_data_source.dart';
import 'pantry_data_source.dart';

/// The single entry point for household-scoped data.
///
/// All collection paths live here so Roles 1–3 can share data without adding
/// unguarded top-level collections or duplicating Firestore path logic.
class HouseholdRepository implements PantryDataSource, GroceryDataSource {
  HouseholdRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Random _random = Random.secure();

  @override
  String get currentUserId => _uid;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('A signed-in user is required.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _households() =>
      _firestore.collection('households');

  DocumentReference<Map<String, dynamic>> _household(String householdId) =>
      _households().doc(householdId);

  CollectionReference<Map<String, dynamic>> _members(String householdId) =>
      _household(householdId).collection('members');

  CollectionReference<Map<String, dynamic>> _groceryItems(String householdId) =>
      _household(householdId).collection('groceryItems');

  CollectionReference<Map<String, dynamic>> _pantryItems(String householdId) =>
      _household(householdId).collection('pantryItems');

  CollectionReference<Map<String, dynamic>> _favoriteStores(
    String householdId,
  ) => _household(householdId).collection('favoriteStores');

  /// Creates the household, owner membership, and non-enumerable invite in a
  /// single atomic batch. Keep the invite code long enough to resist guessing.
  Future<String> createHousehold({required String name}) async {
    final household = _households().doc();
    final inviteCode = _newInviteCode();
    final batch = _firestore.batch();

    batch.set(household, {
      'name': name.trim(),
      'ownerId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_members(household.id).doc(_uid), {
      'userId': _uid,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('inviteCodes').doc(inviteCode), {
      'householdId': household.id,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return inviteCode;
  }

  /// Joins only when the exact, non-listable invite-code document exists.
  Future<String> joinHousehold({required String inviteCode}) async {
    final normalizedCode = inviteCode.trim().toUpperCase();
    final invite = await _firestore
        .collection('inviteCodes')
        .doc(normalizedCode)
        .get();
    if (!invite.exists) throw StateError('That invite code is not valid.');

    final householdId = invite.data()!['householdId'] as String;
    await _members(householdId).doc(_uid).set({
      'userId': _uid,
      'role': 'member',
      'inviteCode': normalizedCode,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return householdId;
  }

  Stream<List<Household>> watchHouseholdsForCurrentUser() => _firestore
      .collectionGroup('members')
      .where('userId', isEqualTo: _uid)
      .snapshots()
      .asyncMap((members) async {
        final households = await Future.wait(
          members.docs.map(
            (member) => _household(member.reference.parent.parent!.id).get(),
          ),
        );
        return households
            .where((household) => household.exists)
            .map(Household.fromDocument)
            .toList();
      });

  @override
  Stream<List<GroceryItem>> watchGroceryItems(String householdId) =>
      _groceryItems(householdId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(GroceryItem.fromDocument).toList(),
          );

  @override
  Future<void> addGroceryItem({
    required String householdId,
    required String name,
    required num quantity,
  }) async {
    validateGroceryInput(name, quantity);
    await _groceryItems(householdId).add({
      'name': name.trim(),
      'quantity': quantity,
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'isPurchased': false,
    });
  }

  @override
  Future<void> updateGroceryItem({
    required String householdId,
    required GroceryItem expected,
    required String name,
    required num quantity,
  }) async {
    validateGroceryInput(name, quantity);
    final ref = _groceryItems(householdId).doc(expected.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      checkGroceryUnchanged(
        expected,
        snapshot.exists ? GroceryItem.fromDocument(snapshot) : null,
      );
      if (expected.isPurchased) throw const GroceryConflict();
      transaction.update(ref, {'name': name.trim(), 'quantity': quantity});
    });
  }

  @override
  Future<void> deleteGroceryItem({
    required String householdId,
    required GroceryItem expected,
  }) async {
    final ref = _groceryItems(householdId).doc(expected.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      checkGroceryUnchanged(
        expected,
        snapshot.exists ? GroceryItem.fromDocument(snapshot) : null,
      );
      transaction.delete(ref);
    });
  }

  /// Marks an item purchased without creating pantry inventory.
  ///
  /// Prefer [purchaseToPantry] for the normal purchase flow so both writes are
  /// committed together.
  Future<void> markGroceryItemPurchased({
    required String householdId,
    required String itemId,
  }) => _groceryItems(householdId).doc(itemId).update({
    'isPurchased': true,
    'purchasedBy': _uid,
    'purchasedAt': FieldValue.serverTimestamp(),
  });

  @override
  Stream<List<PantryItem>> watchPantryItems(String householdId) =>
      _pantryItems(householdId).snapshots().map(
        (snapshot) => snapshot.docs.map(PantryItem.fromDocument).toList(),
      );

  @override
  Future<void> updatePantryItem({
    required String householdId,
    required String itemId,
    required num quantity,
    required String storageLocationId,
    DateTime? expiresOn,
  }) {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError(
        'Quantity must be a finite number greater than zero.',
      );
    }
    if (storageLocationId.trim().isEmpty) {
      throw ArgumentError('A storage location is required.');
    }
    return _pantryItems(householdId).doc(itemId).update({
      'quantity': quantity,
      'storageLocationId': storageLocationId,
      'expiresOn': expiresOn == null ? null : Timestamp.fromDate(expiresOn),
      'updatedBy': _uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> useUpPantryItem({
    required String householdId,
    required String itemId,
  }) => _pantryItems(householdId).doc(itemId).delete();

  Future<void> addPantryItem({
    required String householdId,
    required String name,
    required num quantity,
    required String storageLocationId,
    DateTime? expiresOn,
  }) => _pantryItems(householdId).add({
    'name': name.trim(),
    'quantity': quantity,
    'storageLocationId': storageLocationId,
    'expiresOn': expiresOn == null ? null : Timestamp.fromDate(expiresOn),
    'createdBy': _uid,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedBy': _uid,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Atomically converts one unpurchased grocery item into pantry inventory.
  /// If either write cannot be authorized, neither change is committed.
  @override
  Future<void> purchaseToPantry({
    required String householdId,
    required String groceryItemId,
    required String storageLocationId,
    DateTime? expiresOn,
  }) async {
    if (!['fridge', 'freezer', 'cupboard'].contains(storageLocationId)) {
      throw ArgumentError('Choose Fridge, Freezer, or Cupboard.');
    }
    final grocery = _groceryItems(householdId).doc(groceryItemId);
    final pantry = _pantryItems(householdId).doc();

    await _firestore.runTransaction((transaction) async {
      final grocerySnapshot = await transaction.get(grocery);
      if (!grocerySnapshot.exists) {
        throw StateError('The grocery item no longer exists.');
      }
      final data = grocerySnapshot.data()!;
      validateGroceryInput(data['name'] as String, data['quantity'] as num);
      if (data['isPurchased'] == true) {
        throw StateError('The grocery item has already been purchased.');
      }

      final now = FieldValue.serverTimestamp();
      transaction.update(grocery, {
        'isPurchased': true,
        'purchasedBy': _uid,
        'purchasedAt': now,
      });
      transaction.set(pantry, {
        'name': data['name'] as String,
        'quantity': data['quantity'] as num,
        'storageLocationId': storageLocationId,
        'expiresOn': expiresOn == null ? null : Timestamp.fromDate(expiresOn),
        'groceryItemId': groceryItemId,
        'createdBy': _uid,
        'createdAt': now,
        'updatedBy': _uid,
        'updatedAt': now,
      });
    });
  }

  Stream<List<FavoriteStore>> watchFavoriteStores(String householdId) =>
      _favoriteStores(householdId)
          .orderBy('name')
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs.map(FavoriteStore.fromDocument).toList(),
          );

  Future<void> saveFavoriteStore({
    required String householdId,
    required String name,
    required String address,
    required bool isHouseholdFavorite,
    double? latitude,
    double? longitude,
  }) {
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError('Latitude and longitude must be supplied together.');
    }
    return _favoriteStores(householdId).add({
      'name': name.trim(),
      'address': address.trim(),
      'isHouseholdFavorite': isHouseholdFavorite,
      'location': latitude == null ? null : GeoPoint(latitude, longitude!),
      'createdBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFavoriteStore({
    required String householdId,
    required String storeId,
  }) => _favoriteStores(householdId).doc(storeId).delete();

  String _newInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      10,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}

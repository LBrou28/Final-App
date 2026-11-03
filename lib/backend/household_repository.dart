import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

/// The single entry point for household-scoped data.
///
/// All collection paths live here so Roles 1–3 can share data without adding
/// unguarded top-level collections or duplicating Firestore path logic.
class HouseholdRepository {
  HouseholdRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Random _random = Random.secure();

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

  Stream<List<GroceryItem>> watchGroceryItems(String householdId) =>
      _groceryItems(householdId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(GroceryItem.fromDocument).toList(),
          );

  Future<void> addGroceryItem({
    required String householdId,
    required String name,
    required num quantity,
  }) => _groceryItems(householdId).add({
    'name': name.trim(),
    'quantity': quantity,
    'createdBy': _uid,
    'createdAt': FieldValue.serverTimestamp(),
    'isPurchased': false,
  });

  Future<void> markGroceryItemPurchased({
    required String householdId,
    required String itemId,
  }) => _groceryItems(householdId).doc(itemId).update({
    'isPurchased': true,
    'purchasedBy': _uid,
    'purchasedAt': FieldValue.serverTimestamp(),
  });

  Stream<List<PantryItem>> watchPantryItems(String householdId) =>
      _pantryItems(householdId)
          .orderBy('expiresOn')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map(PantryItem.fromDocument).toList(),
          );

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
    'createdAt': FieldValue.serverTimestamp(),
    'updatedBy': _uid,
  });

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

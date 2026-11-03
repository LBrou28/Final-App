import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collections are intentionally household-scoped. UI features must
/// receive a household ID from the active membership rather than construct one.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime? createdAt;

  factory Household.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Household(
      id: doc.id,
      name: data['name'] as String,
      ownerId: data['ownerId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String role;
  final DateTime? joinedAt;

  factory HouseholdMember.fromMap(Map<String, dynamic> data) => HouseholdMember(
        userId: data['userId'] as String,
        role: data['role'] as String,
        joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      );
}

class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.createdBy,
    required this.isPurchased,
  });

  final String id;
  final String name;
  final num quantity;
  final String createdBy;
  final bool isPurchased;

  factory GroceryItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroceryItem(
      id: doc.id,
      name: data['name'] as String,
      quantity: data['quantity'] as num,
      createdBy: data['createdBy'] as String,
      isPurchased: data['isPurchased'] as bool? ?? false,
    );
  }
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.storageLocationId,
    this.expiresOn,
  });

  final String id;
  final String name;
  final num quantity;
  final String storageLocationId;
  final DateTime? expiresOn;

  factory PantryItem.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return PantryItem(
      id: doc.id,
      name: data['name'] as String,
      quantity: data['quantity'] as num,
      storageLocationId: data['storageLocationId'] as String,
      expiresOn: (data['expiresOn'] as Timestamp?)?.toDate(),
    );
  }
}

class FavoriteStore {
  const FavoriteStore({
    required this.id,
    required this.name,
    required this.address,
    required this.isHouseholdFavorite,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String address;
  final bool isHouseholdFavorite;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory FavoriteStore.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final location = data['location'] as GeoPoint?;
    return FavoriteStore(
      id: doc.id,
      name: data['name'] as String,
      address: data['address'] as String? ?? '',
      isHouseholdFavorite: data['isHouseholdFavorite'] as bool? ?? false,
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
  }
}

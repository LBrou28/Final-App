import 'dart:math' as math;

import 'models.dart';

class StoreRecommendation {
  const StoreRecommendation({
    required this.store,
    required this.reason,
    required this.directionsUri,
    this.distanceKilometers,
  });

  final FavoriteStore store;
  final String reason;
  final Uri directionsUri;
  final double? distanceKilometers;
}

/// Chooses a household favorite first, then uses distance as a tie-breaker.
/// Without a device location, it still returns a transparent saved-store reason.
class StoreRecommendationService {
  const StoreRecommendationService();

  StoreRecommendation? recommend({
    required Iterable<FavoriteStore> stores,
    double? userLatitude,
    double? userLongitude,
  }) {
    final allStores = List<FavoriteStore>.from(stores);
    if (allStores.isEmpty) return null;

    final favorites = allStores.where((store) => store.isHouseholdFavorite).toList();
    final candidates = favorites.isNotEmpty ? favorites : allStores;
    final hasUserLocation = userLatitude != null && userLongitude != null;
    final withLocation = candidates.where((store) => store.hasLocation).toList();

    FavoriteStore selected;
    double? distanceKilometers;
    if (hasUserLocation && withLocation.isNotEmpty) {
      selected = withLocation.reduce((closest, candidate) {
        final closestDistance = _distanceKilometers(
          userLatitude,
          userLongitude,
          closest.latitude!,
          closest.longitude!,
        );
        final candidateDistance = _distanceKilometers(
          userLatitude,
          userLongitude,
          candidate.latitude!,
          candidate.longitude!,
        );
        return candidateDistance < closestDistance ? candidate : closest;
      });
      distanceKilometers = _distanceKilometers(
        userLatitude,
        userLongitude,
        selected.latitude!,
        selected.longitude!,
      );
    } else {
      selected = candidates.first;
    }

    final reason = selected.isHouseholdFavorite
        ? 'Household favorite'
        : distanceKilometers == null
            ? 'Saved store'
            : 'Closest saved store';
    return StoreRecommendation(
      store: selected,
      reason: reason,
      distanceKilometers: distanceKilometers,
      directionsUri: _directionsUri(selected),
    );
  }

  Uri _directionsUri(FavoriteStore store) {
    final destination = store.hasLocation
        ? '${store.latitude},${store.longitude}'
        : '${store.name} ${store.address}'.trim();
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
  }

  double _distanceKilometers(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    const earthRadiusKilometers = 6371.0;
    final latitudeDelta = _radians(toLatitude - fromLatitude);
    final longitudeDelta = _radians(toLongitude - fromLongitude);
    final haversine = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_radians(fromLatitude)) *
            math.cos(_radians(toLatitude)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusKilometers * 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pantrypal/backend/models.dart';
import 'package:pantrypal/backend/store_recommendation_service.dart';

void main() {
  const service = StoreRecommendationService();

  test('prioritizes a household favorite and explains why', () {
    final recommendation = service.recommend(
      stores: const [
        FavoriteStore(
          id: 'closest',
          name: 'Closest Market',
          address: '1 Main St',
          isHouseholdFavorite: false,
          latitude: 41.0,
          longitude: -87.0,
        ),
        FavoriteStore(
          id: 'favorite',
          name: 'Favorite Market',
          address: '2 Main St',
          isHouseholdFavorite: true,
          latitude: 42.0,
          longitude: -88.0,
        ),
      ],
      userLatitude: 41.0,
      userLongitude: -87.0,
    );

    expect(recommendation!.store.id, 'favorite');
    expect(recommendation.reason, 'Household favorite');
    expect(recommendation.directionsUri.queryParameters['api'], '1');
  });

  test('uses nearest saved store when there is no favorite', () {
    final recommendation = service.recommend(
      stores: const [
        FavoriteStore(
          id: 'far',
          name: 'Far Market',
          address: '',
          isHouseholdFavorite: false,
          latitude: 42.0,
          longitude: -88.0,
        ),
        FavoriteStore(
          id: 'near',
          name: 'Near Market',
          address: '',
          isHouseholdFavorite: false,
          latitude: 41.01,
          longitude: -87.01,
        ),
      ],
      userLatitude: 41.0,
      userLongitude: -87.0,
    );

    expect(recommendation!.store.id, 'near');
    expect(recommendation.reason, 'Closest saved store');
  });
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/store_recommendation_service.dart';

/// Drop this into the household dashboard after Role 1 supplies the active
/// household and Role 4's repository supplies its saved stores.
class StoreRecommendationCard extends StatelessWidget {
  const StoreRecommendationCard({super.key, required this.recommendation});

  final StoreRecommendation? recommendation;

  @override
  Widget build(BuildContext context) {
    final item = recommendation;
    if (item == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.storefront_outlined),
          title: Text('No saved stores yet'),
          subtitle: Text(
            'Add a household favorite to receive a recommendation.',
          ),
        ),
      );
    }

    final distance = item.distanceKilometers == null
        ? null
        : '${item.distanceKilometers!.toStringAsFixed(1)} km away';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.storefront),
        title: Text(item.store.name),
        subtitle: Text(
          [
            item.reason,
            distance,
            item.store.address,
          ].whereType<String>().where((part) => part.isNotEmpty).join(' • '),
        ),
        trailing: IconButton(
          tooltip: 'Open directions',
          icon: const Icon(Icons.directions),
          onPressed: () => launchUrl(item.directionsUri),
        ),
      ),
    );
  }
}

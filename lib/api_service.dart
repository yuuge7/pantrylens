import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/error_reporter.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client;
  final http.Client? _client;
  static const hosts = [
    'world.openfoodfacts.org',
    'world.openproductsfacts.org',
  ];
  Future<Map<String, String?>> fetchProductByBarcode(String barcode) async {
    for (final host in hosts) {
      try {
        final uri = Uri.https(
          host,
          '/api/v2/product/${Uri.encodeComponent(barcode)}.json',
        );
        const headers = {'User-Agent': 'PantryLens/1.0 (Flutter app)'};
        final response = await (_client?.get(uri, headers: headers) ??
                http.get(uri, headers: headers))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) continue;
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['product'] is! Map) continue;
        final p = decoded['product'] as Map;
        String? str(Object? v) =>
            v is String && v.trim().isNotEmpty ? v.trim() : null;
        final categories =
            '${p['categories'] ?? ''} ${p['categories_tags'] ?? ''}'
                .toLowerCase();
        final category = switch (categories) {
          final s
              when s.contains('dair') ||
                  s.contains('milk') ||
                  s.contains('yogurt') =>
            'Dairy',
          final s when s.contains('vegetable') || s.contains('fruit') =>
            'Produce',
          final s when s.contains('meat') || s.contains('fish') =>
            'Meat & fish',
          final s when s.contains('beverage') || s.contains('drink') =>
            'Drinks',
          final s when s.contains('baby') => 'Baby',
          final s when s.contains('pet') => 'Pet',
          final s when s.contains('clean') => 'Cleaning',
          _ => 'Other',
        };
        final nutrients = p['nutriments'];
        final nutrition =
            nutrients is Map
                ? [
                  for (final (key, label) in [
                    ('energy-kcal_100g', 'kcal'),
                    ('fat_100g', 'g fat'),
                    ('carbohydrates_100g', 'g carbs'),
                    ('proteins_100g', 'g protein'),
                    ('salt_100g', 'g salt'),
                  ])
                    if (nutrients[key] is num) '${nutrients[key]} $label',
                ].join(' · ')
                : '';
        return {
          'product_name':
              str(p['product_name']) ??
              str(p['product_name_en']) ??
              str(p['generic_name']),
          'image_url': str(p['image_url']) ?? str(p['image_front_url']),
          'category': category,
          'ingredients': str(p['ingredients_text']) ?? '',
          'allergens':
              (p['allergens_tags'] is List
                  ? (p['allergens_tags'] as List)
                      .map((a) => '$a'.split(':').last)
                      .join(',')
                  : str(p['allergens'])) ??
              '',
          'nutrition': nutrition,
        };
      } catch (e, s) {
        await ErrorReporter.capture(e, s);
      }
    }
    return {'product_name': null, 'image_url': null};
  }
}

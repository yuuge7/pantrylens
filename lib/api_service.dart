import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService({http.Client? client}) : _client = client;

  static const Duration _requestTimeout = Duration(seconds: 12);
  final http.Client? _client;

  Future<Map<String, String?>> fetchProductByBarcode(String barcode) async {
    final encodedBarcode = Uri.encodeComponent(barcode);
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v0/product/$encodedBarcode.json',
    );

    try {
      const headers = {'User-Agent': 'PantryLens/1.0 (Flutter app)'};
      final request =
          _client?.get(uri, headers: headers) ??
          http.get(uri, headers: headers);
      final response = await request.timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _emptyProductData();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return _emptyProductData();

      final product = decoded['product'];
      if (product is! Map<String, dynamic>) return _emptyProductData();

      return {
        'product_name':
            _nonEmptyString(product['product_name']) ??
            _nonEmptyString(product['product_name_en']) ??
            _nonEmptyString(product['generic_name']),
        'image_url':
            _nonEmptyString(product['image_url']) ??
            _nonEmptyString(product['image_front_url']),
      };
    } on TimeoutException {
      return _emptyProductData();
    } on http.ClientException {
      return _emptyProductData();
    } on FormatException {
      return _emptyProductData();
    } catch (_) {
      // Network implementations can surface platform-specific I/O exceptions.
      // The caller can still save the barcode with a fallback product name.
      return _emptyProductData();
    }
  }

  String? _nonEmptyString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, String?> _emptyProductData() => {
    'product_name': null,
    'image_url': null,
  };
}

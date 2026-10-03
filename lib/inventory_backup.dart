import 'dart:convert';

import 'pantry_item.dart';

/// The JSON file format used to export and import the pantry inventory.
class InventoryBackup {
  InventoryBackup._();

  static const int formatVersion = 1;

  static String fileName([DateTime? now]) {
    final date = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    return 'pantrylens-inventory-$date.json';
  }

  static String encode(List<PantryItem> items, [DateTime? now]) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'PantryLens',
      'version': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'items': [for (final item in items) item.toMap()..remove('id')],
    });
  }

  /// Reads the items from an exported file.
  ///
  /// Entries that are incomplete are skipped, and a barcode listed twice
  /// keeps its last entry. Throws a [FormatException] when [source] is not an
  /// inventory export or holds no usable items.
  static List<PantryItem> decode(String source) {
    final decoded = jsonDecode(source);
    final entries = decoded is Map ? decoded['items'] : decoded;
    if (entries is! List) {
      throw const FormatException('Not a PantryLens inventory export.');
    }

    final byBarcode = <String, PantryItem>{};
    for (final entry in entries) {
      final item = _itemFrom(entry);
      if (item != null) byBarcode[item.barcode] = item;
    }
    if (byBarcode.isEmpty) {
      throw const FormatException('The export holds no pantry items.');
    }
    return byBarcode.values.toList();
  }

  static PantryItem? _itemFrom(Object? entry) {
    if (entry is! Map) return null;
    final barcode = entry['barcode'];
    final name = entry['name'];
    final quantity = entry['quantity'];
    final imageUrl = entry['imageUrl'];
    final expirationDate = entry['expirationDate'];
    if (barcode is! String ||
        barcode.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        quantity is! num ||
        quantity < 1 ||
        expirationDate is! String) {
      return null;
    }
    final date = DateTime.tryParse(expirationDate);
    if (date == null) return null;

    return PantryItem(
      barcode: barcode.trim(),
      name: name.trim(),
      // Only web addresses are ever loaded as photos.
      imageUrl:
          imageUrl is String && imageUrl.startsWith('http') ? imageUrl : null,
      quantity: quantity.toInt(),
      expirationDate: date,
    );
  }
}

import 'dart:convert';
import 'pantry_item.dart';

class InventoryBackup {
  InventoryBackup._();
  static const formatVersion = 2;
  static String fileName([DateTime? now]) =>
      'pantrylens-inventory-${(now ?? DateTime.now()).toIso8601String().substring(0, 10)}.json';
  static String encode(List<PantryItem> items, [DateTime? now]) =>
      const JsonEncoder.withIndent('  ').convert({
        'app': 'PantryLens',
        'version': formatVersion,
        'exportedAt': (now ?? DateTime.now()).toIso8601String(),
        'items': [for (final item in items) item.toMap()..remove('id')],
      });
  static List<PantryItem> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map &&
        decoded['version'] is num &&
        decoded['version'] > formatVersion) {
      throw const FormatException(
        'This backup needs a newer PantryLens version.',
      );
    }
    final entries = decoded is Map ? decoded['items'] : decoded;
    if (entries is! List)
      throw const FormatException('Not a PantryLens inventory export.');
    final batches = <String, PantryItem>{};
    for (final entry in entries) {
      try {
        if (entry is! Map) continue;
        final map = Map<String, Object?>.from(entry)..remove('id');
        final item = PantryItem.fromMap(map);
        item.validate();
        batches[item.batchKey] = item;
      } catch (_) {
        /* Legacy malformed entries are skipped; no partial DB writes. */
      }
    }
    if (batches.isEmpty && entries.isNotEmpty)
      throw const FormatException('The export holds no valid pantry batches.');
    return batches.values.toList();
  }
}

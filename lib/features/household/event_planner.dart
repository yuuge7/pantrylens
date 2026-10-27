import '../../pantry_item.dart';

num? convertAmount(num amount, String from, String to) {
  if (from == to) return amount;
  const factors = {'g': 1, 'kg': 1000, 'ml': 1, 'l': 1000};
  if (({'g', 'kg'}.contains(from) && {'g', 'kg'}.contains(to)) ||
      ({'ml', 'l'}.contains(from) && {'ml', 'l'}.contains(to))) {
    return amount * factors[from]! / factors[to]!;
  }
  return null;
}

List<Map<String, dynamic>> missingIngredients(
  List<Map<String, dynamic>> requirements,
  List<PantryItem> inventory,
  String homeId,
) {
  final required = <String, Map<String, dynamic>>{};
  for (final r in requirements) {
    final unit = r['unit'] as String;
    final family = switch (unit) {
      'g' || 'kg' => 'mass',
      'ml' || 'l' => 'volume',
      _ => unit,
    };
    final key = '${(r['name'] as String).trim().toLowerCase()}|$family';
    final old = required[key];
    required[key] = {
      ...old ?? r,
      'quantity':
          old == null
              ? r['quantity']
              : (old['quantity'] as num) +
                  convertAmount(
                    r['quantity'] as num,
                    unit,
                    old['unit'] as String,
                  )!,
    };
  }
  return [
    for (final r in required.values)
      ...(() {
        final available = inventory
            .where(
              (i) =>
                  i.homeId == homeId &&
                  i.name.trim().toLowerCase() ==
                      (r['name'] as String).trim().toLowerCase() &&
                  i.daysUntilExpiry() >= 0,
            )
            .fold<num>(
              0,
              (sum, i) =>
                  sum +
                  (convertAmount(i.quantity, i.unit, r['unit'] as String) ?? 0),
            );
        final deficit = (r['quantity'] as num) - available;
        return deficit > 0.000000001
            ? [
              {...r, 'quantity': deficit},
            ]
            : <Map<String, dynamic>>[];
      })(),
  ];
}

List<Map<String, dynamic>> parseRequirements(String source) {
  final result = <Map<String, dynamic>>[];
  for (final line in source.split('\n').where((l) => l.trim().isNotEmpty)) {
    final parts = line.split('|').map((s) => s.trim()).toList();
    if (parts.length != 3 ||
        parts[0].isEmpty ||
        !PantryItem.units.contains(parts[2]))
      throw const FormatException(
        'Use one ingredient per line: Name | amount | unit',
      );
    final amount = num.tryParse(parts[1].replaceAll(',', '.'));
    if (amount == null || !amount.isFinite || amount <= 0)
      throw const FormatException('Ingredient amounts must be above 0.');
    result.add({'name': parts[0], 'quantity': amount, 'unit': parts[2]});
  }
  return result;
}

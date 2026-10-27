import 'dart:convert';

/// A physical batch. Barcodes identify products; batch keys identify purchases.
class PantryItem {
  final int? id;
  final String batchId;
  final String barcode;
  final String name;
  final String? imageUrl;
  final num quantity;
  final String unit;
  final DateTime expirationDate;
  final String homeId;
  final String location;
  final String category;
  final List<String> tags;
  final DateTime? openedDate;
  final int? daysAfterOpening;
  final num minimumStock;

  /// Price per selected unit, in the household's currency.
  final num price;
  final String store;
  final String ingredients;
  final List<String> allergens;
  final String nutrition;

  static const units = ['pieces', 'g', 'kg', 'ml', 'l', 'bottle'];
  static const locations = [
    'Pantry',
    'Fridge',
    'Freezer',
    'Wine cellar',
    'Garage',
  ];
  static const categories = [
    'Other',
    'Dairy',
    'Produce',
    'Meat & fish',
    'Bakery',
    'Dry goods',
    'Drinks',
    'Baby',
    'Pet',
    'Cleaning',
  ];

  const PantryItem({
    this.id,
    this.batchId = '',
    required this.barcode,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.expirationDate,
    this.unit = 'pieces',
    this.homeId = 'main',
    this.location = 'Pantry',
    this.category = 'Other',
    this.tags = const [],
    this.openedDate,
    this.daysAfterOpening,
    this.minimumStock = 0,
    this.price = 0,
    this.store = '',
    this.ingredients = '',
    this.allergens = const [],
    this.nutrition = '',
  });

  String get batchKey =>
      batchId.isNotEmpty
          ? batchId
          : '$barcode|$homeId|$location|$unit|${expirationDate.toIso8601String()}';
  String get amountLabel => '${formatAmount(quantity)} $unit';
  num get value => quantity * price;
  DateTime get effectiveExpiry {
    if (openedDate == null || daysAfterOpening == null) return expirationDate;
    final openedExpiry = DateTime(
      openedDate!.year,
      openedDate!.month,
      openedDate!.day + daysAfterOpening!,
    );
    return openedExpiry.isBefore(expirationDate)
        ? openedExpiry
        : expirationDate;
  }

  PantryItem copyWith({
    int? id,
    String? batchId,
    String? barcode,
    String? name,
    String? imageUrl,
    num? quantity,
    String? unit,
    DateTime? expirationDate,
    String? homeId,
    String? location,
    String? category,
    List<String>? tags,
    DateTime? openedDate,
    int? daysAfterOpening,
    bool clearOpened = false,
    num? minimumStock,
    num? price,
    String? store,
    String? ingredients,
    List<String>? allergens,
    String? nutrition,
  }) => PantryItem(
    id: id ?? this.id,
    batchId: batchId ?? this.batchId,
    barcode: barcode ?? this.barcode,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    quantity: quantity ?? this.quantity,
    expirationDate: expirationDate ?? this.expirationDate,
    unit: unit ?? this.unit,
    homeId: homeId ?? this.homeId,
    location: location ?? this.location,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    openedDate: clearOpened ? null : openedDate ?? this.openedDate,
    daysAfterOpening:
        clearOpened ? null : daysAfterOpening ?? this.daysAfterOpening,
    minimumStock: minimumStock ?? this.minimumStock,
    price: price ?? this.price,
    store: store ?? this.store,
    ingredients: ingredients ?? this.ingredients,
    allergens: allergens ?? this.allergens,
    nutrition: nutrition ?? this.nutrition,
  );

  int daysUntilExpiry([DateTime? now]) {
    final today = now ?? DateTime.now();
    final end = effectiveExpiry;
    return DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  }

  void validate() {
    if (barcode.trim().isEmpty ||
        name.trim().isEmpty ||
        homeId.isEmpty ||
        !quantity.isFinite ||
        quantity <= 0 ||
        !price.isFinite ||
        price < 0 ||
        !minimumStock.isFinite ||
        minimumStock < 0 ||
        !units.contains(unit) ||
        (daysAfterOpening != null && daysAfterOpening! < 1)) {
      throw const FormatException(
        'Invalid batch. Check name, amount, unit and price.',
      );
    }
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'batchId': batchKey,
    'barcode': barcode,
    'name': name,
    'imageUrl': imageUrl,
    'quantity': quantity,
    'expirationDate': expirationDate.toIso8601String(),
    'unit': unit,
    'homeId': homeId,
    'location': location,
    'category': category,
    'tags': jsonEncode(tags),
    'openedDate': openedDate?.toIso8601String(),
    'daysAfterOpening': daysAfterOpening,
    'minimumStock': minimumStock,
    'price': price,
    'store': store,
    'ingredients': ingredients,
    'allergens': jsonEncode(allergens),
    'nutrition': nutrition,
  };

  factory PantryItem.fromMap(Map<String, Object?> m) => PantryItem(
    id: m['id'] as int?,
    batchId: m['batchId'] as String? ?? '',
    barcode: m['barcode'] as String,
    name: m['name'] as String,
    imageUrl: m['imageUrl'] as String?,
    quantity: m['quantity'] as num,
    expirationDate: DateTime.parse(m['expirationDate'] as String),
    unit: m['unit'] as String? ?? 'pieces',
    homeId: m['homeId'] as String? ?? 'main',
    location: m['location'] as String? ?? 'Pantry',
    category: m['category'] as String? ?? 'Other',
    tags: stringList(m['tags']),
    openedDate: DateTime.tryParse(m['openedDate'] as String? ?? ''),
    daysAfterOpening: m['daysAfterOpening'] as int?,
    minimumStock: m['minimumStock'] as num? ?? 0,
    price: m['price'] as num? ?? 0,
    store: m['store'] as String? ?? '',
    ingredients: m['ingredients'] as String? ?? '',
    allergens: stringList(m['allergens']),
    nutrition: m['nutrition'] as String? ?? '',
  );
}

String formatAmount(num n) =>
    n == n.roundToDouble()
        ? n.toInt().toString()
        : n
            .toStringAsFixed(3)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
List<String> stringList(Object? value) {
  if (value == null || value == '') return [];
  final decoded = value is String ? jsonDecode(value) : value;
  return (decoded as List).whereType<String>().toList();
}

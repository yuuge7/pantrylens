class ShoppingItem {
  final int? id;
  final String name;
  final String? barcode;
  final String? imageUrl;
  final num quantity;
  final String unit;
  final bool isChecked;
  final String homeId;
  final String aisle;
  final String store;
  final bool automatic;

  const ShoppingItem({
    this.id,
    required this.name,
    this.barcode,
    this.imageUrl,
    this.quantity = 1,
    this.isChecked = false,
    this.unit = 'pieces',
    this.homeId = 'main',
    this.aisle = 'Other',
    this.store = '',
    this.automatic = false,
  });

  ShoppingItem copyWith({
    String? name,
    num? quantity,
    bool? isChecked,
    String? aisle,
    String? store,
    String? unit,
    bool? automatic,
  }) => ShoppingItem(
    id: id,
    name: name ?? this.name,
    barcode: barcode,
    imageUrl: imageUrl,
    quantity: quantity ?? this.quantity,
    isChecked: isChecked ?? this.isChecked,
    unit: unit ?? this.unit,
    homeId: homeId,
    aisle: aisle ?? this.aisle,
    store: store ?? this.store,
    automatic: automatic ?? this.automatic,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'barcode': barcode,
    'imageUrl': imageUrl,
    'quantity': quantity,
    'isChecked': isChecked ? 1 : 0,
    'unit': unit,
    'homeId': homeId,
    'aisle': aisle,
    'store': store,
    'automatic': automatic ? 1 : 0,
  };

  factory ShoppingItem.fromMap(Map<String, Object?> m) => ShoppingItem(
    id: m['id'] as int?,
    name: m['name'] as String,
    barcode: m['barcode'] as String?,
    imageUrl: m['imageUrl'] as String?,
    quantity: m['quantity'] as num? ?? 1,
    isChecked: m['isChecked'] == 1,
    unit: m['unit'] as String? ?? 'pieces',
    homeId: m['homeId'] as String? ?? 'main',
    aisle: m['aisle'] as String? ?? 'Other',
    store: m['store'] as String? ?? '',
    automatic: m['automatic'] == 1,
  );
}

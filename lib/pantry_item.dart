class PantryItem {
  /// The database-assigned id. It is null until the item is inserted.
  final int? id;
  final String barcode;
  final String name;
  final String? imageUrl;
  final int quantity;
  final DateTime expirationDate;

  const PantryItem({
    this.id,
    required this.barcode,
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.expirationDate,
  });

  PantryItem copyWith({
    int? id,
    String? barcode,
    String? name,
    String? imageUrl,
    int? quantity,
    DateTime? expirationDate,
  }) {
    return PantryItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }

  /// Whole calendar days until [expirationDate]; negative once it has passed.
  int daysUntilExpiry([DateTime? now]) {
    final today = now ?? DateTime.now();
    final start = DateTime.utc(today.year, today.month, today.day);
    final end = DateTime.utc(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    return end.difference(start).inDays;
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'barcode': barcode,
      'name': name,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'expirationDate': expirationDate.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory PantryItem.fromMap(Map<String, Object?> map) {
    return PantryItem(
      id: map['id'] as int?,
      barcode: map['barcode'] as String,
      name: map['name'] as String,
      imageUrl: map['imageUrl'] as String?,
      quantity: map['quantity'] as int,
      expirationDate: DateTime.parse(map['expirationDate'] as String),
    );
  }
}

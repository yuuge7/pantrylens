class ShoppingItem {
  /// The database-assigned id. It is null until the item is inserted.
  final int? id;
  final String name;

  /// The barcode of the pantry item this entry came from, when known.
  final String? barcode;

  /// The photo of the pantry item this entry came from, when known.
  final String? imageUrl;

  /// How many units to buy.
  final int quantity;
  final bool isChecked;

  const ShoppingItem({
    this.id,
    required this.name,
    this.barcode,
    this.imageUrl,
    this.quantity = 1,
    this.isChecked = false,
  });

  ShoppingItem copyWith({String? name, int? quantity, bool? isChecked}) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      barcode: barcode,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'name': name,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'isChecked': isChecked ? 1 : 0,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      imageUrl: map['imageUrl'] as String?,
      quantity: map['quantity'] as int? ?? 1,
      isChecked: (map['isChecked'] as int? ?? 0) != 0,
    );
  }
}

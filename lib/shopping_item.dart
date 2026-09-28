class ShoppingItem {
  /// The database-assigned id. It is null until the item is inserted.
  final int? id;
  final String name;

  /// The barcode of the pantry item this entry came from, when known.
  final String? barcode;
  final bool isChecked;

  const ShoppingItem({
    this.id,
    required this.name,
    this.barcode,
    this.isChecked = false,
  });

  ShoppingItem copyWith({bool? isChecked}) {
    return ShoppingItem(
      id: id,
      name: name,
      barcode: barcode,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'name': name,
      'barcode': barcode,
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
      isChecked: (map['isChecked'] as int? ?? 0) != 0,
    );
  }
}

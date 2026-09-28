import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'database_helper.dart';
import 'pantry_item.dart';
import 'shopping_item.dart';

/// What happened when a barcode was scanned.
class ScanOutcome {
  const ScanOutcome({
    required this.item,
    required this.isNew,
    this.checkedOffShoppingList = false,
  });

  final PantryItem item;

  /// True when the barcode created a new pantry item rather than adding one.
  final bool isNew;

  /// True when the scan ticked a matching entry on the shopping list.
  final bool checkedOffShoppingList;
}

/// A pantry item that was removed, kept so the removal can be undone.
class RemovedItem {
  const RemovedItem({required this.item, this.shoppingItemId});

  final PantryItem item;

  /// The shopping list entry created for the item, if one was added.
  final int? shoppingItemId;
}

class PantryProvider extends ChangeNotifier {
  PantryProvider({DatabaseHelper? databaseHelper, ApiService? apiService})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
      _apiService = apiService ?? ApiService() {
    loadItems();
  }

  final DatabaseHelper _databaseHelper;
  final ApiService _apiService;
  final List<PantryItem> _items = [];
  final List<ShoppingItem> _shoppingItems = [];
  final Set<String> _barcodesBeingProcessed = {};

  bool _isLoading = true;
  String? _errorMessage;

  List<PantryItem> get items => List.unmodifiable(_items);
  List<ShoppingItem> get shoppingItems => List.unmodifiable(_shoppingItems);
  bool get isLoading => _isLoading;

  /// Set when the pantry could not be read from the database.
  String? get errorMessage => _errorMessage;

  int get totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);
  int get shoppingItemsToBuy =>
      _shoppingItems.where((item) => !item.isChecked).length;

  Future<void> loadItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reload();
    } catch (_) {
      _errorMessage =
          'Your pantry could not be loaded. Check storage and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reads both lists before replacing them, so overlapping reloads cannot
  /// interleave and duplicate entries.
  Future<void> _reload() async {
    final items = await _databaseHelper.getAllItems();
    final shoppingItems = await _databaseHelper.getShoppingItems();
    _items
      ..clear()
      ..addAll(items);
    _shoppingItems
      ..clear()
      ..addAll(shoppingItems);
  }

  /// Adds one unit for [barcode], creating the item on its first scan.
  ///
  /// Returns null when the barcode is empty or already being processed.
  Future<ScanOutcome?> onBarcodeScanned(
    String barcode, {
    int shelfLifeDays = 30,
    bool lookUpProduct = true,
  }) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty ||
        !_barcodesBeingProcessed.add(normalizedBarcode)) {
      return null;
    }

    try {
      final existingItem = await _databaseHelper.getItemByBarcode(
        normalizedBarcode,
      );

      final PantryItem savedItem;
      if (existingItem != null) {
        savedItem = existingItem.copyWith(quantity: existingItem.quantity + 1);
        await _databaseHelper.updateItem(savedItem);
      } else {
        final product =
            lookUpProduct
                ? await _apiService.fetchProductByBarcode(normalizedBarcode)
                : const <String, String?>{};
        final productName = product['product_name']?.trim();
        final today = DateTime.now();

        final item = PantryItem(
          barcode: normalizedBarcode,
          name:
              productName == null || productName.isEmpty
                  ? 'Unknown product ($normalizedBarcode)'
                  : productName,
          imageUrl: product['image_url'],
          quantity: 1,
          expirationDate: DateTime(
            today.year,
            today.month,
            today.day + shelfLifeDays,
          ),
        );
        final id = await _databaseHelper.insertItem(item);
        savedItem = item.copyWith(id: id);
      }

      var checkedOff = false;
      for (final entry in _shoppingItems) {
        if (!entry.isChecked && entry.barcode == normalizedBarcode) {
          await _databaseHelper.updateShoppingItem(
            entry.copyWith(isChecked: true),
          );
          checkedOff = true;
        }
      }

      await _reload();
      return ScanOutcome(
        item: savedItem,
        isNew: existingItem == null,
        checkedOffShoppingList: checkedOff,
      );
    } finally {
      _barcodesBeingProcessed.remove(normalizedBarcode);
      notifyListeners();
    }
  }

  Future<void> updateItem(PantryItem item) async {
    final index = _items.indexWhere((existing) => existing.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
    }
    try {
      await _databaseHelper.updateItem(item);
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> changeQuantity(PantryItem item, int delta) {
    final quantity = item.quantity + delta;
    if (quantity < 1) {
      throw RangeError.value(quantity, 'quantity', 'Must be at least 1');
    }
    return updateItem(item.copyWith(quantity: quantity));
  }

  /// Removes [item] from the pantry, optionally adding it to the shopping
  /// list. The item disappears from [items] before the first await, so a
  /// dismissed list tile can leave the tree immediately.
  Future<RemovedItem> removeItem(
    PantryItem item, {
    bool addToShoppingList = false,
  }) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError.value(item, 'item', 'Item has no database id.');
    }

    _items.removeWhere((existing) => existing.id == id);
    notifyListeners();

    try {
      await _databaseHelper.deleteItem(id);
      int? shoppingItemId;
      if (addToShoppingList && !_isOnShoppingList(item)) {
        shoppingItemId = await _databaseHelper.insertShoppingItem(
          ShoppingItem(name: item.name, barcode: item.barcode),
        );
      }
      return RemovedItem(item: item, shoppingItemId: shoppingItemId);
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> restoreItem(RemovedItem removed) async {
    try {
      final shoppingItemId = removed.shoppingItemId;
      if (shoppingItemId != null) {
        await _databaseHelper.deleteShoppingItem(shoppingItemId);
      }

      // The same barcode may have been scanned again since the removal.
      final existing = await _databaseHelper.getItemByBarcode(
        removed.item.barcode,
      );
      if (existing == null) {
        await _databaseHelper.insertItem(removed.item);
      } else {
        await _databaseHelper.updateItem(
          existing.copyWith(
            quantity: existing.quantity + removed.item.quantity,
          ),
        );
      }
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> clearInventory() async {
    try {
      await _databaseHelper.deleteAllItems();
    } finally {
      await _reloadAndNotify();
    }
  }

  bool _isOnShoppingList(PantryItem item) {
    return _shoppingItems.any(
      (entry) =>
          !entry.isChecked &&
          (entry.barcode == item.barcode ||
              entry.name.toLowerCase() == item.name.toLowerCase()),
    );
  }

  /// Returns false when an unchecked entry with the same name already exists.
  Future<bool> addShoppingItem(String name, {String? barcode}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final duplicate = _shoppingItems.any(
      (entry) =>
          !entry.isChecked && entry.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return false;

    try {
      await _databaseHelper.insertShoppingItem(
        ShoppingItem(name: trimmed, barcode: barcode),
      );
      return true;
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> setShoppingItemChecked(ShoppingItem item, bool isChecked) async {
    final index = _shoppingItems.indexWhere((entry) => entry.id == item.id);
    if (index != -1) {
      _shoppingItems[index] = item.copyWith(isChecked: isChecked);
      notifyListeners();
    }
    try {
      await _databaseHelper.updateShoppingItem(
        item.copyWith(isChecked: isChecked),
      );
    } finally {
      await _reloadAndNotify();
    }
  }

  /// Removes [item] immediately from [shoppingItems]; see [removeItem].
  Future<void> removeShoppingItem(ShoppingItem item) async {
    final id = item.id;
    if (id == null) return;
    _shoppingItems.removeWhere((entry) => entry.id == id);
    notifyListeners();
    try {
      await _databaseHelper.deleteShoppingItem(id);
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> restoreShoppingItem(ShoppingItem item) async {
    try {
      await _databaseHelper.insertShoppingItem(item);
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> clearCheckedShoppingItems() async {
    try {
      await _databaseHelper.deleteCheckedShoppingItems();
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> clearShoppingList() async {
    try {
      await _databaseHelper.deleteAllShoppingItems();
    } finally {
      await _reloadAndNotify();
    }
  }

  Future<void> _reloadAndNotify() async {
    try {
      await _reload();
    } catch (_) {
      // Keep the optimistic in-memory state; the next load will retry.
    }
    notifyListeners();
  }
}

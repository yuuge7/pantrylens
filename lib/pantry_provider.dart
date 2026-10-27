import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'database_helper.dart';
import 'features/household/household_models.dart';
import 'pantry_item.dart';
import 'shopping_item.dart';
import 'services/error_reporter.dart';

class ScanOutcome {
  const ScanOutcome({
    required this.item,
    required this.isNew,
    this.checkedOffShoppingList = false,
  });
  final PantryItem item;
  final bool isNew;
  final bool checkedOffShoppingList;
}

class RemovedItem {
  const RemovedItem({required this.item, this.shoppingItemId, this.activityId});
  final PantryItem item;
  final int? shoppingItemId;
  final int? activityId;
}

class PantryProvider extends ChangeNotifier {
  PantryProvider({DatabaseHelper? databaseHelper, ApiService? apiService})
    : data = databaseHelper ?? DatabaseHelper.instance,
      _api = apiService ?? ApiService() {
    unawaited(loadItems());
  }
  final DatabaseHelper data;
  final ApiService _api;
  List<PantryItem> _items = [];
  List<ShoppingItem> _shopping = [];
  List<Home> homes = [];
  List<HouseholdRecord> _records = [];
  List<Activity> _activity = [];
  bool _loading = true;
  bool _hasLoaded = false;
  bool _disposed = false;
  String? _error;
  String? _homeId = 'main';
  String actor = 'Me';
  Future<void>? _load;
  Future<void> _writes = Future.value();
  int revision = 0;

  final Set<String> _scanning = {};
  String? get selectedHomeId => _homeId;
  String get selectedHomeName =>
      _homeId == null
          ? 'All homes'
          : homes.where((h) => h.id == _homeId).firstOrNull?.name ?? 'My home';
  List<PantryItem> get allItems => List.unmodifiable(_items);
  List<ShoppingItem> get allShoppingItems => List.unmodifiable(_shopping);
  List<PantryItem> get items => _items
      .where((i) => _homeId == null || i.homeId == _homeId)
      .toList(growable: false);
  List<ShoppingItem> get shoppingItems => _shopping
      .where((i) => _homeId == null || i.homeId == _homeId)
      .toList(growable: false);
  List<HouseholdRecord> get records => _records
      .where((r) => _homeId == null || r.homeId == _homeId)
      .toList(growable: false);
  List<Activity> get activity => _activity
      .where((r) => _homeId == null || r.homeId == _homeId)
      .toList(growable: false);
  bool get isLoading => _loading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _error;
  num get totalUnits => items
      .where((i) => i.unit == 'pieces')
      .fold<num>(0, (s, i) => s + i.quantity);
  num get totalValue => items.fold<num>(0, (s, i) => s + i.value);
  int get shoppingItemsToBuy => shoppingItems.where((i) => !i.isChecked).length;
  List<String> get locations =>
      {
        ...homes
            .where((h) => _homeId == null || h.id == _homeId)
            .expand((h) => h.locations),
        ...items.map((i) => i.location),
      }.toList();
  void selectHome(String? id) {
    if (id != null && !homes.any((h) => h.id == id)) return;
    _homeId = id;
    revision++;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadItems() =>
      _load ??= _loadItems().whenComplete(() => _load = null);
  Future<void> _loadItems() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      await _reload();
    } catch (e, s) {
      _error = 'Your pantry could not be loaded. Check storage and try again.';
      unawaited(ErrorReporter.capture(e, s));
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    final snapshot = await data.getSnapshot();
    _items = snapshot.items;
    _shopping = snapshot.shopping;
    homes = snapshot.homes;
    _records = snapshot.records;
    _activity = snapshot.activity;
    _hasLoaded = true;
    revision++;
  }

  Future<T> _write<T>(Future<T> Function() action, {bool restock = true}) {
    final result = _writes.then((_) async {
      if (_load != null) await _load;
      try {
        final value = await action();
        if (restock) await data.reconcileStock();
        await _reload();
        _error = null;
        return value;
      } catch (e, s) {
        _error = 'Changes could not be saved. Check storage and try again.';
        unawaited(ErrorReporter.capture(e, s));
        rethrow;
      } finally {
        _notify();
      }
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Activity _entry(
    PantryItem i,
    String action,
    num quantity, {
    String? wasteReason,
  }) => Activity(
    homeId: i.homeId,
    actor: actor,
    action: action,
    name: i.name,
    quantity: quantity,
    unit: i.unit,
    value: quantity * i.price,
    at: DateTime.now(),
    wasteReason:
        action == 'wasted'
            ? wasteReason ?? (i.daysUntilExpiry() < 0 ? 'expired' : 'other')
            : null,
  );

  Future<ScanOutcome?> onBarcodeScanned(
    String barcode, {
    int shelfLifeDays = 30,
    bool lookUpProduct = true,
  }) async {
    barcode = barcode.trim();
    if (barcode.isEmpty || !_scanning.add(barcode)) return null;
    final code = barcode;
    try {
      final product =
          lookUpProduct && !_items.any((i) => i.barcode == code)
              ? await _api.fetchProductByBarcode(code)
              : <String, String?>{};
      return await _write(() async {
        final home = _homeId ?? 'main';
        final now = DateTime.now();
        final expiry = DateTime(now.year, now.month, now.day + shelfLifeDays);
        final template = _items.where((i) => i.barcode == code).firstOrNull;
        final shoppingTemplate =
            _shopping.where((i) => i.barcode == code).firstOrNull;
        final existing =
            _items
                .where(
                  (i) =>
                      i.barcode == code &&
                      i.homeId == home &&
                      i.location == 'Pantry' &&
                      i.unit == 'pieces' &&
                      i.openedDate == null &&
                      i.expirationDate == expiry,
                )
                .firstOrNull;
        PantryItem saved;
        if (existing != null) {
          saved = existing.copyWith(quantity: existing.quantity + 1);
          await data.updateItem(saved);
        } else {
          final draft = PantryItem(
            barcode: code,
            name:
                template?.name ??
                product['product_name'] ??
                shoppingTemplate?.name ??
                'Unknown product ($code)',
            imageUrl:
                template?.imageUrl ??
                product['image_url'] ??
                shoppingTemplate?.imageUrl,
            quantity: 1,
            expirationDate: expiry,
            homeId: home,
            minimumStock: await data.stockMinimum(code, home, 'pieces'),
            category: template?.category ?? product['category'] ?? 'Other',
            ingredients: template?.ingredients ?? product['ingredients'] ?? '',
            allergens:
                template?.allergens ??
                (product['allergens'] ?? '')
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .toList(),
            nutrition: template?.nutrition ?? product['nutrition'] ?? '',
          );
          final id = await data.insertItem(draft);
          saved = draft.copyWith(id: id, batchId: draft.batchKey);
        }
        var checked = false;
        for (final entry in _shopping.where(
          (i) => !i.isChecked && i.homeId == home && i.barcode == code,
        )) {
          // A single scan supplies one piece, rather than completing a larger order.
          if (entry.unit != 'pieces') continue;
          await data.updateShoppingItem(
            entry.quantity <= 1
                ? entry.copyWith(isChecked: true)
                : entry.copyWith(quantity: entry.quantity - 1),
          );
          if (entry.quantity <= 1) {
            checked = true;
            await data.saveRecord(
              HouseholdRecord(
                kind: 'purchase',
                homeId: entry.homeId,
                data: entry.copyWith(isChecked: true).toMap(),
              ),
            );
          }
        }
        await data.log(_entry(saved, 'added', 1));
        return ScanOutcome(
          item: saved,
          isNew: existing == null,
          checkedOffShoppingList: checked,
        );
      });
    } finally {
      _scanning.remove(code);
    }
  }

  Future<PantryItem> addBatch(PantryItem item) => _write(() async {
    final batch = item.copyWith(
      batchId:
          item.batchId.isEmpty
              ? 'batch-${DateTime.now().microsecondsSinceEpoch}'
              : item.batchId,
    );
    final id = await data.insertItem(batch);
    await data.saveStockRule(batch);
    await data.log(_entry(batch, 'added', batch.quantity));
    return batch.copyWith(id: id);
  });
  Future<void> addBatches(List<PantryItem> items) => _write(() async {
    final db = await data.database;
    for (final item in items) {
      item.validate();
    }
    await db.transaction((txn) async {
      for (var n = 0; n < items.length; n++) {
        final item = items[n].copyWith(
          batchId: 'receipt-${DateTime.now().microsecondsSinceEpoch}-$n',
        );
        await txn.insert('pantry_items', item.toMap()..remove('id'));
        await data.log(_entry(item, 'added', item.quantity), txn: txn);
      }
    });
  });
  Future<void> updateItem(PantryItem item) => _write(() async {
    final previous = _items.where((i) => i.id == item.id).firstOrNull;
    if (previous == null) throw StateError('This batch no longer exists.');
    await data.updateItem(item);
    // Product corrections apply across purchases; batch-specific fields stay local.
    if (item.barcode == previous.barcode &&
        (item.name != previous.name ||
            item.imageUrl != previous.imageUrl ||
            item.category != previous.category ||
            item.ingredients != previous.ingredients ||
            !listEquals(item.allergens, previous.allergens))) {
      final db = await data.database;
      await db.update(
        'pantry_items',
        {
          'name': item.name,
          'imageUrl': item.imageUrl,
          'category': item.category,
          'ingredients': item.ingredients,
          'allergens': item.toMap()['allergens'],
          'nutrition': item.nutrition,
        },
        where: 'barcode=?',
        whereArgs: [item.barcode],
      );
    }
    await data.saveStockRule(item);
    final difference = item.quantity - previous.quantity;
    await data.log(
      _entry(
        item,
        difference < 0
            ? 'used'
            : difference > 0
            ? 'added'
            : previous.homeId != item.homeId ||
                previous.location != item.location
            ? 'moved'
            : 'edited',
        difference.abs(),
      ),
    );
  });
  Future<void> changeQuantity(PantryItem item, num delta) => _write(() async {
    final current = _items.firstWhere((i) => i.id == item.id);
    final next = current.copyWith(quantity: current.quantity + delta);
    await data.updateItem(next);
    await data.log(_entry(current, delta < 0 ? 'used' : 'added', delta.abs()));
  });

  /// Consume the earliest effective expiry first, within one home and unit.
  Future<void> useProduct(
    String barcode,
    num amount, {
    required String homeId,
    String unit = 'pieces',
    bool wasted = false,
    String? wasteReason,
  }) => _write(() async {
    if (!amount.isFinite || amount <= 0)
      throw ArgumentError('Enter a positive amount');
    final batches =
        _items
            .where(
              (i) =>
                  i.barcode == barcode && i.homeId == homeId && i.unit == unit,
            )
            .toList()
          ..sort((a, b) => a.effectiveExpiry.compareTo(b.effectiveExpiry));
    if (batches.fold<num>(0, (s, i) => s + i.quantity) < amount)
      throw StateError('Not enough stock');
    final db = await data.database;
    await db.transaction((txn) async {
      var left = amount;
      for (final batch in batches) {
        if (left <= 0) break;
        final used = left < batch.quantity ? left : batch.quantity;
        if (used == batch.quantity) {
          await txn.delete(
            'pantry_items',
            where: 'id=?',
            whereArgs: [batch.id],
          );
        } else {
          await txn.update(
            'pantry_items',
            {'quantity': batch.quantity - used},
            where: 'id=?',
            whereArgs: [batch.id],
          );
        }
        await data.log(
          _entry(
            batch,
            wasted ? 'wasted' : 'used',
            used,
            wasteReason: wasteReason,
          ),
          txn: txn,
        );
        left -= used;
      }
    });
  });

  /// Waste is recorded against the physical batch the person discarded.
  Future<void> discardBatch(PantryItem item, num amount, String reason) =>
      _write(() async {
        if (!Activity.wasteReasons.contains(reason))
          throw ArgumentError('Choose a waste reason');
        final current = _items.firstWhere((i) => i.id == item.id);
        if (!amount.isFinite || amount <= 0 || amount > current.quantity)
          throw ArgumentError('Enter an amount within this batch');
        await (await data.database).transaction((txn) async {
          if (amount == current.quantity) {
            await txn.delete(
              'pantry_items',
              where: 'id=?',
              whereArgs: [current.id],
            );
          } else {
            await txn.update(
              'pantry_items',
              {'quantity': current.quantity - amount},
              where: 'id=?',
              whereArgs: [current.id],
            );
          }
          await data.log(
            _entry(current, 'wasted', amount, wasteReason: reason),
            txn: txn,
          );
        });
      });

  Future<RemovedItem> removeItem(
    PantryItem item, {
    bool addToShoppingList = false,
    bool wasted = false,
    bool usedUp = false,
    String? wasteReason,
  }) => _write(() async {
    if (item.id == null) throw ArgumentError('Missing batch id');
    final current = _items.firstWhere((i) => i.id == item.id);
    final db = await data.database;
    int? shoppingId;
    int? logId;
    await db.transaction((txn) async {
      await txn.delete('pantry_items', where: 'id=?', whereArgs: [current.id]);
      if (addToShoppingList &&
          !_shopping.any(
            (e) =>
                !e.isChecked &&
                e.homeId == current.homeId &&
                e.barcode == current.barcode &&
                e.unit == current.unit,
          )) {
        shoppingId = await txn.insert(
          'shopping_items',
          ShoppingItem(
            name: current.name,
            barcode: current.barcode,
            imageUrl: current.imageUrl,
            homeId: current.homeId,
            unit: current.unit,
            aisle: current.category,
            store: current.store,
          ).toMap(),
        );
      }
      logId = await data.log(
        _entry(
          current,
          wasted
              ? 'wasted'
              : usedUp || addToShoppingList
              ? 'used'
              : 'removed',
          current.quantity,
          wasteReason: wasteReason,
        ),
        txn: txn,
      );
    });
    return RemovedItem(
      item: current,
      shoppingItemId: shoppingId,
      activityId: logId,
    );
  });
  Future<void> restoreItem(RemovedItem removed) => _write(() async {
    final db = await data.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'pantry_items',
        where: 'batchId=?',
        whereArgs: [removed.item.batchKey],
      );
      if (rows.isEmpty) {
        await txn.insert('pantry_items', removed.item.toMap()..remove('id'));
      } else {
        await txn.update(
          'pantry_items',
          {'quantity': (rows.first['quantity'] as num) + removed.item.quantity},
          where: 'id=?',
          whereArgs: [rows.first['id']],
        );
      }
      if (removed.shoppingItemId != null)
        await txn.delete(
          'shopping_items',
          where: 'id=?',
          whereArgs: [removed.shoppingItemId],
        );
      if (removed.activityId != null)
        await txn.delete(
          'activity',
          where: 'id=?',
          whereArgs: [removed.activityId],
        );
      await data.log(
        _entry(removed.item, 'restored', removed.item.quantity),
        txn: txn,
      );
    });
  });
  Future<void> clearInventory() => _write(() async {
    await data.deleteAllItems(homeId: _homeId, actor: actor);
  });
  Future<void> importItems(
    List<PantryItem> items, {
    required bool replaceAll,
  }) => _write(() async {
    await data.importItems(
      items,
      replaceAll: replaceAll,
      replaceHomeId: _homeId,
      actor: actor,
    );
    for (final item in items) {
      await data.saveStockRule(item);
    }
  });
  PantryItem? pantryItemFor(ShoppingItem entry) =>
      _items
          .where(
            (i) =>
                i.homeId == entry.homeId &&
                (i.barcode == entry.barcode ||
                    i.name.toLowerCase() == entry.name.toLowerCase()),
          )
          .firstOrNull;
  Future<bool> addShoppingItem(
    String name, {
    String? barcode,
    String? imageUrl,
    num quantity = 1,
    String unit = 'pieces',
    String aisle = 'Other',
    String store = '',
    String? homeId,
    bool ensureQuantity = false,
  }) => _write(() async {
    final h = homeId ?? _homeId ?? 'main';
    if (name.trim().isEmpty || !quantity.isFinite || quantity <= 0)
      return false;
    final duplicate =
        _shopping
            .where(
              (e) =>
                  !e.isChecked &&
                  e.homeId == h &&
                  e.unit == unit &&
                  e.name.toLowerCase() == name.trim().toLowerCase(),
            )
            .firstOrNull;
    if (duplicate != null) {
      if (ensureQuantity && quantity > duplicate.quantity) {
        await data.updateShoppingItem(
          duplicate.copyWith(quantity: quantity, automatic: false),
        );
        return true;
      }
      return false;
    }
    await data.insertShoppingItem(
      ShoppingItem(
        name: name.trim(),
        barcode: barcode,
        imageUrl: imageUrl,
        quantity: quantity,
        unit: unit,
        homeId: h,
        aisle: aisle,
        store: store,
      ),
    );
    return true;
  }, restock: false);
  Future<void> updateShoppingItem(ShoppingItem item) => _write(() async {
    final before = _shopping.where((s) => s.id == item.id).firstOrNull;
    final saved = item.copyWith(automatic: false);
    await data.updateShoppingItem(saved);
    if (item.isChecked && before?.isChecked == false) {
      await data.saveRecord(
        HouseholdRecord(
          kind: 'purchase',
          homeId: item.homeId,
          data: saved.toMap(),
        ),
      );
    }
  }, restock: false);
  Future<void> setShoppingItemChecked(ShoppingItem item, bool checked) =>
      updateShoppingItem(item.copyWith(isChecked: checked));
  Future<void> removeShoppingItem(ShoppingItem item) => _write(() async {
    if (item.id != null) await data.deleteShoppingItem(item.id!);
  }, restock: false);
  Future<void> restoreShoppingItem(ShoppingItem item) => _write(() async {
    await data.insertShoppingItem(item);
  }, restock: false);
  Future<void> clearCheckedShoppingItems() => _write(() async {
    await data.deleteCheckedShoppingItems(homeId: _homeId);
  }, restock: false);
  Future<void> clearShoppingList() => _write(() async {
    await data.deleteAllShoppingItems(homeId: _homeId);
  }, restock: false);
  Future<void> saveHome(Home home) => _write(() async {
    await data.saveHome(home);
  }, restock: false);
  Future<void> saveRecord(HouseholdRecord record) => _write(() async {
    await data.saveRecord(record);
  }, restock: false);
  Future<void> deleteRecord(int id) => _write(() async {
    await data.deleteRecord(id);
  }, restock: false);

  Set<String> allergyWarnings(PantryItem item) {
    final warnings = <String>{};
    final text =
        '${item.allergens.join(' ')} ${item.ingredients}'.toLowerCase();
    for (final p in _records.where(
      (r) => r.kind == 'profile' && r.homeId == item.homeId,
    )) {
      for (final a in (p.data['allergies'] as String? ?? '').split(',')) {
        if (a.trim().isNotEmpty && text.contains(a.trim().toLowerCase()))
          warnings.add('${p.data['name']}: ${a.trim()}');
      }
    }
    return warnings;
  }

  Future<void> loadSamplePantry() async {
    if (_loading) await loadItems();
    final now = DateTime.now();
    await addBatches([
      PantryItem(
        barcode: 'sample-oats',
        name: 'Rolled oats',
        quantity: 0.75,
        unit: 'kg',
        category: 'Dry goods',
        price: 4.2,
        expirationDate: now.add(const Duration(days: 90)),
        homeId: _homeId ?? 'main',
      ),
      PantryItem(
        barcode: 'sample-yogurt',
        name: 'Natural yogurt',
        quantity: 2,
        category: 'Dairy',
        location: 'Fridge',
        price: 1.8,
        allergens: const ['milk'],
        expirationDate: now.add(const Duration(days: 2)),
        homeId: _homeId ?? 'main',
      ),
      PantryItem(
        barcode: 'sample-tomatoes',
        name: 'Cherry tomatoes',
        quantity: 0.5,
        unit: 'kg',
        category: 'Produce',
        location: 'Fridge',
        price: 5,
        expirationDate: now.add(const Duration(days: 4)),
        homeId: _homeId ?? 'main',
      ),
    ]);
  }
}

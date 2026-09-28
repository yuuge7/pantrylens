import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InventorySort { name, expiry, quantity, recent }

/// App preferences, persisted with shared_preferences.
///
/// Without a [SharedPreferences] instance the values live in memory only,
/// which keeps tests independent of device storage.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider([this._prefs]) {
    final prefs = _prefs;
    if (prefs == null) return;

    _themeMode = _enumByName(
      ThemeMode.values,
      prefs.getString(_themeModeKey),
      _themeMode,
    );
    _inventorySort = _enumByName(
      InventorySort.values,
      prefs.getString(_inventorySortKey),
      _inventorySort,
    );
    _shelfLifeDays = prefs.getInt(_shelfLifeDaysKey) ?? _shelfLifeDays;
    _useSoonDays = prefs.getInt(_useSoonDaysKey) ?? _useSoonDays;
    _lookUpProducts = prefs.getBool(_lookUpProductsKey) ?? _lookUpProducts;
    _keepScanning = prefs.getBool(_keepScanningKey) ?? _keepScanning;
    _vibrateOnScan = prefs.getBool(_vibrateOnScanKey) ?? _vibrateOnScan;
    _addUsedUpToShoppingList =
        prefs.getBool(_addUsedUpKey) ?? _addUsedUpToShoppingList;
  }

  static Future<SettingsProvider> load() async {
    return SettingsProvider(await SharedPreferences.getInstance());
  }

  static const List<int> shelfLifeOptions = [7, 14, 30, 90, 180, 365];
  static const List<int> useSoonOptions = [3, 7, 14];

  static const String _themeModeKey = 'themeMode';
  static const String _inventorySortKey = 'inventorySort';
  static const String _shelfLifeDaysKey = 'shelfLifeDays';
  static const String _useSoonDaysKey = 'useSoonDays';
  static const String _lookUpProductsKey = 'lookUpProducts';
  static const String _keepScanningKey = 'keepScanning';
  static const String _vibrateOnScanKey = 'vibrateOnScan';
  static const String _addUsedUpKey = 'addUsedUpToShoppingList';

  final SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  InventorySort _inventorySort = InventorySort.name;
  int _shelfLifeDays = 30;
  int _useSoonDays = 7;
  bool _lookUpProducts = true;
  bool _keepScanning = false;
  bool _vibrateOnScan = true;
  bool _addUsedUpToShoppingList = true;

  ThemeMode get themeMode => _themeMode;
  InventorySort get inventorySort => _inventorySort;

  /// Days from the scan date used as the best-before date for new items.
  int get shelfLifeDays => _shelfLifeDays;

  /// Items expiring within this many days are flagged as "use soon".
  int get useSoonDays => _useSoonDays;
  bool get lookUpProducts => _lookUpProducts;
  bool get keepScanning => _keepScanning;
  bool get vibrateOnScan => _vibrateOnScan;
  bool get addUsedUpToShoppingList => _addUsedUpToShoppingList;

  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _prefs?.setString(_themeModeKey, value.name);
    notifyListeners();
  }

  set inventorySort(InventorySort value) {
    if (value == _inventorySort) return;
    _inventorySort = value;
    _prefs?.setString(_inventorySortKey, value.name);
    notifyListeners();
  }

  set shelfLifeDays(int value) {
    if (value == _shelfLifeDays || value < 1) return;
    _shelfLifeDays = value;
    _prefs?.setInt(_shelfLifeDaysKey, value);
    notifyListeners();
  }

  set useSoonDays(int value) {
    if (value == _useSoonDays || value < 1) return;
    _useSoonDays = value;
    _prefs?.setInt(_useSoonDaysKey, value);
    notifyListeners();
  }

  set lookUpProducts(bool value) {
    if (value == _lookUpProducts) return;
    _lookUpProducts = value;
    _prefs?.setBool(_lookUpProductsKey, value);
    notifyListeners();
  }

  set keepScanning(bool value) {
    if (value == _keepScanning) return;
    _keepScanning = value;
    _prefs?.setBool(_keepScanningKey, value);
    notifyListeners();
  }

  set vibrateOnScan(bool value) {
    if (value == _vibrateOnScan) return;
    _vibrateOnScan = value;
    _prefs?.setBool(_vibrateOnScanKey, value);
    notifyListeners();
  }

  set addUsedUpToShoppingList(bool value) {
    if (value == _addUsedUpToShoppingList) return;
    _addUsedUpToShoppingList = value;
    _prefs?.setBool(_addUsedUpKey, value);
    notifyListeners();
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/error_reporter.dart';

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
    final extra = prefs.getString('householdSettings');
    if (extra != null) {
      try {
        _extra.addAll((jsonDecode(extra) as Map).cast<String, dynamic>());
      } catch (error, stack) {
        persistenceError =
            'Some preferences could not be read. Review your settings and retry saving.';
        unawaited(ErrorReporter.capture(error, stack));
      }
    }
  }

  static Future<SettingsProvider> load() async {
    try {
      return SettingsProvider(await SharedPreferences.getInstance());
    } catch (error, stack) {
      unawaited(ErrorReporter.capture(error, stack));
      final settings = SettingsProvider();
      settings._extra['onboardingComplete'] = false;
      settings.persistenceError =
          'Preferences could not be loaded. Changes are temporary until you retry saving.';
      return settings;
    }
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

  SharedPreferences? _prefs;
  String? persistenceError;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _save(Future<bool>? result) async {
    if (result == null) return;
    try {
      if (!await result)
        throw StateError('Preference storage rejected the write');
    } catch (error, stack) {
      persistenceError =
          'Preferences could not be saved. Retry before closing the app.';
      unawaited(ErrorReporter.capture(error, stack));
      _notify();
    }
  }

  Future<void> retryPersistence() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final saved = await Future.wait([
        prefs.setString(_themeModeKey, _themeMode.name),
        prefs.setString(_inventorySortKey, _inventorySort.name),
        prefs.setInt(_shelfLifeDaysKey, _shelfLifeDays),
        prefs.setInt(_useSoonDaysKey, _useSoonDays),
        prefs.setBool(_lookUpProductsKey, _lookUpProducts),
        prefs.setBool(_keepScanningKey, _keepScanning),
        prefs.setBool(_vibrateOnScanKey, _vibrateOnScan),
        prefs.setBool(_addUsedUpKey, _addUsedUpToShoppingList),
        prefs.setString('householdSettings', jsonEncode(_extra)),
      ]);
      if (saved.any((v) => !v))
        throw StateError('Preference storage rejected the write');
      persistenceError = null;
    } catch (error, stack) {
      persistenceError =
          'Preferences could not be saved. Check available storage and retry.';
      unawaited(ErrorReporter.capture(error, stack));
    }
    _notify();
  }

  final Map<String, dynamic> _extra = {};
  bool get onboardingComplete =>
      _extra['onboardingComplete'] as bool? ?? (_prefs == null);
  bool get remindersEnabled => _extra['remindersEnabled'] as bool? ?? false;
  bool get dailyDigest => _extra['dailyDigest'] as bool? ?? true;
  int get reminderHour => _extra['reminderHour'] as int? ?? 9;
  int get reminderMinute => _extra['reminderMinute'] as int? ?? 0;
  int get quietStart => _extra['quietStart'] as int? ?? 22;
  int get quietEnd => _extra['quietEnd'] as int? ?? 8;
  String get actorName => _extra['actorName'] as String? ?? 'Me';
  String get currency => _extra['currency'] as String? ?? 'EUR';
  String? get homeId =>
      _extra.containsKey('homeId') ? _extra['homeId'] as String? : 'main';
  Future<void> setExtra(String key, dynamic value) async {
    _extra[key] = value;
    await _save(_prefs?.setString('householdSettings', jsonEncode(_extra)));
    _notify();
  }

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
    unawaited(_save(_prefs?.setString(_themeModeKey, value.name)));
    _notify();
  }

  set inventorySort(InventorySort value) {
    if (value == _inventorySort) return;
    _inventorySort = value;
    unawaited(_save(_prefs?.setString(_inventorySortKey, value.name)));
    _notify();
  }

  set shelfLifeDays(int value) {
    if (value == _shelfLifeDays || value < 1) return;
    _shelfLifeDays = value;
    unawaited(_save(_prefs?.setInt(_shelfLifeDaysKey, value)));
    _notify();
  }

  set useSoonDays(int value) {
    if (value == _useSoonDays || value < 1) return;
    _useSoonDays = value;
    unawaited(_save(_prefs?.setInt(_useSoonDaysKey, value)));
    _notify();
  }

  set lookUpProducts(bool value) {
    if (value == _lookUpProducts) return;
    _lookUpProducts = value;
    unawaited(_save(_prefs?.setBool(_lookUpProductsKey, value)));
    _notify();
  }

  set keepScanning(bool value) {
    if (value == _keepScanning) return;
    _keepScanning = value;
    unawaited(_save(_prefs?.setBool(_keepScanningKey, value)));
    _notify();
  }

  set vibrateOnScan(bool value) {
    if (value == _vibrateOnScan) return;
    _vibrateOnScan = value;
    unawaited(_save(_prefs?.setBool(_vibrateOnScanKey, value)));
    _notify();
  }

  set addUsedUpToShoppingList(bool value) {
    if (value == _addUsedUpToShoppingList) return;
    _addUsedUpToShoppingList = value;
    unawaited(_save(_prefs?.setBool(_addUsedUpKey, value)));
    _notify();
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

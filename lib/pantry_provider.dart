import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'database_helper.dart';
import 'pantry_item.dart';

class PantryProvider extends ChangeNotifier {
  PantryProvider({DatabaseHelper? databaseHelper, ApiService? apiService})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
      _apiService = apiService ?? ApiService() {
    loadItems();
  }

  final DatabaseHelper _databaseHelper;
  final ApiService _apiService;
  final List<PantryItem> _items = [];
  final Set<String> _barcodesBeingProcessed = {};

  bool _isLoading = true;
  String? _errorMessage;

  List<PantryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadItems() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _items
        ..clear()
        ..addAll(await _databaseHelper.getAllItems());
    } catch (_) {
      _errorMessage = 'Your pantry could not be loaded. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> onBarcodeScanned(String barcode) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty ||
        !_barcodesBeingProcessed.add(normalizedBarcode)) {
      return;
    }

    try {
      final existingItem = await _databaseHelper.getItemByBarcode(
        normalizedBarcode,
      );

      if (existingItem != null) {
        await _databaseHelper.updateItem(
          existingItem.copyWith(quantity: existingItem.quantity + 1),
        );
      } else {
        final product = await _apiService.fetchProductByBarcode(
          normalizedBarcode,
        );
        final productName = product['product_name']?.trim();

        final item = PantryItem(
          barcode: normalizedBarcode,
          name:
              productName == null || productName.isEmpty
                  ? 'Unknown product ($normalizedBarcode)'
                  : productName,
          imageUrl: product['image_url'],
          quantity: 1,
          expirationDate: _oneMonthFromToday(),
        );
        await _databaseHelper.insertItem(item);
      }

      _items
        ..clear()
        ..addAll(await _databaseHelper.getAllItems());
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'The scanned item could not be saved. Please try again.';
      rethrow;
    } finally {
      _barcodesBeingProcessed.remove(normalizedBarcode);
      notifyListeners();
    }
  }

  DateTime _oneMonthFromToday() {
    final today = DateTime.now();
    final nextMonth = today.month == 12 ? 1 : today.month + 1;
    final nextYear = today.month == 12 ? today.year + 1 : today.year;
    final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
    final day = today.day > lastDayOfNextMonth ? lastDayOfNextMonth : today.day;

    return DateTime(nextYear, nextMonth, day);
  }
}

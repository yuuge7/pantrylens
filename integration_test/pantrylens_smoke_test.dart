import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:pantrylens/api_service.dart';
import 'package:pantrylens/database_helper.dart';
import 'package:pantrylens/inventory_backup.dart';
import 'package:pantrylens/main.dart';
import 'package:pantrylens/pantry_item.dart';
import 'package:pantrylens/pantry_provider.dart';
import 'package:pantrylens/screens/photo_viewer.dart';
import 'package:pantrylens/settings_provider.dart';
import 'package:pantrylens/shopping_item.dart';

class _FakeApiService extends ApiService {
  @override
  Future<Map<String, String?>> fetchProductByBarcode(String barcode) async {
    return const {'product_name': 'Emulator Test Product', 'image_url': null};
  }
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Widget _app(PantryProvider provider) {
  return MultiProvider(
    providers: [
      // In-memory settings, so the test leaves device preferences alone.
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider<PantryProvider>.value(value: provider),
    ],
    child: const MyApp(),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads, adds, increments, and opens the scanner', (tester) async {
    final database = DatabaseHelper.instance;
    final provider = PantryProvider(apiService: _FakeApiService());
    await provider.loadItems();

    final barcode = '${DateTime.now().millisecondsSinceEpoch}';
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();
    expect(find.text('PantryLens'), findsOneWidget);

    await provider.onBarcodeScanned(barcode);
    var savedItem = await database.getItemByBarcode(barcode);
    expect(savedItem, isNotNull);
    expect(savedItem!.name, 'Emulator Test Product');
    expect(savedItem.quantity, 1);

    await provider.onBarcodeScanned(barcode);
    savedItem = await database.getItemByBarcode(barcode);
    expect(savedItem!.quantity, 2);

    await tester.pumpAndSettle();
    await tester.tap(_tab('Inventory'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), barcode);
    await tester.pumpAndSettle();
    expect(find.text('Emulator Test Product'), findsOneWidget);

    await tester.tap(find.byTooltip('Add one of Emulator Test Product'));
    await tester.pumpAndSettle();
    savedItem = await database.getItemByBarcode(barcode);
    expect(savedItem!.quantity, 3);

    await tester.tap(_tab('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Appearance'))).brightness,
      Brightness.dark,
    );

    await tester.tap(_tab('Inventory'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan item'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Scan barcode'), findsOneWidget);

    await database.deleteItem(savedItem.id!);
    await provider.loadItems();
  });

  testWidgets('edits a shopping list entry', (tester) async {
    final database = DatabaseHelper.instance;
    final provider = PantryProvider(apiService: _FakeApiService());
    await provider.loadItems();

    final name = 'Emulator List Entry ${DateTime.now().millisecondsSinceEpoch}';
    Future<ShoppingItem> saved() async => (await database.getShoppingItems())
        .firstWhere((entry) => entry.name == name);

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();
    expect(await provider.addShoppingItem(name), isTrue);

    await tester.tap(_tab('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add one of $name'));
    await tester.pumpAndSettle();
    expect((await saved()).quantity, 2);

    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(find.text('Quantity to buy'), findsOneWidget);
    await tester.tap(find.text('In basket'));
    await tester.pumpAndSettle();
    expect((await saved()).isChecked, isTrue);

    await provider.removeShoppingItem(await saved());
  });

  testWidgets('exports and imports the inventory', (tester) async {
    final database = DatabaseHelper.instance;
    final provider = PantryProvider(apiService: _FakeApiService());
    final barcode = '${DateTime.now().millisecondsSinceEpoch}';
    PantryItem item(int quantity) => PantryItem(
      barcode: barcode,
      name: 'Emulator Backup Product',
      imageUrl: 'https://example.com/photo.jpg',
      quantity: quantity,
      expirationDate: DateTime(2030, 1, 15),
    );

    final decoded = InventoryBackup.decode(InventoryBackup.encode([item(5)]));
    expect(decoded.single.toMap(), item(5).toMap());
    expect(
      () => InventoryBackup.decode('{"items": [{"name": "No barcode"}]}'),
      throwsFormatException,
    );
    expect(() => InventoryBackup.decode('not json'), throwsFormatException);

    await provider.importItems(decoded, replaceAll: false);
    expect((await database.getItemByBarcode(barcode))!.quantity, 5);

    // Importing a barcode again updates the item instead of duplicating it.
    await provider.importItems([item(7)], replaceAll: false);
    final saved = await database.getItemByBarcode(barcode);
    expect(saved!.quantity, 7);
    expect(
      provider.items.where((entry) => entry.barcode == barcode),
      hasLength(1),
    );

    await database.deleteItem(saved.id!);
    await provider.loadItems();
  });

  testWidgets('asks Open Food Facts for the full-size photo', (tester) async {
    const photos = 'https://images.openfoodfacts.org/images/products/301';
    expect(
      PhotoViewer.fullSizeUrl('$photos/front_en.879.400.jpg'),
      '$photos/front_en.879.full.jpg',
    );
    expect(
      PhotoViewer.fullSizeUrl('https://example.com/photo.400.jpg'),
      'https://example.com/photo.400.jpg',
    );
  });

  testWidgets('parses an Open Food Facts product response', (tester) async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://world.openfoodfacts.org/api/v0/product/3017620422003.json',
      );
      expect(request.headers['User-Agent'], 'PantryLens/1.0 (Flutter app)');

      return http.Response(
        jsonEncode({
          'status': 1,
          'product': {
            'product_name': 'Nutella',
            'image_url': 'https://images.openfoodfacts.org/nutella.jpg',
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final product = await ApiService(
      client: client,
    ).fetchProductByBarcode('3017620422003');

    expect(product.keys, containsAll(['product_name', 'image_url']));
    expect(product['product_name'], 'Nutella');
    expect(
      product['image_url'],
      'https://images.openfoodfacts.org/nutella.jpg',
    );
  });
}

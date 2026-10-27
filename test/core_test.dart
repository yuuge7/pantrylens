import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pantrylens/api_service.dart';
import 'package:pantrylens/database_helper.dart';
import 'package:pantrylens/pantry_item.dart';
import 'package:pantrylens/pantry_provider.dart';
import 'package:pantrylens/shopping_item.dart';
import 'package:pantrylens/inventory_backup.dart';
import 'package:pantrylens/features/adding/text_parsers.dart';
import 'package:pantrylens/features/household/event_planner.dart';
import 'package:pantrylens/features/household/household_models.dart';
import 'package:pantrylens/services/reminder_service.dart';
import 'package:pantrylens/settings_provider.dart';

PantryItem batch({
  String barcode = 'milk',
  String batchId = '',
  String home = 'main',
  num quantity = 2,
  DateTime? expiry,
  String unit = 'pieces',
  num minimum = 0,
}) => PantryItem(
  batchId: batchId,
  barcode: barcode,
  name: barcode,
  quantity: quantity,
  unit: unit,
  homeId: home,
  expirationDate: expiry ?? DateTime(2030, 1, 1),
  minimumStock: minimum,
  price: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  group('Batch model and backup', () {
    test('fractional amounts and opening expiry round trip', () {
      final item = batch(quantity: 0.5, unit: 'bottle').copyWith(
        openedDate: DateTime(2026, 10, 25),
        daysAfterOpening: 3,
        tags: ['breakfast'],
        allergens: ['milk'],
      );
      expect(item.effectiveExpiry, DateTime(2026, 10, 28));
      expect(item.daysUntilExpiry(DateTime(2026, 10, 27, 23, 59)), 1);
      expect(item.amountLabel, '0.5 bottle');
      expect(PantryItem.fromMap(item.toMap()).toMap(), item.toMap());
      expect(
        InventoryBackup.decode(InventoryBackup.encode([item])).single.toMap(),
        item.toMap(),
      );
      expect(item.copyWith(clearOpened: true).openedDate, isNull);
    });
    test('opening never extends original best-before', () {
      expect(
        batch(expiry: DateTime(2026, 10, 26))
            .copyWith(openedDate: DateTime(2026, 10, 25), daysAfterOpening: 10)
            .effectiveExpiry,
        DateTime(2026, 10, 26),
      );
    });
    test('invalid quantities and prices cannot reach storage', () {
      for (final amount in [0, -1, double.nan, double.infinity]) {
        expect(() => batch(quantity: amount).validate(), throwsFormatException);
      }
      expect(
        () => batch().copyWith(price: -1).validate(),
        throwsFormatException,
      );
    });
    test('backup preserves separate batches and imports v1', () {
      final a = batch(batchId: 'a');
      final b = batch(batchId: 'b');
      expect(
        InventoryBackup.decode(InventoryBackup.encode([a, b])),
        hasLength(2),
      );
      final old =
          '{"version":1,"items":[{"barcode":"1","name":"Rice","quantity":2,"expirationDate":"2030-01-01"}]}';
      expect(InventoryBackup.decode(old).single.unit, 'pieces');
      expect(InventoryBackup.decode(InventoryBackup.encode([])), isEmpty);
      expect(
        () => InventoryBackup.decode('{"version":99,"items":[]}'),
        throwsFormatException,
      );
      expect(
        () => InventoryBackup.decode('{"items":[{}]}'),
        throwsFormatException,
      );
      expect(() => InventoryBackup.decode('bad'), throwsFormatException);
    });
    test('shopping item retains home and aisle', () {
      const item = ShoppingItem(
        name: 'Olive oil',
        quantity: 0.5,
        unit: 'l',
        homeId: 'second',
        aisle: 'Dry goods',
        automatic: true,
      );
      expect(
        ShoppingItem.fromMap(item.toMap()).copyWith(isChecked: true).homeId,
        'second',
      );
      expect(ShoppingItem.fromMap(item.toMap()).toMap(), item.toMap());
    });
  });

  group('Database and provider', () {
    late Database db;
    late DatabaseHelper data;
    late PantryProvider pantry;
    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: DatabaseHelper.createSchema,
        ),
      );
      data = DatabaseHelper.forDatabase(db);
      pantry = PantryProvider(databaseHelper: data);
      await pantry.loadItems();
    });
    tearDown(() async {
      pantry.dispose();
      await db.close();
    });
    test(
      'same barcode can have independent batches, homes and partial amounts',
      () async {
        await pantry.addBatch(batch(batchId: 'a', quantity: 0.5, unit: 'l'));
        await pantry.addBatch(batch(batchId: 'b', quantity: 2, unit: 'l'));
        await pantry.saveHome(const Home(id: 'second', name: 'Guest house'));
        await pantry.addBatch(batch(batchId: 'c', home: 'second'));
        expect(pantry.items, hasLength(2));
        pantry.selectHome(null);
        expect(pantry.items, hasLength(3));
        pantry.selectHome('second');
        expect(pantry.items.single.batchId, 'c');
      },
    );
    test(
      'oldest first uses effective opened expiry and never crosses homes',
      () async {
        await pantry.addBatch(
          batch(batchId: 'late', quantity: 4, expiry: DateTime(2030, 6, 1)),
        );
        await pantry.addBatch(
          batch(
            batchId: 'opened',
            quantity: 1,
            expiry: DateTime(2030, 7, 1),
          ).copyWith(openedDate: DateTime(2029, 1, 1), daysAfterOpening: 3),
        );
        await pantry.addBatch(
          batch(
            batchId: 'other-home',
            home: 'second',
            quantity: 7,
            expiry: DateTime(2028),
          ),
        );
        await pantry.useProduct('milk', 2, homeId: 'main');
        expect(pantry.allItems.any((i) => i.batchId == 'opened'), isFalse);
        expect(
          pantry.allItems.firstWhere((i) => i.batchId == 'late').quantity,
          3,
        );
        expect(
          pantry.allItems.firstWhere((i) => i.batchId == 'other-home').quantity,
          7,
        );
        expect(pantry.activity.where((a) => a.action == 'used'), hasLength(2));
        await expectLater(
          pantry.useProduct('milk', 100, homeId: 'main'),
          throwsStateError,
        );
        expect(pantry.items.single.quantity, 3);
      },
    );
    test(
      'minimum stock survives last batch and reconciles after restock',
      () async {
        await pantry.addBatch(batch(batchId: 'a', quantity: 1, minimum: 2));
        expect(pantry.shoppingItems.single.quantity, 1);
        await pantry.useProduct('milk', 1, homeId: 'main');
        expect(pantry.items, isEmpty);
        expect(pantry.shoppingItems.single.quantity, 2);
        await pantry.addBatch(batch(batchId: 'b', quantity: 3, minimum: 2));
        expect(pantry.shoppingItems, isEmpty);
      },
    );
    test(
      'product corrections and thresholds stay consistent across batches',
      () async {
        final first = await pantry.addBatch(batch(batchId: 'a', minimum: 2));
        await pantry.addBatch(batch(batchId: 'b', minimum: 2));
        await pantry.updateItem(
          first.copyWith(name: 'Corrected milk', minimumStock: 3),
        );
        expect(
          pantry.items.every(
            (i) => i.name == 'Corrected milk' && i.minimumStock == 3,
          ),
          isTrue,
        );
      },
    );
    test('usage is recorded when automatic shopping is disabled', () async {
      final item = await pantry.addBatch(
        batch(batchId: 'used-without-shopping'),
      );
      await pantry.removeItem(item, usedUp: true);
      expect(pantry.shoppingItems, isEmpty);
      expect(
        pantry.activity.where((a) => a.action == 'used').single.quantity,
        2,
      );
    });
    test('reports include history beyond the activity feed limit', () async {
      await db.transaction((txn) async {
        final b = txn.batch();
        b.insert('activity', const <String, Object?>{
          'homeId': 'main',
          'actor': 'Me',
          'action': 'wasted',
          'name': 'Old waste',
          'quantity': 1,
          'unit': 'pieces',
          'value': 7,
          'at': '2020-01-01T00:00:00',
        });
        for (var n = 0; n < 5001; n++) {
          b.insert('activity', <String, Object?>{
            'homeId': 'main',
            'actor': 'Me',
            'action': 'used',
            'name': 'Rice',
            'quantity': 1,
            'unit': 'pieces',
            'value': 2,
            'at': DateTime.now().toIso8601String(),
          });
        }
        await b.commit(noResult: true);
      });
      final stats = await data.getInsights(homeId: 'main');
      expect(stats.wastedValue, 7);
      expect(stats.mostUsed.single['quantity'], 5001);
      expect((await data.getInsights(homeId: 'other')).wastedValue, 0);
    });
    test(
      'minimum-stock shopping can be edited, completed and dismissed',
      () async {
        final item = await pantry.addBatch(
          batch(batchId: 'min', quantity: 1, minimum: 2),
        );
        await pantry.setShoppingItemChecked(pantry.shoppingItems.single, true);
        expect(pantry.shoppingItemsToBuy, 0);
        await pantry.clearCheckedShoppingItems();
        expect(pantry.shoppingItems, isEmpty);
        await pantry.changeQuantity(item, 1);
        await pantry.changeQuantity(item, -1);
        expect(pantry.shoppingItems.single.quantity, 1);
        await pantry.updateShoppingItem(
          pantry.shoppingItems.single.copyWith(quantity: 3),
        );
        expect(pantry.shoppingItems.single.quantity, 3);
        await pantry.removeShoppingItem(pantry.shoppingItems.single);
        expect(pantry.shoppingItems, isEmpty);
        expect(pantry.items.single.minimumStock, 2);
      },
    );
    test(
      'scans complete shopping amounts gradually and save purchase history',
      () async {
        await pantry.addShoppingItem('Milk', barcode: 'milk', quantity: 2);
        final first = await pantry.onBarcodeScanned(
          'milk',
          lookUpProduct: false,
        );
        expect(first!.checkedOffShoppingList, isFalse);
        expect(first.item.name, 'Milk');
        expect(pantry.shoppingItems.single.quantity, 1);
        expect(pantry.shoppingItems.single.isChecked, isFalse);
        final second = await pantry.onBarcodeScanned(
          'milk',
          lookUpProduct: false,
        );
        expect(second!.checkedOffShoppingList, isTrue);
        expect(pantry.shoppingItems.single.isChecked, isTrue);
        expect(
          pantry.records.where((r) => r.kind == 'purchase').single.data['name'],
          'Milk',
        );
      },
    );
    test('undo restores exact batch and removes waste accounting', () async {
      final item = await pantry.addBatch(batch(batchId: 'a'));
      final removed = await pantry.removeItem(item, wasted: true);
      expect(
        pantry.activity.where((a) => a.action == 'wasted').single.value,
        6,
      );
      await pantry.restoreItem(removed);
      expect(pantry.items.single.batchKey, 'a');
      expect(pantry.activity.where((a) => a.action == 'wasted'), isEmpty);
    });
    test(
      'writes are serialized and increments cannot overwrite each other',
      () async {
        final item = await pantry.addBatch(batch(batchId: 'a', quantity: 1));
        await Future.wait([
          for (var i = 0; i < 10; i++) pantry.changeQuantity(item, 1),
        ]);
        expect(pantry.items.single.quantity, 11);
      },
    );
    test('batch imports are idempotent and invalid import is atomic', () async {
      await pantry.importItems([
        batch(batchId: 'a'),
        batch(batchId: 'b'),
      ], replaceAll: false);
      await pantry.importItems([
        batch(batchId: 'a', quantity: 7),
      ], replaceAll: false);
      expect(pantry.items, hasLength(2));
      expect(pantry.items.firstWhere((i) => i.batchId == 'a').quantity, 7);
      await expectLater(
        pantry.importItems([
          batch(batchId: 'c'),
          batch(quantity: -1),
        ], replaceAll: true),
        throwsFormatException,
      );
      expect(await data.getAllItems(), hasLength(2));
    });
    test('purchase history and profiles remain scoped to a home', () async {
      await pantry.addShoppingItem('Oats', quantity: 2, aisle: 'Dry goods');
      await pantry.setShoppingItemChecked(pantry.shoppingItems.single, true);
      await pantry.clearCheckedShoppingItems();
      expect(
        pantry.records.where((r) => r.kind == 'purchase').single.data['name'],
        'Oats',
      );
      await pantry.saveRecord(
        const HouseholdRecord(
          kind: 'profile',
          homeId: 'main',
          data: {'name': 'Guest', 'allergies': 'milk, nuts'},
        ),
      );
      expect(
        pantry.allergyWarnings(batch().copyWith(allergens: ['milk'])),
        contains('Guest: milk'),
      );
      expect(
        pantry.allergyWarnings(
          batch(home: 'second').copyWith(allergens: ['milk']),
        ),
        isEmpty,
      );
    });
    test(
      '5000 batches use bounded, indexed pages without duplicate rows',
      () async {
        final watch = Stopwatch()..start();
        await db.transaction((txn) async {
          final insert = txn.batch();
          for (var n = 0; n < 5000; n++) {
            insert.insert(
              'pantry_items',
              batch(
                batchId: 'perf-$n',
                barcode: 'Product ${n.toString().padLeft(4, '0')}',
              ).toMap(),
            );
          }
          await insert.commit(noResult: true);
        });
        final a = await data.getItemsPage();
        final b = await data.getItemsPage(offset: 60);
        expect(a, hasLength(60));
        expect(b, hasLength(60));
        expect({...a.map((i) => i.id), ...b.map((i) => i.id)}, hasLength(120));
        expect(await data.getItemsPage(query: 'Product 4999'), hasLength(1));
        expect(watch.elapsed, lessThan(const Duration(seconds: 15)));
      },
    );
  });

  for (final version in [1, 2, 3]) {
    test(
      'migration from schema v$version preserves inventory and shopping',
      () async {
        final dir = await Directory.systemTemp.createTemp('pantry-migration-');
        final path = '${dir.path}/test.db';
        var db = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: (db, v) async {
              await db.execute(
                'CREATE TABLE pantry_items (id INTEGER PRIMARY KEY, barcode TEXT NOT NULL UNIQUE, name TEXT NOT NULL, imageUrl TEXT, quantity INTEGER NOT NULL, expirationDate TEXT NOT NULL)',
              );
              await db.insert('pantry_items', {
                'id': 42,
                'barcode': 'milk',
                'name': 'Milk',
                'quantity': 3,
                'imageUrl': 'https://example.com/milk.jpg',
                'expirationDate': '2030-01-01',
              });
              if (v >= 2) {
                await db.execute(
                  'CREATE TABLE shopping_items (id INTEGER PRIMARY KEY, name TEXT NOT NULL, barcode TEXT, isChecked INTEGER DEFAULT 0${v >= 3 ? ', imageUrl TEXT, quantity INTEGER DEFAULT 1' : ''})',
                );
                await db.insert('shopping_items', {
                  'id': 8,
                  'name': 'Milk',
                  'barcode': 'milk',
                  'isChecked': 0,
                });
              }
            },
          ),
        );
        await db.close();
        db = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 4,
            onUpgrade: DatabaseHelper.migrate,
          ),
        );
        final data = DatabaseHelper.forDatabase(db);
        expect((await data.getAllItems()).single.id, 42);
        expect((await data.getAllItems()).single.quantity, 3);
        await data.insertItem(batch(batchId: 'new'));
        expect(await data.getAllItems(), hasLength(2));
        if (version >= 2) {
          expect(
            (await data.getShoppingItems()).single.imageUrl,
            'https://example.com/milk.jpg',
          );
          expect((await data.getShoppingItems()).single.quantity, 1);
        }
        expect(await data.getHomes(), hasLength(1));
        await db.close();
        await dir.delete(recursive: true);
      },
    );
  }

  group('Adding and planning', () {
    test('OCR dates reject impossible dates and expose ambiguous orders', () {
      expect(parseExpiryDates('Best before 31/02/2027'), isEmpty);
      expect(parseExpiryDates('BB 2027-12-24'), [DateTime(2027, 12, 24)]);
      expect(parseExpiryDates('BB 24 OCT 2027'), [DateTime(2027, 10, 24)]);
      expect(
        parseExpiryDates('03/04/27'),
        containsAll([DateTime(2027, 4, 3), DateTime(2027, 3, 4)]),
      );
    });
    test(
      'receipt parser separates amount and unit price and ignores totals',
      () {
        final lines = parseReceipt(
          '2 x Milk 3.60\nOats 2,50\nTOTAL 6.10\nVAT 0.20\nCARD 6.10',
        );
        expect(lines, hasLength(2));
        expect(lines.first.name, 'Milk');
        expect(lines.first.quantity, 2);
        expect(lines.first.unitPrice, 1.8);
      },
    );
    test(
      'event planning converts compatible units and excludes expired food',
      () {
        final req = parseRequirements(
          'milk | 2 | l\nmilk | 1 | l\nEggs | 2 | pieces',
        );
        final missing = missingIngredients(req, [
          batch(quantity: 500, unit: 'ml'),
          batch(barcode: 'Eggs', quantity: 2, expiry: DateTime(2001)),
        ], 'main');
        expect(missing.first['quantity'], 2.5);
        expect(missing.last['quantity'], 2);
        expect(
          () => parseRequirements('Rice | -2 | kg'),
          throwsFormatException,
        );
        expect(convertAmount(1, 'kg', 'ml'), isNull);
      },
    );
    test('quiet hours work overnight and within a day', () {
      expect(
        outsideQuietHours(DateTime(2026, 10, 27, 23), 22, 8),
        DateTime(2026, 10, 28, 8),
      );
      expect(
        outsideQuietHours(DateTime(2026, 10, 27, 7), 22, 8),
        DateTime(2026, 10, 27, 8),
      );
      expect(
        outsideQuietHours(DateTime(2026, 10, 27, 13), 12, 15),
        DateTime(2026, 10, 27, 15),
      );
    });
    test('reminders obey preferences and stay below platform limit', () async {
      final settings = SettingsProvider();
      final now = DateTime(2026, 10, 27, 6);
      final items = [batch(expiry: DateTime(2026, 10, 28))];
      expect(planReminders(items, settings, now), isEmpty);
      await settings.setExtra('remindersEnabled', true);
      expect(planReminders(items, settings, now).first.at.hour, 9);
      await settings.setExtra('dailyDigest', false);
      await settings.setExtra('reminderHour', 23);
      expect(
        planReminders(items, settings, now).single.at,
        DateTime(2026, 10, 28, 8),
      );
      settings.dispose();
    });
    test('settings persist theme and household controls', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsProvider.load();
      expect(settings.onboardingComplete, isFalse);
      settings.themeMode = ThemeMode.dark;
      await settings.setExtra('actorName', 'Alex');
      await settings.setExtra('onboardingComplete', true);
      final loaded = await SettingsProvider.load();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.actorName, 'Alex');
      expect(loaded.onboardingComplete, isTrue);
    });
    test(
      'API v2 parses dietary data and falls back when product is missing',
      () async {
        final hosts = <String>[];
        final api = ApiService(
          client: MockClient((request) async {
            hosts.add(request.url.host);
            expect(request.url.path, contains('/api/v2/product/'));
            return request.url.host == ApiService.hosts.first
                ? http.Response('{"status":0}', 404)
                : http.Response(
                  '{"product":{"product_name":"Soap","categories":"Cleaning","allergens_tags":["en:milk"],"ingredients_text":"milk","nutriments":{"salt_100g":1}}}',
                  200,
                );
          }),
        );
        final result = await api.fetchProductByBarcode('123');
        expect(hosts, ApiService.hosts);
        expect(result['product_name'], 'Soap');
        expect(result['category'], 'Cleaning');
        expect(result['allergens'], 'milk');
        expect(result['nutrition'], contains('1 g salt'));
      },
    );
  });
}

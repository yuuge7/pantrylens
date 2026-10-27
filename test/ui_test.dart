import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pantrylens/database_helper.dart';
import 'package:pantrylens/main.dart';
import 'package:pantrylens/pantry_item.dart';
import 'package:pantrylens/pantry_provider.dart';
import 'package:pantrylens/settings_provider.dart';
import 'package:pantrylens/screens/item_sheet.dart';
import 'package:pantrylens/features/household/household_screen.dart';
import 'package:pantrylens/features/insights/insights_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late PantryProvider pantry;
  late SettingsProvider settings;
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'PantryLens',
      packageName: 'com.pantrylens.pantrylens',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: DatabaseHelper.createSchema,
      ),
    );
    pantry = PantryProvider(databaseHelper: DatabaseHelper.forDatabase(db));
    settings = SettingsProvider();
    await pantry.loadItems();
    await pantry.addBatch(
      PantryItem(
        barcode: 'test',
        name: 'Natural yogurt',
        quantity: 0.5,
        unit: 'kg',
        location: 'Fridge',
        expirationDate: DateTime.now().add(const Duration(days: 2)),
      ),
    );
  });
  tearDown(() async {
    pantry.dispose();
    settings.dispose();
    await db.close();
  });
  Widget app({Widget? screen}) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: pantry),
      ChangeNotifierProvider.value(value: settings),
    ],
    child: screen == null ? const MyApp() : MaterialApp(home: screen),
  );
  for (final (size, scale) in [
    (const Size(400, 900), 1.0),
    (const Size(400, 900), 2.0),
    (const Size(1280, 900), 1.0),
    (const Size(900, 450), 1.3),
  ]) {
    testWidgets('home and inventory fit $size at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(app());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final nav = find.byType(
        size.width >= 840 ? NavigationRail : NavigationBar,
      );
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Inventory')),
      );
      await tester
          .pump(); // Mount the lazy tab before allowing native FFI work.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Natural yogurt'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
    });
  }
  testWidgets('batch editor validates amounts and saves a fraction', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        screen: Scaffold(
          body: ItemSheet(
            itemId: pantry.items.single.id,
            initialItem: pantry.items.single,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    final amount = find.widgetWithText(TextFormField, 'Amount');
    await tester.enterText(amount, '0');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount above 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  });
  testWidgets('usage reports load and fit large text', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(app(screen: const InsightsScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Recorded waste'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('household empty task state gives a clear action', (
    tester,
  ) async {
    await tester.pumpWidget(app(screen: const HouseholdScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasks'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  });
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pantrylens/database_helper.dart';
import 'package:pantrylens/main.dart';
import 'package:pantrylens/pantry_item.dart';
import 'package:pantrylens/pantry_provider.dart';
import 'package:pantrylens/settings_provider.dart';
import 'package:pantrylens/features/adding/document_scan_screen.dart';
import 'package:pantrylens/features/adding/text_parsers.dart';
import 'package:pantrylens/features/household/household_models.dart';
import 'package:pantrylens/features/household/household_screen.dart';
import 'package:pantrylens/services/reminder_service.dart';
import 'package:pantrylens/services/widget_service.dart';

Widget app(
  PantryProvider pantry,
  SettingsProvider settings, {
  Widget? screen,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: pantry),
    ChangeNotifierProvider.value(value: settings),
  ],
  child: screen == null ? const MyApp() : MaterialApp(home: screen),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native OCR reads a package date and a receipt', (tester) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1200, 500),
      Paint()..color = Colors.white,
    );
    final painter = TextPainter(
      text: const TextSpan(
        text: 'BEST BEFORE 24/12/2027\n2 x Milk 3.60\nOats 2.50\nTOTAL 6.10',
        style: TextStyle(
          fontSize: 56,
          color: Colors.black,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 1100);
    painter.paint(canvas, const Offset(40, 40));
    final image = await recorder.endRecording().toImage(1200, 500);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      '${(await getTemporaryDirectory()).path}/ocr-integration.png',
    );
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      expect(parseExpiryDates(result.text), contains(DateTime(2027, 12, 24)));
      expect(
        parseReceipt(result.text).map((r) => r.name),
        containsAll(['Milk', 'Oats']),
      );
    } finally {
      await recognizer.close();
      await file.delete();
      image.dispose();
      painter.dispose();
    }
  });

  testWidgets('receipt review adds selected lines as real batches', (
    tester,
  ) async {
    final pantry = PantryProvider();
    final settings = SettingsProvider();
    await pantry.loadItems();
    final before = pantry.allItems.map((i) => i.id).toSet();
    await tester.pumpWidget(
      app(pantry, settings, screen: const DocumentScanScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      '2 x Roadmap Milk 3.60\nRoadmap Oats 2.50\nTOTAL 6.10',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add 2 items'));
    await tester.tap(find.text('Add 2 items'));
    await tester.pumpAndSettle();
    final added = pantry.allItems.where((i) => !before.contains(i.id)).toList();
    expect(added, hasLength(2));
    expect(added.firstWhere((i) => i.name == 'Roadmap Milk').quantity, 2);
    for (final i in added) {
      await DatabaseHelper.instance.deleteItem(i.id!);
    }
    await tester.pumpWidget(const SizedBox());
    pantry.dispose();
    settings.dispose();
  });

  testWidgets(
    'multi-home batches, FIFO, tasks, profiles and widget data persist',
    (tester) async {
      final pantry = PantryProvider();
      final settings = SettingsProvider();
      await pantry.loadItems();
      final stamp = 'roadmap-${DateTime.now().microsecondsSinceEpoch}';
      final home = Home(
        id: stamp,
        name: 'Emulator guest house',
        locations: const ['Guest fridge', 'Garage'],
      );
      await pantry.saveHome(home);
      pantry.selectHome(stamp);
      final early = await pantry.addBatch(
        PantryItem(
          batchId: '$stamp-a',
          barcode: stamp,
          name: 'Roadmap olive oil',
          quantity: 0.5,
          unit: 'bottle',
          minimumStock: 1,
          homeId: stamp,
          location: 'Guest fridge',
          price: 10,
          expirationDate: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await pantry.addBatch(
        early.copyWith(
          batchId: '$stamp-b',
          quantity: 1,
          expirationDate: DateTime.now().add(const Duration(days: 20)),
        ),
      );
      await pantry.useProduct(stamp, 0.75, homeId: stamp, unit: 'bottle');
      expect(pantry.items.single.quantity, 0.75);
      expect(pantry.shoppingItems.single.quantity, 0.25);
      await pantry.saveRecord(
        HouseholdRecord(
          kind: 'task',
          homeId: stamp,
          data: {
            'name': 'Restock guest fridge',
            'assignee': 'Alex',
            'steps': [
              {'text': 'Buy olive oil', 'done': false},
            ],
          },
        ),
      );
      await pantry.saveRecord(
        HouseholdRecord(
          kind: 'profile',
          homeId: stamp,
          data: {'name': 'Visitor', 'allergies': 'milk', 'favorites': 'Oats'},
        ),
      );
      await pantry.saveRecord(
        HouseholdRecord(
          kind: 'event',
          homeId: stamp,
          data: {
            'name': 'Friday dinner',
            'requirements': [
              {'name': 'Roadmap olive oil', 'quantity': 2, 'unit': 'bottle'},
            ],
          },
        ),
      );
      await pantry.loadItems();
      expect(pantry.records, hasLength(3));
      await WidgetService.sync(pantry, settings);
      expect(
        await HomeWidget.getWidgetData<String>('shopping'),
        contains('Roadmap olive oil'),
      );
      await tester.pumpWidget(
        app(pantry, settings, screen: const HouseholdScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Restock guest fridge'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await pantry.pendingChanges;
      await tester.pumpAndSettle();
      expect(
        (pantry.records.firstWhere((r) => r.kind == 'task').data['steps']
                as List)
            .first['done'],
        isTrue,
      );
      await tester.tap(find.text('Guests'));
      await tester.pumpAndSettle();
      expect(find.text('Allergies: milk'), findsOneWidget);
      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Missing:'), findsOneWidget);
      await tester.tap(find.text('Shop missing ingredients'));
      await tester.pumpAndSettle();
      expect(
        pantry.shoppingItems.where((i) => i.name == 'Roadmap olive oil'),
        isNotEmpty,
      );
      expect(pantry.shoppingItems.single.quantity, 1.25);
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        for (final table in [
          'pantry_items',
          'shopping_items',
          'household_records',
          'stock_rules',
          'activity',
        ]) {
          await txn.delete(table, where: 'homeId=?', whereArgs: [stamp]);
        }
        await txn.delete('homes', where: 'id=?', whereArgs: [stamp]);
      });
      await tester.pumpWidget(const SizedBox());
      pantry.dispose();
      settings.dispose();
    },
  );

  testWidgets('minimum-stock shopping remains editable and completed', (
    tester,
  ) async {
    final pantry = PantryProvider();
    final settings = SettingsProvider();
    await pantry.loadItems();
    final stamp = 'min-shopping-${DateTime.now().microsecondsSinceEpoch}';
    await pantry.saveHome(Home(id: stamp, name: 'Minimum stock fixture'));
    pantry.selectHome(stamp);
    await pantry.addBatch(
      PantryItem(
        barcode: stamp,
        name: 'Minimum stock test',
        quantity: 1,
        minimumStock: 2,
        homeId: stamp,
        expirationDate: DateTime(2030),
      ),
    );
    await tester.pumpWidget(app(pantry, settings));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Shopping'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add one of Minimum stock test'));
    await pantry.pendingChanges;
    await tester.pumpAndSettle();
    expect(pantry.shoppingItems.single.quantity, 2);
    await tester.tap(find.byType(Checkbox));
    await pantry.pendingChanges;
    await tester.pumpAndSettle();
    expect(pantry.shoppingItemsToBuy, 0);
    await pantry.clearCheckedShoppingItems();
    expect(pantry.shoppingItems, isEmpty);
    await tester.pumpWidget(const SizedBox());
    final db = await pantry.data.database;
    await db.transaction((txn) async {
      for (final table in [
        'pantry_items',
        'shopping_items',
        'household_records',
        'stock_rules',
        'activity',
      ]) {
        await txn.delete(table, where: 'homeId=?', whereArgs: [stamp]);
      }
      await txn.delete('homes', where: 'id=?', whereArgs: [stamp]);
    });
    pantry.dispose();
    settings.dispose();
  });
  testWidgets('native reminders are scheduled and canceled', (tester) async {
    final settings = SettingsProvider();
    await settings.setExtra('remindersEnabled', true);
    final item = PantryItem(
      barcode: 'reminder-test',
      name: 'Reminder test',
      quantity: 1,
      expirationDate: DateTime.now().add(const Duration(days: 3)),
    );
    await ReminderService.instance.sync([item], settings);
    expect(
      await ReminderService.instance.plugin.pendingNotificationRequests(),
      isNotEmpty,
    );
    await settings.setExtra('remindersEnabled', false);
    await ReminderService.instance.sync([item], settings);
    expect(
      await ReminderService.instance.plugin.pendingNotificationRequests(),
      isEmpty,
    );
    settings.dispose();
  });

  testWidgets('5000 batches browse through bounded pages on emulator', (
    tester,
  ) async {
    final pantry = PantryProvider();
    final settings = SettingsProvider();
    await pantry.loadItems();
    final stamp = 'perf-${DateTime.now().microsecondsSinceEpoch}';
    await pantry.saveHome(Home(id: stamp, name: 'Performance fixture'));
    pantry.selectHome(stamp);
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final b = txn.batch();
      for (var n = 0; n < 5000; n++) {
        b.insert(
          'pantry_items',
          PantryItem(
            batchId: '$stamp-$n',
            barcode: '$stamp-$n',
            name: 'Pantry item ${n.toString().padLeft(4, '0')}',
            quantity: 1,
            homeId: stamp,
            expirationDate: DateTime(2030),
          ).toMap(),
        );
      }
      await b.commit(noResult: true);
    });
    final watch = Stopwatch()..start();
    final page = await pantry.data.getItemsPage(homeId: stamp);
    watch.stop();
    expect(page, hasLength(60));
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    await pantry.loadItems();
    await tester.pumpWidget(app(pantry, settings));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Inventory'),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(ListView).hitTestable().last;
    final timings = <ui.FrameTiming>[];
    void onTimings(List<ui.FrameTiming> frames) => timings.addAll(frames);
    binding.addTimingsCallback(onTimings);
    Future<void> scroll() async {
      await tester.fling(list, const Offset(0, -2400), 2400);
      await tester.pumpAndSettle();
    }

    if (const bool.fromEnvironment('CAPTURE_TIMELINE')) {
      await binding.traceAction(scroll, reportKey: 'inventory_5000_scroll');
    } else {
      await scroll();
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    binding.removeTimingsCallback(onTimings);
    final builds =
        timings.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
          ..sort();
    final rasters =
        timings.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
          ..sort();
    final stats = {
      'queryMilliseconds': watch.elapsedMicroseconds / 1000,
      'frames': timings.length,
      'p90BuildMilliseconds':
          builds.isEmpty ? 0 : builds[((builds.length - 1) * 0.9).floor()],
      'p90RasterMilliseconds':
          rasters.isEmpty ? 0 : rasters[((rasters.length - 1) * 0.9).floor()],
    };
    binding.reportData = {...?(binding.reportData), 'inventory5000': stats};
    debugPrint('Inventory performance: $stats');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.delete('pantry_items', where: 'homeId=?', whereArgs: [stamp]);
    await db.delete('homes', where: 'id=?', whereArgs: [stamp]);
    pantry.dispose();
    settings.dispose();
  });
}

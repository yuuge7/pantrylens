import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'features/household/household_models.dart';
import 'features/insights/insights_data.dart';
import 'pantry_item.dart';
import 'shopping_item.dart';

class PantrySnapshot {
  const PantrySnapshot(
    this.items,
    this.shopping,
    this.homes,
    this.records,
    this.activity,
  );
  final List<PantryItem> items;
  final List<ShoppingItem> shopping;
  final List<Home> homes;
  final List<HouseholdRecord> records;
  final List<Activity> activity;
}

class DatabaseHelper {
  DatabaseHelper._internal();
  DatabaseHelper.forDatabase(Database db) : _databaseFuture = Future.value(db);
  static final instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  static const version = 4;
  Future<Database>? _databaseFuture;
  Future<Database> get database => _databaseFuture ??= _open();

  Future<Database> _open() async => openDatabase(
    p.join((await getApplicationDocumentsDirectory()).path, 'pantrylens.db'),
    version: version,
    onCreate: createSchema,
    onUpgrade: migrate,
  );

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      '''CREATE TABLE pantry_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, batchId TEXT NOT NULL UNIQUE,
      barcode TEXT NOT NULL, name TEXT NOT NULL, imageUrl TEXT,
      quantity REAL NOT NULL CHECK(quantity > 0), expirationDate TEXT NOT NULL,
      unit TEXT NOT NULL DEFAULT 'pieces', homeId TEXT NOT NULL DEFAULT 'main',
      location TEXT NOT NULL DEFAULT 'Pantry', category TEXT NOT NULL DEFAULT 'Other',
      tags TEXT NOT NULL DEFAULT '[]', openedDate TEXT, daysAfterOpening INTEGER,
      minimumStock REAL NOT NULL DEFAULT 0, price REAL NOT NULL DEFAULT 0,
      store TEXT NOT NULL DEFAULT '', ingredients TEXT NOT NULL DEFAULT '',
      allergens TEXT NOT NULL DEFAULT '[]', nutrition TEXT NOT NULL DEFAULT '')''',
    );
    await _createShopping(db);
    await _createHousehold(db);
  }

  static Future<void> _createShopping(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE shopping_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, barcode TEXT,
      imageUrl TEXT, quantity REAL NOT NULL DEFAULT 1 CHECK(quantity > 0),
      isChecked INTEGER NOT NULL DEFAULT 0, unit TEXT NOT NULL DEFAULT 'pieces',
      homeId TEXT NOT NULL DEFAULT 'main', aisle TEXT NOT NULL DEFAULT 'Other',
      store TEXT NOT NULL DEFAULT '', automatic INTEGER NOT NULL DEFAULT 0)''');
  }

  static Future<void> _createHousehold(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE homes (id TEXT PRIMARY KEY, name TEXT NOT NULL, locations TEXT NOT NULL)',
    );
    await db.insert('homes', const Home(id: 'main', name: 'My home').toMap());
    await db.execute('''CREATE TABLE household_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
      homeId TEXT NOT NULL, data TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE activity (
      id INTEGER PRIMARY KEY AUTOINCREMENT, homeId TEXT NOT NULL,
      actor TEXT NOT NULL, action TEXT NOT NULL, name TEXT NOT NULL,
      quantity REAL NOT NULL, unit TEXT NOT NULL, value REAL NOT NULL,
      at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE stock_rules (
      barcode TEXT NOT NULL, homeId TEXT NOT NULL, unit TEXT NOT NULL,
      name TEXT NOT NULL, minimum REAL NOT NULL, aisle TEXT NOT NULL,
      imageUrl TEXT, store TEXT NOT NULL, PRIMARY KEY(barcode,homeId,unit))''');
    await db.execute(
      'CREATE INDEX inventory_home_name ON pantry_items(homeId, name COLLATE NOCASE, id)',
    );
    await db.execute(
      'CREATE INDEX inventory_barcode ON pantry_items(barcode,homeId)',
    );
    await db.execute(
      'CREATE INDEX inventory_expiry ON pantry_items(expirationDate)',
    );
    await db.execute('CREATE INDEX activity_home_at ON activity(homeId,at)');
    await db.execute(
      'CREATE INDEX records_home_kind ON household_records(homeId,kind)',
    );
    await db.execute(
      'CREATE INDEX shopping_home ON shopping_items(homeId,isChecked)',
    );
  }

  /// Rebuilds old tables to remove barcode uniqueness without losing row IDs.
  /// v1 had no shopping list; v2 lacked shopping photos and amounts.
  static Future<void> migrate(Database db, int old, int next) async {
    if (old >= 4) return;
    final pantry = await db.query('pantry_items');
    final shopping =
        old >= 2 ? await db.query('shopping_items') : <Map<String, Object?>>[];
    await db.execute('DROP TABLE pantry_items');
    if (old >= 2) await db.execute('DROP TABLE shopping_items');
    await createSchema(db, next);
    for (final row in pantry) {
      final item = PantryItem.fromMap(
        row,
      ).copyWith(batchId: 'legacy-${row['id']}');
      await db.insert('pantry_items', item.toMap());
    }
    for (final row in shopping) {
      final item = ShoppingItem.fromMap(row);
      final photo =
          pantry
              .where((p) => p['barcode'] == item.barcode)
              .firstOrNull?['imageUrl'];
      await db.insert('shopping_items', {
        ...item.toMap(),
        'imageUrl': item.imageUrl ?? photo,
      });
    }
  }

  Map<String, Object?> _values(Map<String, Object?> map) => map..remove('id');

  /// A consistent snapshot with one native batch call instead of five round trips.
  Future<PantrySnapshot> getSnapshot() async {
    final db = await database;
    final results = await db.transaction((txn) async {
      final batch =
          txn.batch()
            ..query('pantry_items', orderBy: 'name COLLATE NOCASE, id')
            ..query(
              'shopping_items',
              orderBy: 'isChecked, aisle COLLATE NOCASE, name COLLATE NOCASE',
            )
            ..query('homes')
            ..query('household_records', orderBy: 'id DESC')
            ..query('activity', orderBy: 'at DESC, id DESC', limit: 5000);
      return batch.commit();
    });
    List<Map<String, Object?>> rows(int n) =>
        (results[n] as List)
            .map((r) => Map<String, Object?>.from(r as Map))
            .toList();
    return PantrySnapshot(
      rows(0).map(PantryItem.fromMap).toList(),
      rows(1).map(ShoppingItem.fromMap).toList(),
      rows(2).map(Home.fromMap).toList(),
      rows(3).map(HouseholdRecord.fromMap).toList(),
      rows(4).map(Activity.fromMap).toList(),
    );
  }

  Future<int> insertItem(PantryItem item) async {
    item.validate();
    return (await database).insert('pantry_items', _values(item.toMap()));
  }

  Future<int> updateItem(PantryItem item) async {
    item.validate();
    if (item.id == null) throw ArgumentError('Missing batch id');
    return (await database).update(
      'pantry_items',
      _values(item.toMap()),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async =>
      (await database).delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteAllItems({String? homeId}) async => (await database).delete(
    'pantry_items',
    where: homeId == null ? null : 'homeId = ?',
    whereArgs: homeId == null ? null : [homeId],
  );
  Future<void> importItems(
    List<PantryItem> items, {
    required bool replaceAll,
  }) async {
    for (final item in items) {
      item.validate();
    }
    await (await database).transaction((txn) async {
      if (replaceAll) {
        await txn.delete('pantry_items');
        await txn.delete('stock_rules');
        await txn.delete(
          'shopping_items',
          where: 'automatic=1 AND isChecked=0',
        );
      }
      for (final item in items) {
        await txn.insert(
          'pantry_items',
          _values(item.toMap()),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'homes',
          Home(
            id: item.homeId,
            name: item.homeId == 'main' ? 'My home' : item.homeId,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<PantryItem?> getItemByBarcode(String barcode, {String? homeId}) async {
    final rows = await (await database).query(
      'pantry_items',
      where: homeId == null ? 'barcode = ?' : 'barcode = ? AND homeId = ?',
      whereArgs: [barcode, if (homeId != null) homeId],
      orderBy: 'expirationDate ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : PantryItem.fromMap(rows.first);
  }

  Future<List<PantryItem>> getAllItems() async =>
      (await (await database).query(
        'pantry_items',
        orderBy: 'name COLLATE NOCASE, id',
      )).map(PantryItem.fromMap).toList();

  /// Bounded reads for inventory browsing. SQL values always use bindings.
  Future<List<PantryItem>> getItemsPage({
    int offset = 0,
    int limit = 60,
    String? homeId,
    String query = '',
    String? location,
    String? category,
    String filter = 'all',
    int useSoonDays = 7,
    String sort = 'name',
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (homeId != null) {
      clauses.add('homeId = ?');
      args.add(homeId);
    }
    if (query.isNotEmpty) {
      clauses.add(
        r"(name LIKE ? ESCAPE '\' OR barcode LIKE ? ESCAPE '\' OR tags LIKE ? ESCAPE '\')",
      );
      args.addAll(
        List.filled(
          3,
          '%${query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%',
        ),
      );
    }
    if (location != null) {
      clauses.add('location = ?');
      args.add(location);
    }
    if (category != null) {
      clauses.add('category = ?');
      args.add(category);
    }
    if (filter != 'all') {
      clauses.add(
        "date(CASE WHEN openedDate IS NOT NULL AND daysAfterOpening IS NOT NULL THEN min(expirationDate, datetime(openedDate, '+' || daysAfterOpening || ' days')) ELSE expirationDate END) ${filter == 'expired' ? '<' : '<='} date(?)",
      );
      final n = DateTime.now();
      args.add(
        DateTime(
          n.year,
          n.month,
          n.day + (filter == 'expired' ? 0 : useSoonDays),
        ).toIso8601String(),
      );
    }
    final order = switch (sort) {
      'expiry' =>
        "CASE WHEN openedDate IS NOT NULL AND daysAfterOpening IS NOT NULL THEN min(expirationDate, datetime(openedDate, '+' || daysAfterOpening || ' days')) ELSE expirationDate END",
      'quantity' => 'quantity DESC',
      'recent' => 'id DESC',
      _ => 'name COLLATE NOCASE',
    };
    return (await (await database).query(
      'pantry_items',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: '$order, id',
      offset: offset,
      limit: limit.clamp(1, 200),
    )).map(PantryItem.fromMap).toList();
  }

  Future<List<ShoppingItem>> getShoppingItems() async =>
      (await (await database).query(
        'shopping_items',
        orderBy: 'isChecked, aisle COLLATE NOCASE, name COLLATE NOCASE',
      )).map(ShoppingItem.fromMap).toList();
  Future<int> insertShoppingItem(ShoppingItem item) async =>
      (await database).insert('shopping_items', _values(item.toMap()));
  Future<int> updateShoppingItem(ShoppingItem item) async {
    if (item.id == null ||
        !item.quantity.isFinite ||
        item.quantity <= 0 ||
        item.name.trim().isEmpty)
      throw ArgumentError('Invalid shopping entry');
    return (await database).update(
      'shopping_items',
      _values(item.toMap()),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteShoppingItem(int id) async => (await database).delete(
    'shopping_items',
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<int> deleteCheckedShoppingItems({String? homeId}) async =>
      (await database).delete(
        'shopping_items',
        where: 'isChecked = 1${homeId == null ? '' : ' AND homeId = ?'}',
        whereArgs: homeId == null ? [] : [homeId],
      );
  Future<int> deleteAllShoppingItems({String? homeId}) async =>
      (await database).delete(
        'shopping_items',
        where: homeId == null ? null : 'homeId = ?',
        whereArgs: homeId == null ? null : [homeId],
      );
  Future<List<Home>> getHomes() async =>
      (await (await database).query('homes')).map(Home.fromMap).toList();
  Future<void> saveHome(Home h) async => (await database).insert(
    'homes',
    h.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<List<HouseholdRecord>> getRecords() async =>
      (await (await database).query(
        'household_records',
        orderBy: 'id DESC',
      )).map(HouseholdRecord.fromMap).toList();
  Future<void> saveRecord(HouseholdRecord r) async => (await database).insert(
    'household_records',
    r.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<void> deleteRecord(int id) async => (await database).delete(
    'household_records',
    where: 'id = ?',
    whereArgs: [id],
  );
  Future<List<Activity>> getActivity({int limit = 5000}) async =>
      (await (await database).query(
        'activity',
        orderBy: 'at DESC, id DESC',
        limit: limit,
      )).map(Activity.fromMap).toList();

  /// Aggregate all stored history; the activity feed's page limit never truncates reports.
  Future<PantryInsights> getInsights({String? homeId}) async {
    final home = homeId == null ? '' : ' AND homeId=?';
    final args = <Object?>[if (homeId != null) homeId];
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - 5).toIso8601String();
    final db = await database;
    final batch =
        db.batch()
          ..rawQuery(
            "SELECT COALESCE(SUM(value),0) AS wasted FROM activity WHERE action='wasted'$home",
            args,
          )
          ..rawQuery(
            "SELECT substr(at,1,7) AS month, SUM(CASE WHEN action='used' THEN value ELSE 0 END) AS used, SUM(CASE WHEN action='wasted' THEN value ELSE 0 END) AS wasted FROM activity WHERE at>=?$home GROUP BY substr(at,1,7)",
            [since, ...args],
          )
          ..rawQuery(
            "SELECT name,unit,SUM(quantity) AS quantity FROM activity WHERE action='used'$home GROUP BY name,unit ORDER BY quantity DESC LIMIT 10",
            args,
          );
    final results = await batch.commit();
    List<Map<String, Object?>> rows(int n) =>
        (results[n] as List)
            .map((r) => Map<String, Object?>.from(r as Map))
            .toList();
    return PantryInsights(
      wastedValue: rows(0).single['wasted'] as num,
      months: rows(1),
      mostUsed: rows(2),
    );
  }

  Future<int> log(Activity activity, {DatabaseExecutor? txn}) async =>
      (txn ?? await database).insert('activity', _values(activity.toMap()));

  Future<void> saveStockRule(PantryItem item) async {
    final db = await database;
    await db.update(
      'pantry_items',
      {'minimumStock': item.minimumStock},
      where: 'barcode=? AND homeId=? AND unit=?',
      whereArgs: [item.barcode, item.homeId, item.unit],
    );
    if (item.minimumStock <= 0) {
      await db.transaction((txn) async {
        await txn.delete(
          'stock_rules',
          where: 'barcode=? AND homeId=? AND unit=?',
          whereArgs: [item.barcode, item.homeId, item.unit],
        );
        await txn.delete(
          'shopping_items',
          where:
              'barcode=? AND homeId=? AND unit=? AND automatic=1 AND isChecked=0',
          whereArgs: [item.barcode, item.homeId, item.unit],
        );
      });
      return;
    }
    await db.insert('stock_rules', {
      'barcode': item.barcode,
      'homeId': item.homeId,
      'unit': item.unit,
      'name': item.name,
      'minimum': item.minimumStock,
      'aisle': item.category,
      'imageUrl': item.imageUrl,
      'store': item.store,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<num> stockMinimum(String barcode, String homeId, String unit) async {
    final rows = await (await database).query(
      'stock_rules',
      columns: ['minimum'],
      where: 'barcode=? AND homeId=? AND unit=?',
      whereArgs: [barcode, homeId, unit],
      limit: 1,
    );
    return rows.firstOrNull?['minimum'] as num? ?? 0;
  }

  /// Rules survive the final batch, and only manage entries they created.
  Future<void> reconcileStock() async {
    await (await database).transaction((txn) async {
      for (final rule in await txn.query('stock_rules')) {
        final rows = await txn.rawQuery(
          'SELECT SUM(quantity) AS amount FROM pantry_items WHERE barcode=? AND homeId=? AND unit=?',
          [rule['barcode'], rule['homeId'], rule['unit']],
        );
        final amount = rows.first['amount'] as num? ?? 0;
        final deficit = (rule['minimum'] as num) - amount;
        final entries = await txn.query(
          'shopping_items',
          where: 'barcode=? AND homeId=? AND unit=? AND isChecked=0',
          whereArgs: [rule['barcode'], rule['homeId'], rule['unit']],
        );
        final auto = entries.where((e) => e['automatic'] == 1).toList();
        if (deficit <= 0) {
          for (final e in auto) {
            await txn.delete(
              'shopping_items',
              where: 'id=?',
              whereArgs: [e['id']],
            );
          }
        } else if (entries.isEmpty) {
          await txn.insert(
            'shopping_items',
            ShoppingItem(
              name: rule['name'] as String,
              barcode: rule['barcode'] as String,
              homeId: rule['homeId'] as String,
              unit: rule['unit'] as String,
              quantity: deficit,
              aisle: rule['aisle'] as String,
              imageUrl: rule['imageUrl'] as String?,
              store: rule['store'] as String,
              automatic: true,
            ).toMap(),
          );
        } else if (auto.isNotEmpty) {
          await txn.update(
            'shopping_items',
            {'quantity': deficit},
            where: 'id=?',
            whereArgs: [auto.first['id']],
          );
        }
      }
    });
  }
}

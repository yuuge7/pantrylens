import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'pantry_item.dart';
import 'shopping_item.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  factory DatabaseHelper() => instance;

  static const String _databaseName = 'pantrylens.db';
  static const String _tableName = 'pantry_items';
  static const String _shoppingTableName = 'shopping_items';
  static const int _databaseVersion = 2;

  Future<Database>? _databaseFuture;

  Future<Database> get database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = p.join(documentsDirectory.path, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            imageUrl TEXT,
            quantity INTEGER NOT NULL CHECK (quantity > 0),
            expirationDate TEXT NOT NULL
          )
        ''');
        await _createShoppingTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createShoppingTable(db);
        }
      },
    );
  }

  Future<void> _createShoppingTable(Database db) {
    return db.execute('''
      CREATE TABLE $_shoppingTableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        isChecked INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insertItem(PantryItem item) async {
    final db = await database;
    final values = item.toMap()..remove('id');
    return db.insert(
      _tableName,
      values,
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateItem(PantryItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError.value(
        item,
        'item',
        'Cannot update an item without a database id.',
      );
    }

    final db = await database;
    final values = item.toMap()..remove('id');
    return db.update(_tableName, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllItems() async {
    final db = await database;
    return db.delete(_tableName);
  }

  Future<PantryItem?> getItemByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PantryItem.fromMap(rows.first);
  }

  Future<List<PantryItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(PantryItem.fromMap).toList(growable: false);
  }

  Future<List<ShoppingItem>> getShoppingItems() async {
    final db = await database;
    final rows = await db.query(
      _shoppingTableName,
      orderBy: 'isChecked ASC, id DESC',
    );
    return rows.map(ShoppingItem.fromMap).toList(growable: false);
  }

  Future<int> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    final values = item.toMap()..remove('id');
    return db.insert(_shoppingTableName, values);
  }

  Future<int> updateShoppingItem(ShoppingItem item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError.value(
        item,
        'item',
        'Cannot update a shopping item without a database id.',
      );
    }

    final db = await database;
    final values = item.toMap()..remove('id');
    return db.update(
      _shoppingTableName,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteShoppingItem(int id) async {
    final db = await database;
    return db.delete(_shoppingTableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCheckedShoppingItems() async {
    final db = await database;
    return db.delete(_shoppingTableName, where: 'isChecked = 1');
  }

  Future<int> deleteAllShoppingItems() async {
    final db = await database;
    return db.delete(_shoppingTableName);
  }
}

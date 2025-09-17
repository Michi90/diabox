import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:diabox/models/consumable_type.dart';
import 'package:diabox/models/stock_item.dart';
import 'package:diabox/models/active_consumable.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = await getDatabasesPath();
    String databasePath = join(path, 'diabox.db');

    return await openDatabase(
      databasePath,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE consumable_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        default_lifespan_days INTEGER NOT NULL,
        is_fixed_lifespan INTEGER NOT NULL,
        manages_stock INTEGER NOT NULL DEFAULT 1,
        notification_offsets_in_minutes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        consumable_type_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        added_date TEXT NOT NULL,
        FOREIGN KEY (consumable_type_id) REFERENCES consumable_types(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE active_consumables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        consumable_type_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        expected_end_date TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        deactivation_date TEXT,
        notes TEXT,
        FOREIGN KEY (consumable_type_id) REFERENCES consumable_types(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT
      )
    ''');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }

  Future<int> updateSetting(String key, String value) async {
    final db = await database;
    return await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE active_consumables ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE active_consumables ADD COLUMN deactivation_date TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE consumable_types ADD COLUMN manages_stock INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE consumable_types ADD COLUMN notification_offsets_in_minutes TEXT',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE active_consumables ADD COLUMN deactivation_date TEXT',
      );
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE active_consumables ADD COLUMN notes TEXT');
    }
  }

  // ConsumableType CRUD operations
  Future<int> insertConsumableType(ConsumableType type) async {
    final db = await database;
    return await db.insert(
      'consumable_types',
      type.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ConsumableType>> getConsumableTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('consumable_types');
    return List.generate(maps.length, (i) {
      return ConsumableType.fromMap(maps[i]);
    });
  }

  Future<ConsumableType?> getConsumableTypeById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'consumable_types',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ConsumableType.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateConsumableType(ConsumableType type) async {
    final db = await database;
    return await db.update(
      'consumable_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<int> deleteConsumableType(int id) async {
    final db = await database;
    return await db.delete(
      'consumable_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // StockItem CRUD operations
  Future<int> insertStockItem(StockItem item) async {
    final db = await database;
    return await db.insert(
      'stock_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StockItem>> getStockItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stock_items');
    return List.generate(maps.length, (i) {
      return StockItem.fromMap(maps[i]);
    });
  }

  Future<StockItem?> getStockItemById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return StockItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateStockItem(StockItem item) async {
    final db = await database;
    return await db.update(
      'stock_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteStockItem(int id) async {
    final db = await database;
    return await db.delete('stock_items', where: 'id = ?', whereArgs: [id]);
  }

  // ActiveConsumable CRUD operations
  Future<int> insertActiveConsumable(ActiveConsumable item) async {
    final db = await database;
    return await db.insert(
      'active_consumables',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActiveConsumable>> getActiveConsumables() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'active_consumables',
      where: 'is_active = 1',
    );
    return List.generate(maps.length, (i) {
      return ActiveConsumable.fromMap(maps[i]);
    });
  }

  Future<ActiveConsumable?> getActiveConsumableById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'active_consumables',
      where: 'id = ? AND is_active = 1',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ActiveConsumable.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateActiveConsumable(ActiveConsumable item) async {
    final db = await database;
    return await db.update(
      'active_consumables',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deactivateActiveConsumable(int id) async {
    final db = await database;
    return await db.update(
      'active_consumables',
      {'is_active': 0, 'deactivation_date': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Custom queries for ConsumableTypeDetailScreen
  Future<int> getTotalStockForConsumableType(int typeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_items',
      columns: ['SUM(quantity) as total_quantity'],
      where: 'consumable_type_id = ?',
      whereArgs: [typeId],
    );
    if (maps.isNotEmpty && maps.first['total_quantity'] != null) {
      return maps.first['total_quantity'] as int;
    }
    return 0;
  }

  Future<List<ActiveConsumable>> getActiveConsumablesForType(int typeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'active_consumables',
      where: 'consumable_type_id = ? AND is_active = 1',
      whereArgs: [typeId],
    );
    return List.generate(maps.length, (i) {
      return ActiveConsumable.fromMap(maps[i]);
    });
  }

  Future<List<ActiveConsumable>> getUsedConsumablesForType(int typeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'active_consumables',
      where: 'consumable_type_id = ? AND is_active = 0',
      whereArgs: [typeId],
      orderBy: 'start_date DESC',
    );
    return List.generate(maps.length, (i) {
      return ActiveConsumable.fromMap(maps[i]);
    });
  }

  Future<bool> decrementStockItemQuantity(int consumableTypeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'stock_items',
      where: 'consumable_type_id = ? AND quantity > 0',
      whereArgs: [consumableTypeId],
      orderBy: 'added_date ASC', // Get the oldest stock item first
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final stockItem = StockItem.fromMap(maps.first);
      if (stockItem.quantity > 1) {
        // Decrement quantity
        await db.update(
          'stock_items',
          {'quantity': stockItem.quantity - 1},
          where: 'id = ?',
          whereArgs: [stockItem.id],
        );
      } else {
        // Quantity is 1, so delete the item
        await db.delete(
          'stock_items',
          where: 'id = ?',
          whereArgs: [stockItem.id],
        );
      }
      return true;
    }
    return false;
  }

  Future<void> removeStockForConsumableType(
    int consumableTypeId,
    int quantityToRemove,
  ) async {
    final db = await database;
    int removedQuantity = 0;

    while (removedQuantity < quantityToRemove) {
      final List<Map<String, dynamic>> maps = await db.query(
        'stock_items',
        where: 'consumable_type_id = ? AND quantity > 0',
        whereArgs: [consumableTypeId],
        orderBy: 'added_date ASC', // Get the oldest stock item first
        limit: 1,
      );

      if (maps.isEmpty) {
        // No more stock items to remove from
        break;
      }

      final stockItem = StockItem.fromMap(maps.first);
      int canRemove = stockItem.quantity;
      int neededToRemove = quantityToRemove - removedQuantity;

      if (canRemove <= neededToRemove) {
        // Remove the entire stock item
        await db.delete(
          'stock_items',
          where: 'id = ?',
          whereArgs: [stockItem.id],
        );
        removedQuantity += canRemove;
      } else {
        // Decrement quantity from the current stock item
        await db.update(
          'stock_items',
          {'quantity': stockItem.quantity - neededToRemove},
          where: 'id = ?',
          whereArgs: [stockItem.id],
        );
        removedQuantity += neededToRemove;
      }
    }
  }

  // Export/Import functionality
  Future<Map<String, dynamic>> getAllDataAsMap() async {
    final db = await database;
    final List<Map<String, dynamic>> consumableTypes = await db.query('consumable_types');
    final List<Map<String, dynamic>> stockItems = await db.query('stock_items');
    final List<Map<String, dynamic>> activeConsumables = await db.query('active_consumables');
    final List<Map<String, dynamic>> settings = await db.query('settings');

    return {
      'consumable_types': consumableTypes,
      'stock_items': stockItems,
      'active_consumables': activeConsumables,
      'settings': settings,
    };
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('consumable_types');
    await db.delete('stock_items');
    await db.delete('active_consumables');
    await db.delete('settings');
  }

  Future<void> insertAllDataFromMap(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // Insert ConsumableTypes
      if (data.containsKey('consumable_types')) {
        for (var item in (data['consumable_types'] as List)) {
          await txn.insert('consumable_types', item as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert StockItems
      if (data.containsKey('stock_items')) {
        for (var item in (data['stock_items'] as List)) {
          await txn.insert('stock_items', item as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert ActiveConsumables
      if (data.containsKey('active_consumables')) {
        for (var item in (data['active_consumables'] as List)) {
          await txn.insert('active_consumables', item as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      // Insert Settings
      if (data.containsKey('settings')) {
        for (var item in (data['settings'] as List)) {
          await txn.insert('settings', item as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}

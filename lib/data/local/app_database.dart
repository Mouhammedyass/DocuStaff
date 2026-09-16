import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  Future<Database?> get db async {
    if (_db != null) return _db;
    _db = await _initDatabase();
    return _db;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'personnel_management_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE "departments" (
      "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "name" TEXT NOT NULL,
      "parent_id" INTEGER
    )
    ''');
    await db.execute('''
    CREATE TABLE "employees" (
      "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      "name" TEXT NOT NULL,
      "national_id" TEXT,
      "retirement_date" TEXT,
      "department_id" INTEGER NOT NULL,
      "extra_data" TEXT
    )
    ''');
  }

  Future<int> insertData(String table, Map<String, dynamic> values) async {
    Database? mydb = await db;
    int response = await mydb!.insert(table, values);
    return response;
  }

  Future<List<Map<String, dynamic>>> readData(String table,{String? where , List<dynamic>? whereArgs}) async {
    Database? mydb = await db;
    List<Map<String, dynamic>> response = await mydb!.query(table, where: where, whereArgs: whereArgs);
    return response;
  }

  Future<int> deleteData(String table, int id) async {
    Database? mydb = await db;
    int response = await mydb!.delete(table, where: 'id = ?', whereArgs: [id]);
    return response;
  }

  Future<int> updateData(String table, Map<String, dynamic> values, int id) async {
    Database? mydb = await db;
    int response = await mydb!.update(table, values, where: 'id = ?' ,whereArgs: [id]);
    return response;
  }
}
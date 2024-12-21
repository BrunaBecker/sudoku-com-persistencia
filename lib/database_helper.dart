import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sudoku.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sudoku(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR NOT NULL,
        result INTEGER,
        date VARCHAR NOT NULL,
        level INTEGER
      )
    ''');
  }

  Future<int> insertMatch(Map<String, dynamic> match) async {
    final db = await instance.database;
    return db.insert('sudoku', match);
  }

  Future<List<Map<String, dynamic>>> fetchMatchesByLevel(int level) async {
    final db = await instance.database;
    return db.query('sudoku', where: 'level = ?', whereArgs: [level]);
  }
}

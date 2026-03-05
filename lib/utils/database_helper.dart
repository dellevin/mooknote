import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 数据库帮助类 - 管理数据库的创建和版本控制
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mooknote.db');
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

  // 创建数据库表
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const booleanType = 'INTEGER NOT NULL';

    // 影视表
    await db.execute('''
      CREATE TABLE movies (
        id $idType,
        title $textType,
        poster TEXT,
        rating REAL,
        year INTEGER,
        status $textType,
        watch_date TEXT,
        note TEXT
      )
    ''');

    // 书籍表
    await db.execute('''
      CREATE TABLE books (
        id $idType,
        title $textType,
        author TEXT,
        cover TEXT,
        rating REAL,
        status $textType,
        read_date TEXT,
        note TEXT
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE notes (
        id $idType,
        title $textType,
        content $textType,
        tags TEXT,
        created_at $textType,
        updated_at $textType
      )
    ''');
  }

  // 关闭数据库
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

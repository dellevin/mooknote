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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 升级movies表结构
      await _upgradeMoviesTableV2(db);
    }
    if (oldVersion < 3) {
      // 升级books表结构
      await _upgradeBooksTableV3(db);
    }
    if (oldVersion < 4) {
      // 升级notes表结构
      await _upgradeNotesTableV4(db);
    }
  }
  
  /// 升级notes表到V4
  Future<void> _upgradeNotesTableV4(Database db) async {
    // 备份旧数据
    final oldData = await db.query('notes');
    
    // 删除旧表
    await db.execute('DROP TABLE IF EXISTS notes');
    
    // 创建新表
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        content_type TEXT DEFAULT 'markdown',
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // 迁移旧数据（将title合并到content中）
    for (final row in oldData) {
      try {
        final now = DateTime.now().toIso8601String();
        final title = row['title']?.toString() ?? '';
        final content = row['content']?.toString() ?? '';
        final combinedContent = title.isNotEmpty 
            ? '# $title\n\n$content'
            : content;
        
        await db.insert('notes', {
          'id': row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'content': combinedContent,
          'content_type': 'markdown',
          'tags': row['tags'] ?? '',
          'created_at': row['created_at']?.toString() ?? now,
          'updated_at': row['updated_at']?.toString() ?? now,
        });
      } catch (e) {
        // 忽略迁移失败的记录
      }
    }
  }
  
  /// 升级books表到V3
  Future<void> _upgradeBooksTableV3(Database db) async {
    // 备份旧数据
    final oldData = await db.query('books');
    
    // 删除旧表
    await db.execute('DROP TABLE IF EXISTS books');
    
    // 创建新表
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cover_path TEXT,
        authors TEXT,
        alternate_titles TEXT,
        publisher TEXT,
        genres TEXT,
        summary TEXT,
        rating REAL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    
    // 迁移旧数据
    for (final row in oldData) {
      try {
        final now = DateTime.now().toIso8601String();
        await db.insert('books', {
          'id': row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': row['title']?.toString() ?? '',
          'cover_path': row['cover'],
          'authors': row['author'] != null ? '["${row['author']}"]' : '[]',
          'alternate_titles': '[]',
          'publisher': null,
          'genres': '[]',
          'summary': row['note'],
          'rating': row['rating'],
          'status': row['status'] ?? 'want_to_read',
          'created_at': now,
          'updated_at': now,
          'is_deleted': 0,
        });
      } catch (e) {
        // 忽略迁移失败的记录
      }
    }
  }

  /// 升级movies表到V2
  Future<void> _upgradeMoviesTableV2(Database db) async {
    // 备份旧数据
    final oldData = await db.query('movies');
    
    // 删除旧表
    await db.execute('DROP TABLE IF EXISTS movies');
    
    // 创建新表
    await db.execute('''
      CREATE TABLE movies (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        poster_path TEXT,
        release_date TEXT,
        directors TEXT,
        writers TEXT,
        actors TEXT,
        genres TEXT,
        alternate_titles TEXT,
        summary TEXT,
        rating REAL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    
    // 迁移旧数据（尽可能保留）
    for (final row in oldData) {
      try {
        await db.insert('movies', {
          'id': row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': row['title']?.toString() ?? '',
          'poster_path': row['poster_path'],
          'release_date': null,
          'directors': '[]',
          'writers': '[]',
          'actors': '[]',
          'genres': '[]',
          'alternate_titles': '[]',
          'summary': row['note'],
          'rating': row['rating'],
          'status': row['status'] ?? 'want_to_watch',
          'created_at': row['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'is_deleted': row['is_deleted'] ?? 0,
        });
      } catch (e) {
        // 忽略迁移失败的记录
      }
    }
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
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        poster_path TEXT,
        release_date TEXT,
        directors TEXT,
        writers TEXT,
        actors TEXT,
        genres TEXT,
        alternate_titles TEXT,
        summary TEXT,
        rating REAL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 书籍表
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cover_path TEXT,
        authors TEXT,
        alternate_titles TEXT,
        publisher TEXT,
        genres TEXT,
        summary TEXT,
        rating REAL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        content_type TEXT DEFAULT 'markdown',
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // 关闭数据库
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

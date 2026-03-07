import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 数据库帮助类 - 管理数据库的创建和版本控制
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// 重新打开数据库（用于 WebDAV 同步后）
  Future<void> reopenDatabase() async {
    // 关闭现有连接
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    // 重新初始化
    _database = await _initDB('mooknote.db');
  }

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
      version: 9,
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
    if (oldVersion < 5) {
      // 创建影评表和海报墙表
      await _createMovieReviewsTable(db);
      await _createMoviePostersTable(db);
    }
    if (oldVersion < 6) {
      // 为笔记表添加软删除字段
      await _upgradeNotesTableV6(db);
    }
    if (oldVersion < 7) {
      // 创建书评表和摘抄表
      await _createBookReviewsTable(db);
      await _createBookExcerptsTable(db);
    }
    if (oldVersion < 8) {
      // 确保书评表和摘抄表存在（兼容之前版本未成功创建的情况）
      await _createBookReviewsTable(db);
      await _createBookExcerptsTable(db);
    }
    if (oldVersion < 9) {
      // 为笔记表添加图片字段
      await _upgradeNotesTableV9(db);
    }
  }
  
  /// 升级notes表到V9（添加图片字段）
  Future<void> _upgradeNotesTableV9(Database db) async {
    // 检查是否存在 images 列
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    final hasImages = columns.any((col) => col['name'] == 'images');
    
    if (!hasImages) {
      await db.execute('ALTER TABLE notes ADD COLUMN images TEXT');
    }
  }
  
  /// 升级notes表到V6（添加软删除字段）
  Future<void> _upgradeNotesTableV6(Database db) async {
    // 检查是否存在 is_deleted 列
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    final hasIsDeleted = columns.any((col) => col['name'] == 'is_deleted');
    
    if (!hasIsDeleted) {
      await db.execute('ALTER TABLE notes ADD COLUMN is_deleted INTEGER DEFAULT 0');
    }
  }
  
  /// 创建影评表
  Future<void> _createMovieReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_reviews (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        content TEXT NOT NULL,
        reviewer TEXT,
        source TEXT,
        review_type INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (movie_id) REFERENCES movies (id)
      )
    ''');
  }

  /// 创建影视海报墙表
  Future<void> _createMoviePostersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movie_posters (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        poster_path TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (movie_id) REFERENCES movies (id)
      )
    ''');
  }

  /// 创建书评表
  Future<void> _createBookReviewsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_reviews (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        content TEXT NOT NULL,
        reviewer TEXT,
        source TEXT,
        review_type INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id)
      )
    ''');
  }

  /// 创建书籍摘抄表
  Future<void> _createBookExcerptsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_excerpts (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter TEXT,
        content TEXT NOT NULL,
        comment TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id)
      )
    ''');
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
        images TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    
    // 影评表
    await db.execute('''
      CREATE TABLE movie_reviews (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        content TEXT NOT NULL,
        reviewer TEXT,
        source TEXT,
        review_type INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (movie_id) REFERENCES movies (id)
      )
    ''');
    
    // 影视海报墙表
    await db.execute('''
      CREATE TABLE movie_posters (
        id TEXT PRIMARY KEY,
        movie_id TEXT NOT NULL,
        poster_path TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (movie_id) REFERENCES movies (id)
      )
    ''');

    // 书评表
    await db.execute('''
      CREATE TABLE book_reviews (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        content TEXT NOT NULL,
        reviewer TEXT,
        source TEXT,
        review_type INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id)
      )
    ''');

    // 书籍摘抄表
    await db.execute('''
      CREATE TABLE book_excerpts (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter TEXT,
        content TEXT NOT NULL,
        comment TEXT,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books (id)
      )
    ''');
  }

  // 关闭数据库
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

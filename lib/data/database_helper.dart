import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/data_models.dart';

/// 数据库帮助类 - 管理数据库的创建和版本控制
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Completer<void>? _reopenCompleter;
  static Completer<Database>? _initCompleter;

  DatabaseHelper._init();

  /// 数据库文件路径
  Future<String?> get databasePath async {
    final path = await getDatabasesPath();
    return join(path, 'mooknote.db');
  }

  /// 重新打开数据库（用于 WebDAV 同步后）
  Future<void> reopenDatabase() async {
    // 如果已有重开在进行，等待它完成即可
    if (_reopenCompleter != null) {
      return _reopenCompleter!.future;
    }
    _reopenCompleter = Completer<void>();
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      _database = await _initDB('mooknote.db');
      _reopenCompleter!.complete();
    } catch (e) {
      _reopenCompleter!.completeError(e);
      rethrow;
    } finally {
      _reopenCompleter = null;
    }
  }

  Future<Database> get database async {
    // 如果正在重开，等待完成
    if (_reopenCompleter != null) {
      await _reopenCompleter!.future;
    }
    if (_database != null) return _database!;

    // 如果已有初始化在进行，等待它完成
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDB('mooknote.db');
      _initCompleter!.complete(_database!);
      return _database!;
    } catch (e) {
      _initCompleter!.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 34,
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
    if (oldVersion < 10) {
      // 为影视表添加观看日期字段
      await _upgradeMoviesTableV10(db);
    }
    if (oldVersion < 11) {
      // 为书籍表添加ISBN和出版时间字段
      await _upgradeBooksTableV11(db);
    }
    if (oldVersion < 12) {
      // 确保notes表有title列
      await _upgradeNotesTableV12(db);
    }
    if (oldVersion < 13) {
      await _upgradeToV13(db);
    }
    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reader_books (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT DEFAULT '',
          cover_path TEXT,
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_extension TEXT NOT NULL DEFAULT 'epub',
          last_read_cfi TEXT DEFAULT '',
          reading_percentage REAL DEFAULT 0.0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 15) {
      // 安全添加 cover_offset 列（防止列已存在时报错）
      final movieCols = await db.rawQuery('PRAGMA table_info(movies)');
      if (!movieCols.any((col) => col['name'] == 'cover_offset')) {
        await db.execute('ALTER TABLE movies ADD COLUMN cover_offset REAL DEFAULT 0');
      }
      final bookCols = await db.rawQuery('PRAGMA table_info(books)');
      if (!bookCols.any((col) => col['name'] == 'cover_offset')) {
        await db.execute('ALTER TABLE books ADD COLUMN cover_offset REAL DEFAULT 0');
      }
    }
    // v16: 已合并到 v15（cover_offset 列的添加逻辑相同，v15 的 PRAGMA 检查已确保幂等）
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE tags ADD COLUMN is_hidden INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 18) {
      // note_plus table creation removed (feature dropped in v28)
    }
    if (oldVersion < 19) {
      // note_plus table creation removed (feature dropped in v28)
    }
    if (oldVersion < 20) {
      // 确保 note_plus 表有 parent_id 列（从旧版 folder 迁移）
      try {
        final cols = await db.rawQuery('PRAGMA table_info(note_plus)');
        if (!cols.any((col) => col['name'] == 'parent_id')) {
          if (cols.any((col) => col['name'] == 'folder')) {
            await db.execute("ALTER TABLE note_plus RENAME COLUMN folder TO parent_id");
          } else {
            await db.execute("ALTER TABLE note_plus ADD COLUMN parent_id TEXT DEFAULT ''");
          }
        }
      } catch (e) {
        debugPrint('Migration v20 failed: $e');
      }
    }
    if (oldVersion < 21) {
      try {
        final cols = await db.rawQuery('PRAGMA table_info(note_plus)');
        if (!cols.any((col) => col['name'] == 'sort_index')) {
          await db.execute("ALTER TABLE note_plus ADD COLUMN sort_index INTEGER DEFAULT 0");
        }
      } catch (e) {
        debugPrint('Migration v21 failed: $e');
      }
    }
    if (oldVersion < 22) {
      // 为笔记表添加置顶字段
      await _upgradeNotesTableV22(db);
    }
    if (oldVersion < 23) {
      // 创建书籍批注表（高亮、下划线、书签）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS book_annotations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id TEXT NOT NULL,
          content TEXT NOT NULL DEFAULT '',
          cfi TEXT NOT NULL DEFAULT '',
          chapter TEXT DEFAULT '',
          type TEXT NOT NULL DEFAULT 'highlight',
          color TEXT NOT NULL DEFAULT 'FFEB3B',
          reader_note TEXT DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_book_annotations_book_id ON book_annotations(book_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_book_annotations_type ON book_annotations(book_id, type)',
      );
    }
    if (oldVersion < 24) {
      // reader_books 添加 book_id 列（关联 books 表）
      final cols = await db.rawQuery('PRAGMA table_info(reader_books)');
      if (!cols.any((col) => col['name'] == 'book_id')) {
        await db.execute("ALTER TABLE reader_books ADD COLUMN book_id TEXT DEFAULT ''");
      }
    }
    if (oldVersion < 25) {
      // movies 添加 category 列（影视分类）
      final cols = await db.rawQuery('PRAGMA table_info(movies)');
      if (!cols.any((col) => col['name'] == 'category')) {
        await db.execute("ALTER TABLE movies ADD COLUMN category TEXT NOT NULL DEFAULT 'movie'");
      }
    }
    if (oldVersion < 26) {
      await _upgradeBooksTableV26(db);
    }
    // v27: 已合并到 v26（start_date/finish_date 的添加逻辑相同，v26 的 PRAGMA 检查已确保幂等）
    if (oldVersion < 28) {
      // 移除 Note Plus 功能，删除 note_plus 表
      await db.execute('DROP TABLE IF EXISTS note_plus');
    }
    if (oldVersion < 29) {
      // 为书籍表添加译者字段
      final bookCols = await db.rawQuery('PRAGMA table_info(books)');
      if (!bookCols.any((col) => col['name'] == 'translators')) {
        await db.execute('ALTER TABLE books ADD COLUMN translators TEXT');
      }
    }
    if (oldVersion < 30) {
      // reader_books 添加简介、出版社、ISBN、多作者字段
      final cols = await db.rawQuery('PRAGMA table_info(reader_books)');
      if (!cols.any((col) => col['name'] == 'summary')) {
        await db.execute("ALTER TABLE reader_books ADD COLUMN summary TEXT DEFAULT ''");
      }
      if (!cols.any((col) => col['name'] == 'publisher')) {
        await db.execute("ALTER TABLE reader_books ADD COLUMN publisher TEXT DEFAULT ''");
      }
      if (!cols.any((col) => col['name'] == 'isbn')) {
        await db.execute("ALTER TABLE reader_books ADD COLUMN isbn TEXT DEFAULT ''");
      }
      if (!cols.any((col) => col['name'] == 'authors')) {
        await db.execute("ALTER TABLE reader_books ADD COLUMN authors TEXT DEFAULT ''");
      }
    }
    if (oldVersion < 31) {
      // 创建游戏表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS games (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          cover_path TEXT,
          rating REAL,
          status TEXT NOT NULL DEFAULT 'want_to_play',
          category TEXT NOT NULL DEFAULT 'digital',
          platforms TEXT DEFAULT '[]',
          versions TEXT DEFAULT '[]',
          genres TEXT DEFAULT '[]',
          play_time_hours INTEGER DEFAULT 0,
          play_time_minutes INTEGER DEFAULT 0,
          purchase_platforms TEXT DEFAULT '[]',
          purchase_date TEXT,
          purchase_price TEXT,
          cover_offset REAL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 32) {
      // games表添加summary字段
      await db.execute('ALTER TABLE games ADD COLUMN summary TEXT');
    }
    if (oldVersion < 34) {
      // 确保games表summary字段存在
      final columns = await db.rawQuery('PRAGMA table_info(games)');
      if (!columns.any((col) => col['name'] == 'summary')) {
        await db.execute('ALTER TABLE games ADD COLUMN summary TEXT');
      }
      // 确保游戏评价表和游戏截图表存在
      await db.execute('''
        CREATE TABLE IF NOT EXISTS game_reviews (
          id TEXT PRIMARY KEY,
          game_id TEXT NOT NULL,
          content TEXT NOT NULL,
          reviewer TEXT,
          source TEXT,
          review_type INTEGER DEFAULT 1,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS game_screenshots (
          id TEXT PRIMARY KEY,
          game_id TEXT NOT NULL,
          screenshot_path TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          FOREIGN KEY (game_id) REFERENCES games (id)
        )
      ''');
    }
  }

  /// 升级books表到V26（添加阅读始末日期字段）
  Future<void> _upgradeBooksTableV26(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(books)');
    final hasStartDate = columns.any((col) => col['name'] == 'start_date');
    final hasFinishDate = columns.any((col) => col['name'] == 'finish_date');

    if (!hasStartDate) {
      await db.execute('ALTER TABLE books ADD COLUMN start_date TEXT');
    }
    if (!hasFinishDate) {
      await db.execute('ALTER TABLE books ADD COLUMN finish_date TEXT');
    }
  }

  /// 升级books表到V11（添加ISBN和出版时间字段）
  Future<void> _upgradeBooksTableV11(Database db) async {
    // 检查是否存在 isbn 列
    final columns = await db.rawQuery('PRAGMA table_info(books)');
    final hasIsbn = columns.any((col) => col['name'] == 'isbn');
    final hasPublishDate = columns.any((col) => col['name'] == 'publish_date');

    if (!hasIsbn) {
      await db.execute('ALTER TABLE books ADD COLUMN isbn TEXT');
    }
    if (!hasPublishDate) {
      await db.execute('ALTER TABLE books ADD COLUMN publish_date TEXT');
    }
  }

  /// 升级movies表到V10（添加观看日期字段）
  Future<void> _upgradeMoviesTableV10(Database db) async {
    // 检查是否存在 watch_date 列
    final columns = await db.rawQuery('PRAGMA table_info(movies)');
    final hasWatchDate = columns.any((col) => col['name'] == 'watch_date');

    if (!hasWatchDate) {
      await db.execute('ALTER TABLE movies ADD COLUMN watch_date TEXT');
    }
  }
  
  /// 升级notes表到V12（确保title列存在）
  Future<void> _upgradeNotesTableV12(Database db) async {
    // 检查是否存在 title 列
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    final hasTitle = columns.any((col) => col['name'] == 'title');

    if (!hasTitle) {
      await db.execute('ALTER TABLE notes ADD COLUMN title TEXT DEFAULT \'\'');
    }
  }

  /// 升级notes表到V22（添加置顶字段）
  Future<void> _upgradeNotesTableV22(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(notes)');
    final hasIsPinned = columns.any((col) => col['name'] == 'is_pinned');
    if (!hasIsPinned) {
      await db.execute('ALTER TABLE notes ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// 升级到V13：创建标签表并回填已有数据
  Future<void> _upgradeToV13(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        UNIQUE(name, type)
      )
    ''');
    await _backfillTags(db);
  }

  Future<void> _backfillTags(Database db) async {
    final now = DateTime.now().toIso8601String();
    int counter = 0;

    Future<void> insertTag(String name, String type) async {
      try {
        await db.insert('tags', {
          'id': 'tag_${DateTime.now().millisecondsSinceEpoch}_${counter++}',
          'name': name,
          'type': type,
          'created_at': now,
        });
      } catch (_) {
        // 忽略 UNIQUE 约束冲突
      }
    }

    // 回填影视类型
    final movies = await db.query('movies',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in movies) {
      for (final genre in parseStringListGeneric(row['genres'])) {
        await insertTag(genre, 'movie_genre');
      }
    }

    // 回填书籍类型
    final books = await db.query('books',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in books) {
      for (final genre in parseStringListGeneric(row['genres'])) {
        await insertTag(genre, 'book_genre');
      }
    }

    // 回填笔记标签
    final notes = await db.query('notes',
        where: 'tags IS NOT NULL AND tags != ? AND tags != ?',
        whereArgs: ['[]', '']);
    for (final row in notes) {
      for (final tag in parseStringListGeneric(row['tags'])) {
        await insertTag(tag, 'note_tag');
      }
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
    await db.transaction((txn) async {
      // 备份旧数据
      final oldData = await txn.query('notes');

      // 删除旧表
      await txn.execute('DROP TABLE IF EXISTS notes');

      // 创建新表
      await txn.execute('''
        CREATE TABLE notes (
          id TEXT PRIMARY KEY,
          title TEXT DEFAULT '',
          content TEXT NOT NULL,
          content_type TEXT DEFAULT 'markdown',
          tags TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      // 迁移旧数据（将title字段恢复）
      for (final row in oldData) {
        try {
          final now = DateTime.now().toIso8601String();
          final title = row['title']?.toString() ?? '';
          final content = row['content']?.toString() ?? '';

          await txn.insert('notes', {
            'id': row['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'title': title,
            'content': content,
            'content_type': 'markdown',
            'tags': row['tags'] ?? '',
            'created_at': row['created_at']?.toString() ?? now,
            'updated_at': row['updated_at']?.toString() ?? now,
          });
        } catch (e) {
          debugPrint('[DB] 迁移笔记记录失败: $e');
        }
      }
    });
  }

  /// 升级books表到V3
  Future<void> _upgradeBooksTableV3(Database db) async {
    await db.transaction((txn) async {
      // 备份旧数据
      final oldData = await txn.query('books');

      // 删除旧表
      await txn.execute('DROP TABLE IF EXISTS books');

      // 创建新表
      await txn.execute('''
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
          await txn.insert('books', {
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
          debugPrint('[DB] 迁移书籍记录失败: $e');
        }
      }
    });
  }

  /// 升级movies表到V2
  Future<void> _upgradeMoviesTableV2(Database db) async {
    await db.transaction((txn) async {
      // 备份旧数据
      final oldData = await txn.query('movies');

      // 删除旧表
      await txn.execute('DROP TABLE IF EXISTS movies');

      // 创建新表
      await txn.execute('''
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
          category TEXT NOT NULL DEFAULT 'movie',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0
        )
      ''');

      // 迁移旧数据（尽可能保留）
      for (final row in oldData) {
        try {
          await txn.insert('movies', {
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
          debugPrint('[DB] 迁移影视记录失败: $e');
        }
      }
    });
  }

  // 创建数据库表
  Future<void> _createDB(Database db, int version) async {
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
        category TEXT NOT NULL DEFAULT 'movie',
        watch_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        cover_offset REAL DEFAULT 0
      )
    ''');

    // 书籍表
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cover_path TEXT,
        authors TEXT,
        translators TEXT,
        alternate_titles TEXT,
        publisher TEXT,
        genres TEXT,
        summary TEXT,
        rating REAL,
        status TEXT NOT NULL,
        isbn TEXT,
        publish_date TEXT,
        start_date TEXT,
        finish_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        cover_offset REAL DEFAULT 0
      )
    ''');

    // 笔记表
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT DEFAULT '',
        content TEXT NOT NULL,
        content_type TEXT DEFAULT 'markdown',
        tags TEXT,
        images TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0
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

    // 标签表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_hidden INTEGER NOT NULL DEFAULT 0,
        UNIQUE(name, type)
      )
    ''');

    // EPUB 阅读器书籍表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reader_books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT DEFAULT '',
        authors TEXT DEFAULT '',
        cover_path TEXT,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_extension TEXT NOT NULL DEFAULT 'epub',
        last_read_cfi TEXT DEFAULT '',
        reading_percentage REAL DEFAULT 0.0,
        book_id TEXT DEFAULT '',
        summary TEXT DEFAULT '',
        publisher TEXT DEFAULT '',
        isbn TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 书籍批注表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_annotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        cfi TEXT NOT NULL DEFAULT '',
        chapter TEXT DEFAULT '',
        type TEXT NOT NULL DEFAULT 'highlight',
        color TEXT NOT NULL DEFAULT 'FFEB3B',
        reader_note TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 游戏表
    await db.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cover_path TEXT,
        rating REAL,
        status TEXT NOT NULL DEFAULT 'want_to_play',
        category TEXT NOT NULL DEFAULT 'digital',
        platforms TEXT DEFAULT '[]',
        versions TEXT DEFAULT '[]',
        genres TEXT DEFAULT '[]',
        play_time_hours INTEGER DEFAULT 0,
        play_time_minutes INTEGER DEFAULT 0,
        purchase_platforms TEXT DEFAULT '[]',
        purchase_date TEXT,
        purchase_price TEXT,
        summary TEXT,
        cover_offset REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    // 游戏评价表
    await db.execute('''
      CREATE TABLE game_reviews (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        content TEXT NOT NULL,
        reviewer TEXT,
        source TEXT,
        review_type INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id)
      )
    ''');

    // 游戏截图表
    await db.execute('''
      CREATE TABLE game_screenshots (
        id TEXT PRIMARY KEY,
        game_id TEXT NOT NULL,
        screenshot_path TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (game_id) REFERENCES games (id)
      )
    ''');
  }

  // 关闭数据库
  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

}

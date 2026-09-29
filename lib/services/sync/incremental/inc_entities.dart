/// 增量同步实体规格：表名、时间戳列、图片字段、随父实体整组同步的子表
class IncEntitySpec {
  /// 表名
  final String table;

  /// LWW / 变更检测使用的时间戳列
  final String tsColumn;

  /// 单值图片列
  final List<String> imageColumns;

  /// 笔记式 JSON 列表图片列（如 notes.images）
  final String? imageJsonColumn;

  /// 自定义模块 data_json 式 JSON 对象图片列（{字段key: 图片路径}，海报值在其中）
  final String? imageJsonMapColumn;

  /// 随本行整组打包的子表：组名 → 子表名
  final Map<String, String> groups;

  const IncEntitySpec({
    required this.table,
    required this.tsColumn,
    this.imageColumns = const [],
    this.imageJsonColumn,
    this.imageJsonMapColumn,
    this.groups = const {},
  });
}

/// 仅作为父实体子组存在的表（自身不做行级 LWW）
class IncGroupSpec {
  final String table;
  final String parentTable;
  final String parentColumn;

  /// 用于检测「父行未改但子组新增」的时间戳列（可能为 null）
  final String? tsColumn;

  const IncGroupSpec({
    required this.table,
    required this.parentTable,
    required this.parentColumn,
    this.tsColumn,
  });
}

/// 增量同步的表结构定义
class IncEntities {
  /// 行级同步的实体（按时间戳 LWW）
  static const List<IncEntitySpec> entities = [
    IncEntitySpec(
      table: 'movies',
      tsColumn: 'updated_at',
      imageColumns: ['poster_path'],
      groups: {'movie_people': 'movie_people', 'movie_posters': 'movie_posters'},
    ),
    IncEntitySpec(
      table: 'books',
      tsColumn: 'updated_at',
      imageColumns: ['cover_path'],
      groups: {'book_people': 'book_people'},
    ),
    IncEntitySpec(
      table: 'notes',
      tsColumn: 'updated_at',
      imageJsonColumn: 'images',
    ),
    IncEntitySpec(
      table: 'games',
      tsColumn: 'updated_at',
      imageColumns: ['cover_path'],
      groups: {'game_people': 'game_people', 'game_screenshots': 'game_screenshots'},
    ),
    IncEntitySpec(table: 'movie_reviews', tsColumn: 'updated_at', imageJsonColumn: 'images'),
    IncEntitySpec(table: 'book_reviews', tsColumn: 'updated_at', imageJsonColumn: 'images'),
    IncEntitySpec(table: 'game_reviews', tsColumn: 'updated_at', imageJsonColumn: 'images'),
    IncEntitySpec(table: 'book_excerpts', tsColumn: 'updated_at'),
    IncEntitySpec(table: 'people', tsColumn: 'updated_at', imageColumns: ['photo_path']),
    IncEntitySpec(
      table: 'playlists',
      tsColumn: 'updated_at',
      imageColumns: ['cover_path'],
      groups: {'playlist_items': 'playlist_items'},
    ),
    IncEntitySpec(table: 'movie_characters', tsColumn: 'updated_at', imageColumns: ['image_path']),
    IncEntitySpec(table: 'book_characters', tsColumn: 'updated_at', imageColumns: ['image_path']),
    IncEntitySpec(table: 'game_characters', tsColumn: 'updated_at', imageColumns: ['image_path']),
    // 标签为追加式（无 updated_at），按 created_at 检测
    IncEntitySpec(table: 'tags', tsColumn: 'created_at'),
    // 图库自定义重命名（path 为逻辑路径，无需图片列处理）
    IncEntitySpec(table: 'image_assets', tsColumn: 'updated_at'),
    // 自定义分类模块三表；条目的海报路径在 data_json 对象值里
    IncEntitySpec(table: 'custom_modules', tsColumn: 'updated_at'),
    IncEntitySpec(table: 'custom_module_designs', tsColumn: 'updated_at'),
    IncEntitySpec(
      table: 'custom_module_items',
      tsColumn: 'updated_at',
      imageColumns: ['cover_path'],
      imageJsonMapColumn: 'data_json',
    ),
  ];

  /// 子组表规格
  static const List<IncGroupSpec> groups = [
    IncGroupSpec(table: 'movie_people', parentTable: 'movies', parentColumn: 'movie_id'),
    IncGroupSpec(table: 'movie_posters', parentTable: 'movies', parentColumn: 'movie_id', tsColumn: 'created_at'),
    IncGroupSpec(table: 'book_people', parentTable: 'books', parentColumn: 'book_id'),
    IncGroupSpec(table: 'game_people', parentTable: 'games', parentColumn: 'game_id'),
    IncGroupSpec(table: 'game_screenshots', parentTable: 'games', parentColumn: 'game_id', tsColumn: 'created_at'),
    IncGroupSpec(table: 'playlist_items', parentTable: 'playlists', parentColumn: 'playlist_id', tsColumn: 'added_at'),
  ];

  static IncEntitySpec? specOf(String table) {
    for (final s in entities) {
      if (s.table == table) return s;
    }
    return null;
  }

  static IncGroupSpec? groupSpecOf(String table) {
    for (final s in groups) {
      if (s.table == table) return s;
    }
    return null;
  }
}

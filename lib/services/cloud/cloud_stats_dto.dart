/// 数据统计页服务端聚合结果 DTO。
///
/// 对应后端 GET /app/explore/stats/aggregate：服务端按统计页 10 个分区口径聚合，
/// 一次返回周(0)/月(1)/年(2)三个 range，App 切换时间范围直接取下标，无需重新请求。
/// 只承载统计结果与高分榜（每域最多 5 条、含封面），不再下发全量原始行。
library;

/// 词频条目：导演/作者榜
class CloudNameCount {
  final String name;
  final int count;

  const CloudNameCount({required this.name, required this.count});

  factory CloudNameCount.fromJson(Map<String, dynamic> j) => CloudNameCount(
        name: j['name']?.toString() ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 高分之最单条：标题 + 评分 + 封面（唯一仍需图片 URL 的分区）
class CloudTopRatedItem {
  final String title;
  final double rating;
  final String? cover;

  const CloudTopRatedItem({required this.title, required this.rating, this.cover});

  factory CloudTopRatedItem.fromJson(Map<String, dynamic> j) => CloudTopRatedItem(
        title: j['title']?.toString() ?? '',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        cover: j['cover']?.toString(),
      );
}

/// 总览卡片
class CloudStatsOverview {
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int completed;
  final double completionRate;
  final int periodCount;
  final int lastPeriodCount;
  final double avgRating;
  final int daysTracked;

  const CloudStatsOverview({
    required this.movieCount,
    required this.bookCount,
    required this.noteCount,
    required this.completed,
    required this.completionRate,
    required this.periodCount,
    required this.lastPeriodCount,
    required this.avgRating,
    required this.daysTracked,
  });

  factory CloudStatsOverview.fromJson(Map<String, dynamic> j) => CloudStatsOverview(
        movieCount: (j['movieCount'] as num?)?.toInt() ?? 0,
        bookCount: (j['bookCount'] as num?)?.toInt() ?? 0,
        noteCount: (j['noteCount'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        completionRate: (j['completionRate'] as num?)?.toDouble() ?? 0,
        periodCount: (j['periodCount'] as num?)?.toInt() ?? 0,
        lastPeriodCount: (j['lastPeriodCount'] as num?)?.toInt() ?? 0,
        avgRating: (j['avgRating'] as num?)?.toDouble() ?? 0,
        daysTracked: (j['daysTracked'] as num?)?.toInt() ?? 0,
      );
}

/// 习惯洞察
class CloudStatsHabits {
  final int busiestMonth;
  final double avgPerMonth;
  final double watchedAvgGap;
  final double readAvgGap;

  const CloudStatsHabits({
    required this.busiestMonth,
    required this.avgPerMonth,
    required this.watchedAvgGap,
    required this.readAvgGap,
  });

  factory CloudStatsHabits.fromJson(Map<String, dynamic> j) => CloudStatsHabits(
        busiestMonth: (j['busiestMonth'] as num?)?.toInt() ?? 1,
        avgPerMonth: (j['avgPerMonth'] as num?)?.toDouble() ?? 0,
        watchedAvgGap: (j['watchedAvgGap'] as num?)?.toDouble() ?? 0,
        readAvgGap: (j['readAvgGap'] as num?)?.toDouble() ?? 0,
      );
}

/// 单个时间范围（周/月/年）的全部聚合结果
class CloudStatsRange {
  final int range;
  final CloudStatsOverview overview;
  final CloudStatsHabits habits;
  final Map<String, int> movieGenres;
  final Map<String, int> bookGenres;
  final Map<String, int> noteTags;
  final Map<String, int> gameGenres;
  final List<CloudNameCount> topDirectors;
  final List<CloudNameCount> topAuthors;
  final List<CloudTopRatedItem> topRatedMovies;
  final List<CloudTopRatedItem> topRatedBooks;
  final List<CloudTopRatedItem> topRatedGames;
  final List<int> ratingBuckets;
  final double ratingAvg;
  final List<int> trendMovie;
  final List<int> trendBook;
  final List<int> trendNote;
  final List<int> weekday;
  final List<int> cumulative;

  const CloudStatsRange({
    required this.range,
    required this.overview,
    required this.habits,
    required this.movieGenres,
    required this.bookGenres,
    required this.noteTags,
    required this.gameGenres,
    required this.topDirectors,
    required this.topAuthors,
    required this.topRatedMovies,
    required this.topRatedBooks,
    required this.topRatedGames,
    required this.ratingBuckets,
    required this.ratingAvg,
    required this.trendMovie,
    required this.trendBook,
    required this.trendNote,
    required this.weekday,
    required this.cumulative,
  });

  static Map<String, int> _intMap(dynamic v) {
    if (v is! Map) return const {};
    return v.map((k, val) => MapEntry(k.toString(), (val as num?)?.toInt() ?? 0));
  }

  static List<int> _intList(dynamic v) {
    if (v is! List) return const [];
    return v.map((e) => (e as num?)?.toInt() ?? 0).toList();
  }

  static List<CloudNameCount> _nameCounts(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => CloudNameCount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<CloudTopRatedItem> _topRated(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => CloudTopRatedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  factory CloudStatsRange.fromJson(Map<String, dynamic> j) {
    final topRated = j['topRated'] is Map ? Map<String, dynamic>.from(j['topRated'] as Map) : const {};
    final ratingDist =
        j['ratingDist'] is Map ? Map<String, dynamic>.from(j['ratingDist'] as Map) : const {};
    final trend = j['trend'] is Map ? Map<String, dynamic>.from(j['trend'] as Map) : const {};
    return CloudStatsRange(
      range: (j['range'] as num?)?.toInt() ?? 2,
      overview: CloudStatsOverview.fromJson(
          j['overview'] is Map ? Map<String, dynamic>.from(j['overview'] as Map) : const {}),
      habits: CloudStatsHabits.fromJson(
          j['habits'] is Map ? Map<String, dynamic>.from(j['habits'] as Map) : const {}),
      movieGenres: _intMap(j['movieGenres']),
      bookGenres: _intMap(j['bookGenres']),
      noteTags: _intMap(j['noteTags']),
      gameGenres: _intMap(j['gameGenres']),
      topDirectors: _nameCounts(j['topDirectors']),
      topAuthors: _nameCounts(j['topAuthors']),
      topRatedMovies: _topRated(topRated['movie']),
      topRatedBooks: _topRated(topRated['book']),
      topRatedGames: _topRated(topRated['game']),
      ratingBuckets: _intList(ratingDist['buckets']),
      ratingAvg: (ratingDist['avg'] as num?)?.toDouble() ?? 0,
      trendMovie: _intList(trend['movie']),
      trendBook: _intList(trend['book']),
      trendNote: _intList(trend['note']),
      weekday: _intList(j['weekday']),
      cumulative: _intList(j['cumulative']),
    );
  }
}

/// 统计聚合接口顶层结果：按 range 下标（0 周 / 1 月 / 2 年）取用
class CloudStatsAggregate {
  final List<CloudStatsRange> ranges;

  const CloudStatsAggregate({required this.ranges});

  factory CloudStatsAggregate.fromJson(Map<String, dynamic> j) {
    final raw = j['ranges'] is List ? j['ranges'] as List : const [];
    final list = raw
        .map((e) => CloudStatsRange.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CloudStatsAggregate(ranges: list);
  }

  /// 取指定 range，缺失时回退到年(2)或首个
  CloudStatsRange rangeAt(int range) {
    for (final r in ranges) {
      if (r.range == range) return r;
    }
    for (final r in ranges) {
      if (r.range == 2) return r;
    }
    return ranges.isNotEmpty ? ranges.first : _emptyRange(range);
  }

  static CloudStatsRange _emptyRange(int range) => CloudStatsRange(
        range: range,
        overview: const CloudStatsOverview(
            movieCount: 0,
            bookCount: 0,
            noteCount: 0,
            completed: 0,
            completionRate: 0,
            periodCount: 0,
            lastPeriodCount: 0,
            avgRating: 0,
            daysTracked: 0),
        habits: const CloudStatsHabits(
            busiestMonth: 1, avgPerMonth: 0, watchedAvgGap: 0, readAvgGap: 0),
        movieGenres: const {},
        bookGenres: const {},
        noteTags: const {},
        gameGenres: const {},
        topDirectors: const [],
        topAuthors: const [],
        topRatedMovies: const [],
        topRatedBooks: const [],
        topRatedGames: const [],
        ratingBuckets: const [],
        ratingAvg: 0,
        trendMovie: const [],
        trendBook: const [],
        trendNote: const [],
        weekday: const [],
        cumulative: const [],
      );
}

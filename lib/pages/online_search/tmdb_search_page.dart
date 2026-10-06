import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../services/tmdb_service.dart';
import '../../utils/slide_up_page_route.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'tmdb_detail_page.dart';

/// TMDB 搜索 body —— 可嵌入到统一搜索页 SearchHubPage
class TmdbSearchPageBody extends StatefulWidget {
  const TmdbSearchPageBody({super.key});

  @override
  State<TmdbSearchPageBody> createState() => _TmdbSearchPageBodyState();
}

class _TmdbSearchPageBodyState extends State<TmdbSearchPageBody> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _userPrefs = UserPrefs();
  final _tmdb = TmdbService.instance;

  String _query = '';
  bool _hasSearched = false;
  List<String> _history = [];

  List<Map<String, dynamic>> _list = [];
  int _page = 1;
  int _pageCount = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _tokenInvalid = false;

  @override
  void initState() {
    super.initState();
    _tmdb.configure(_userPrefs.tmdbApiToken, _userPrefs.tmdbAuthType);
    _history = _userPrefs.searchHistory;
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          !_loadingMore &&
          _page < _pageCount) {
        _search(_query, _page + 1);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _doSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || keyword == _query && _hasSearched) return;
    setState(() {
      _query = keyword;
      _hasSearched = true;
    });
    _userPrefs.addSearchHistory(keyword);
    _history = _userPrefs.searchHistory;
    _search(keyword, 1);
  }

  Future<void> _search(String keyword, int page) async {
    if (_userPrefs.tmdbApiToken.isEmpty) {
      ToastUtil.show(context, '请先在设置中配置 TMDB Token'.tr);
      return;
    }

    setState(() {
      if (page == 1) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      await _tmdb.ensureGenres();
      final data = await _tmdb.searchMulti(keyword, page);
      if (!mounted) return;
      final list = (data['results'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      setState(() {
        if (page == 1) {
          _list = list;
        } else {
          _list.addAll(list);
        }
        _page = data['page'] ?? page;
        _pageCount = data['total_pages'] ?? page;
        _tokenInvalid = false;
      });
    } on TmdbAuthException {
      if (mounted) setState(() => _tokenInvalid = true);
    } on TmdbNetworkException {
      if (mounted) ToastUtil.show(context, '搜索失败，请检查网络'.tr);
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Column(
        children: [
          // 搜索栏 + 搜索按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar(colors)),
                TextButton(
                  onPressed: _doSearch,
                  child: Text('搜索'.tr,
                      style: TextStyle(fontSize: 14, color: colors.primary)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _hasSearched ? _buildResults(colors) : _buildHistoryPanel(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colors) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(Icons.search,
              size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: colors.onSurface),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索电影、剧集...'.tr,
                hintStyle: TextStyle(
                    fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3)),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _hasSearched = false;
                  _list = [];
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.close,
                    size: 15, color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          if (_query.isEmpty) const SizedBox(width: 10),
        ],
      ),
    );
  }

  // ── 结果列表 ──────────────────────────────────────────────

  Widget _buildResults(ColorScheme colors) {
    if (_tokenInvalid) {
      return _buildEmptyState(
          colors, 'Token 已失效，请前往设置重新验证'.tr, Icons.vpn_key_outlined);
    }
    if (_loading) return _buildLoadingState(colors);
    if (_list.isEmpty) {
      return _buildEmptyState(colors, '未找到相关内容'.tr, Icons.search_off_outlined);
    }

    final hasMore = _page < _pageCount;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _list.length + 1,
      itemBuilder: (context, index) {
        if (index == _list.length) {
          return _buildBottomIndicator(colors, hasMore);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
                context, SlideUpPageRoute(page: TmdbDetailPage(item: _list[index]))),
            child: _buildCard(colors, _list[index]),
          ),
        );
      },
    );
  }

  Widget _buildCard(ColorScheme colors, Map<String, dynamic> item) {
    final isMovie = item['media_type'] == 'movie';
    final title = (item['title'] ?? item['name'] ?? '').toString();
    final dateStr = (item['release_date'] ?? item['first_air_date'] ?? '').toString();
    final year = dateStr.length >= 4 ? dateStr.substring(0, 4) : '';
    final poster = (item['poster_path'] ?? '').toString();
    final rating = (item['vote_average'] as num?)?.toDouble() ?? 0;
    final overview = (item['overview'] ?? '').toString();
    final genres =
        _tmdb.genreNames(item['media_type'] ?? '', item['genre_ids'] as List? ?? []);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 海报
            SizedBox(
              width: 100,
              child: poster.isNotEmpty
                  ? Image.network('${TmdbService.imageBase}$poster',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _posterPlaceholder(colors))
                  : _posterPlaceholder(colors),
            ),
            // 信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：标题 + 媒体类型
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _buildMediaTag(colors, isMovie),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 第二行：年份 + 评分
                    Row(
                      children: [
                        if (year.isNotEmpty)
                          Text(year,
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.4))),
                        if (rating > 0) ...[
                          if (year.isNotEmpty) const SizedBox(width: 8),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade700),
                          const SizedBox(width: 2),
                          Text(rating.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      colors.onSurface.withValues(alpha: 0.4))),
                        ],
                      ],
                    ),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(genres.join(' / '),
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.4)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(overview,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5),
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTag(ColorScheme colors, bool isMovie) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(isMovie ? '电影'.tr : '剧集'.tr,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600, color: colors.primary)),
    );
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined,
            size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }

  // ── 通用状态 ──────────────────────────────────────────────

  Widget _buildHistoryPanel(ColorScheme colors) {
    if (_history.isEmpty) {
      return _buildEmptyState(
          colors, '搜索你想看的电影或剧集'.tr, Icons.movie_filter_outlined);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Text('搜索历史'.tr,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                _userPrefs.clearSearchHistory();
                setState(() => _history = []);
              },
              child: Text('清空'.tr,
                  style: TextStyle(
                      fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map((h) => GestureDetector(
                    onTap: () {
                      _searchController.text = h;
                      _doSearch();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: colors.outlineVariant, width: 0.5),
                      ),
                      child: Text(h,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.6))),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colors, String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child:
                CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text('正在搜索...'.tr,
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator(ColorScheme colors, bool hasMore) {
    if (hasMore && _loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.primary)),
            const SizedBox(width: 8),
            Text('加载中...'.tr,
                style: TextStyle(
                    fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Container(height: 0.5, color: colors.outlineVariant)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              hasMore ? '' : '已经是所有数据啦'.tr,
              style: TextStyle(
                  fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 0.5, color: colors.outlineVariant)),
        ],
      ),
    );
  }
}

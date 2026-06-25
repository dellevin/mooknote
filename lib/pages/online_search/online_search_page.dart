import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import 'movie_detail_page.dart';
import 'book_detail_page.dart';

/// 在线搜索影视/书籍
class OnlineSearchPage extends StatefulWidget {
  const OnlineSearchPage({super.key});

  @override
  State<OnlineSearchPage> createState() => _OnlineSearchPageState();
}

class _OnlineSearchPageState extends State<OnlineSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _movieScrollController = ScrollController();
  final _bookScrollController = ScrollController();
  final _userPrefs = UserPrefs();

  String _query = '';
  bool _hasSearched = false;
  List<String> _history = [];

  List<Map<String, dynamic>> _movieList = [];
  int _moviePage = 1;
  int _moviePageCount = 1;
  bool _movieLoading = false;
  bool _movieLoadingMore = false;
  int _movieTotal = 0;

  List<Map<String, dynamic>> _bookList = [];
  int _bookPage = 1;
  int _bookPageCount = 1;
  bool _bookLoading = false;
  bool _bookLoadingMore = false;
  int _bookTotal = 0;

  @override
  void initState() {
    super.initState();
    _movieScrollController.addListener(_onMovieScroll);
    _bookScrollController.addListener(_onBookScroll);
    _history = _userPrefs.searchHistory;
    _currentTab = _userPrefs.lastSearchTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _movieScrollController.dispose();
    _bookScrollController.dispose();
    super.dispose();
  }

  void _onMovieScroll() {
    if (_movieScrollController.position.pixels >=
            _movieScrollController.position.maxScrollExtent - 200 &&
        !_movieLoadingMore &&
        _moviePage < _moviePageCount) {
      _loadMoreMovies();
    }
  }

  void _onBookScroll() {
    if (_bookScrollController.position.pixels >=
            _bookScrollController.position.maxScrollExtent - 200 &&
        !_bookLoadingMore &&
        _bookPage < _bookPageCount) {
      _loadMoreBooks();
    }
  }

  void _doSearch() {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _query = q;
      _hasSearched = true;
      _movieList = [];
      _moviePage = 1;
      _moviePageCount = 1;
      _movieTotal = 0;
      _bookList = [];
      _bookPage = 1;
      _bookPageCount = 1;
      _bookTotal = 0;
    });
    _userPrefs.addSearchHistory(q).then((_) {
      setState(() {
        _history = _userPrefs.searchHistory;
      });
    });
    if (_currentTab == 0) {
      _searchMovies(q, 1);
    } else {
      _searchBooks(q, 1);
    }
  }

  Future<void> _searchMovies(String keyword, int page) async {
    final token = UserPrefs().movieSearchToken;
    if (token.isEmpty) {
      if (mounted) ToastUtil.show(context, '请先在设置中配置影视搜索 Token');
      return;
    }

    setState(() {
      if (page == 1) {
        _movieLoading = true;
      } else {
        _movieLoadingMore = true;
      }
    });

    try {
      final url =
          '${ServerConfig.vipBaseUrl}/api/movie/list?movieName=${Uri.encodeComponent(keyword)}&token=$token&page=$page';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 0 && data['data'] != null) {
          final list = (data['data']['list'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          setState(() {
            if (page == 1) {
              _movieList = list;
            } else {
              _movieList.addAll(list);
            }
            _movieTotal = data['data']['total'] ?? 0;
            _moviePage = data['data']['page'] ?? page;
            _moviePageCount = data['data']['pagecount'] ?? page;
          });
        } else if (data['code'] == 401 ||
            data['code'] == 403 ||
            data['msg']?.toString().contains('token') == true ||
            data['msg']?.toString().contains('过期') == true) {
          if (mounted)
            setState(() {
              _movieLoading = false;
              _movieLoadingMore = false;
            });
          _showTokenExpiredDialog();
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('TimeoutException') ? '搜索超时，请稍后重试' : '搜索失败，请检查网络';
        ToastUtil.show(context, msg);
      }
    }

    if (mounted) {
      setState(() {
        _movieLoading = false;
        _movieLoadingMore = false;
      });
    }
  }

  void _loadMoreMovies() {
    _searchMovies(_query, _moviePage + 1);
  }

  Future<void> _searchBooks(String keyword, int page) async {
    final token = UserPrefs().bookSearchToken;
    if (token.isEmpty) return;

    setState(() {
      if (page == 1) {
        _bookLoading = true;
      } else {
        _bookLoadingMore = true;
      }
    });

    try {
      final url =
          '${ServerConfig.vipBaseUrl}/api/book/list?title=${Uri.encodeComponent(keyword)}&token=$token&page=$page';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['code'] == 0 && data['data'] != null) {
          final list = (data['data']['list'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              [];
          setState(() {
            if (page == 1) {
              _bookList = list;
            } else {
              _bookList.addAll(list);
            }
            _bookTotal = data['data']['total'] ?? 0;
            _bookPage = data['data']['page'] ?? page;
            _bookPageCount = data['data']['pagecount'] ?? page;
          });
        } else if (data['code'] == 401 ||
            data['code'] == 403 ||
            data['msg']?.toString().contains('token') == true ||
            data['msg']?.toString().contains('过期') == true) {
          if (mounted)
            setState(() {
              _bookLoading = false;
              _bookLoadingMore = false;
            });
          _showTokenExpiredDialog();
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('TimeoutException') ? '搜索超时，请稍后重试' : '搜索失败，请检查网络';
        ToastUtil.show(context, msg);
      }
    }

    if (mounted) {
      setState(() {
        _bookLoading = false;
        _bookLoadingMore = false;
      });
    }
  }

  void _loadMoreBooks() {
    _searchBooks(_query, _bookPage + 1);
  }

  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        titleSpacing: 8,
        title: _buildSearchBar(colors),
        actions: [
          TextButton(
            onPressed: _doSearch,
            child: Text('搜索',
                style: TextStyle(fontSize: 14, color: colors.primary)),
          ),
        ],
        bottom: _hasSearched
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: colors.outlineVariant, width: 0.5))),
                  child: Row(children: [
                    _buildTabButton(colors, '影视', 0, _movieTotal),
                    _buildTabButton(colors, '书籍', 1, _bookTotal),
                  ]),
                ),
              )
            : null,
      ),
      body: _hasSearched
          ? (_currentTab == 0
              ? _buildMovieResults(colors)
              : _buildBookResults(colors))
          : _buildHistoryPanel(colors),
    );
  }

  Widget _buildTabButton(
      ColorScheme colors, String label, int index, int count) {
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () {
        if (_currentTab == index) return;
        setState(() => _currentTab = index);
        _userPrefs.setLastSearchTab(index);
        // 切到新 tab 时，若该 tab 尚无数据则触发搜索
        if (_hasSearched && _query.isNotEmpty) {
          if (index == 0 && _movieList.isEmpty && !_movieLoading) {
            _searchMovies(_query, 1);
          } else if (index == 1 && _bookList.isEmpty && !_bookLoading) {
            _searchBooks(_query, 1);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: selected ? colors.primary : Colors.transparent,
                  width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.4))),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.1)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.4))),
              ),
            ],
          ],
        ),
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
              focusNode: _focusNode,
              style: TextStyle(fontSize: 13, color: colors.onSurface),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索影视、书籍...',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.3)),
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
                  _movieList = [];
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

  void _showTokenExpiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: c.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Token 已过期',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          content: Text('当前 Token 已过期，请重新获取',
              style: TextStyle(
                  fontSize: 14,
                  color: c.onSurface.withValues(alpha: 0.6),
                  height: 1.5)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('知道了', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  // ── 影视搜索结果 ──────────────────────────────────────────────

  Widget _buildMovieResults(ColorScheme colors) {
    if (!_hasSearched)
      return _buildEmptyState(colors, '搜索你想看的影视作品', Icons.movie_outlined);
    if (UserPrefs().movieSearchToken.isEmpty)
      return _buildEmptyState(
          colors, '填入 Token 后可正常使用该功能', Icons.vpn_key_outlined);
    if (_movieLoading) return _buildLoadingState(colors);
    if (_movieList.isEmpty)
      return _buildEmptyState(colors, '未找到相关内容', Icons.search_off_outlined);

    final hasMore = _moviePage < _moviePageCount;
    final itemCount = _movieList.length + 1; // +1 for bottom indicator

    return ListView.builder(
      controller: _movieScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _movieList.length) {
          return _buildBottomIndicator(colors, hasMore,
              loadingMore: _movieLoadingMore);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MovieDetailPage(vodId: _movieList[index]['vod_id']))),
            child: _buildMovieCard(colors, _movieList[index]),
          ),
        );
      },
    );
  }

  Widget _buildMovieCard(ColorScheme colors, Map<String, dynamic> m) {
    final name = m['vod_name'] ?? '';
    final year = m['vod_year'] ?? '';
    final area = m['vod_area'] ?? '';
    final typeName = m['type_name'] ?? '';
    final className = m['vod_class'] ?? '';
    final director = m['vod_director'] ?? '';
    final pic = m['vod_pic'] ?? '';
    final isEnd = m['vod_isend'] ?? 0;
    final isManual = m['is_manual_optimized'] ?? 0;
    final tag = m['vod_tag'] ?? '';

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
              child: pic.toString().isNotEmpty
                  ? Image.network(pic,
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
                    // 第一行：名称 + 完结状态
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _buildStatusTag(colors, isEnd),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 第二行：年份+地区+类型
                    _buildInfoRow(colors, [
                      if (year.toString().isNotEmpty) year.toString(),
                      if (area.toString().isNotEmpty) area.toString(),
                      if (typeName.toString().isNotEmpty) typeName.toString(),
                    ]),
                    if (className.toString().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(className,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.4)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 6),
                    // 第三行：官方优化 + 标签
                    if (isManual == 1 || tag.toString().isNotEmpty)
                      _buildTagRow(colors, isManual, tag.toString()),
                    // 第四行：导演
                    if (director.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 12,
                              color: colors.onSurface.withValues(alpha: 0.35)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(director,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurface
                                        .withValues(alpha: 0.5)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
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

  Widget _buildStatusTag(ColorScheme colors, int isEnd) {
    final isFinished = isEnd == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isFinished
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isFinished ? '已完结' : '连载中',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isFinished ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ColorScheme colors, List<String> items) {
    return Wrap(
      spacing: 6,
      children: items
          .map((s) => Text(s,
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.5))))
          .toList(),
    );
  }

  Widget _buildTagRow(ColorScheme colors, int isManual, String tag) {
    final tags = tag.split(',').where((t) => t.trim().isNotEmpty).toList();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (isManual == 1)
          _buildSmallTag('官方优化', const Color(0xFF16A34A), isHighlight: true),
        ...tags.take(4).map((t) =>
            _buildSmallTag(t.trim(), colors.onSurface.withValues(alpha: 0.4))),
        if (tags.length > 4)
          Text('+${tags.length - 4}',
              style: TextStyle(
                  fontSize: 10,
                  color: colors.onSurface.withValues(alpha: 0.3))),
      ],
    );
  }

  Widget _buildSmallTag(String text, Color textColor,
      {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : textColor.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              color: isHighlight ? const Color(0xFF16A34A) : textColor)),
    );
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
          child: Icon(Icons.movie_outlined,
              size: 28, color: colors.onSurface.withValues(alpha: 0.2))),
    );
  }

  // ── 书籍搜索结果 ──────────────────────────────────────────────

  Widget _buildBookResults(ColorScheme colors) {
    if (!_hasSearched)
      return _buildEmptyState(colors, '搜索你想看的书籍', Icons.menu_book_outlined);
    if (UserPrefs().bookSearchToken.isEmpty)
      return _buildEmptyState(
          colors, '填入 Token 后可正常使用该功能', Icons.vpn_key_outlined);
    if (_bookLoading) return _buildLoadingState(colors);
    if (_bookList.isEmpty)
      return _buildEmptyState(colors, '未找到相关书籍', Icons.search_off_outlined);

    final hasMore = _bookPage < _bookPageCount;
    final itemCount = _bookList.length + 1;

    return ListView.builder(
      controller: _bookScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _bookList.length) {
          return _buildBottomIndicator(colors, hasMore,
              loadingMore: _bookLoadingMore);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BookDetailPage(
                        bookId: _bookList[index]['id'].toString()))),
            child: _buildBookCard(colors, _bookList[index]),
          ),
        );
      },
    );
  }

  Widget _buildBookCard(ColorScheme colors, Map<String, dynamic> b) {
    final title = b['title'] ?? '';
    final author = b['author'] ?? '';
    final press = b['press'] ?? '';
    final year = b['publishedDate'] ?? '';
    final cover = b['cover'] ?? '';
    final isbn = b['isbn'] ?? '';

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
            SizedBox(
              width: 80,
              child: cover.toString().isNotEmpty
                  ? Image.network(cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _bookCoverPlaceholder(colors))
                  : _bookCoverPlaceholder(colors),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (author.toString().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(author,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (press.toString().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(press,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.4)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    if (year.toString().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text('出版年份 $year',
                          style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurface.withValues(alpha: 0.35))),
                    ],
                    if (isbn.toString().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text('ISBN $isbn',
                          style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurface.withValues(alpha: 0.35))),
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

  Widget _bookCoverPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
          child: Icon(Icons.menu_book_outlined,
              size: 24, color: colors.onSurface.withValues(alpha: 0.2))),
    );
  }

  // ── 通用状态 ──────────────────────────────────────────────────

  Widget _buildLoadingState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text('正在搜索...',
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator(ColorScheme colors, bool hasMore,
      {bool loadingMore = false}) {
    if (hasMore && loadingMore) {
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
            Text('加载中...',
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4))),
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
              '已经是所有数据啦，要是没有的话，请联系开发者添加哦~',
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

  // ── 搜索历史 ──────────────────────────────────────────────────

  Widget _buildHistoryPanel(ColorScheme colors) {
    if (_history.isEmpty)
      return _buildEmptyState(colors, '搜索你想看的影视作品', Icons.movie_outlined);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Text('搜索历史',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final c = Theme.of(ctx).colorScheme;
                    return AlertDialog(
                      backgroundColor: c.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      title: Text('清空搜索记录',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: c.onSurface)),
                      content: Text('确定删除全部搜索记录？',
                          style: TextStyle(
                              fontSize: 14,
                              color: c.onSurface.withValues(alpha: 0.6),
                              height: 1.5)),
                      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                              foregroundColor:
                                  c.onSurface.withValues(alpha: 0.6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child:
                              const Text('取消', style: TextStyle(fontSize: 14)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _userPrefs.clearSearchHistory();
                            setState(() {
                              _history = [];
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: c.error,
                              foregroundColor: c.onError,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child:
                              const Text('清空', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text('清空',
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.4))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history
              .map((kw) => GestureDetector(
                    onTap: () {
                      _searchController.text = kw;
                      _doSearch();
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final c = Theme.of(ctx).colorScheme;
                          return AlertDialog(
                            backgroundColor: c.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            title: Text('删除搜索记录',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: c.onSurface)),
                            content: Text('确定删除「$kw」？',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: c.onSurface.withValues(alpha: 0.6),
                                    height: 1.5)),
                            actionsPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      c.onSurface.withValues(alpha: 0.6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('取消',
                                    style: TextStyle(fontSize: 14)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _userPrefs.removeSearchHistory(kw).then((_) {
                                    if (mounted)
                                      setState(() {
                                        _history = _userPrefs.searchHistory;
                                      });
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.error,
                                  foregroundColor: c.onError,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('删除',
                                    style: TextStyle(fontSize: 14)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: colors.outlineVariant, width: 0.5),
                      ),
                      child: Text(kw,
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

  Widget _buildEmptyState(ColorScheme colors, String hint, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon,
                size: 36, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 20),
          Text(hint,
              style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.35))),
          const SizedBox(height: 4),
          Text('输入关键词后点击搜索',
              style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.2))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../services/douban_service.dart';
import '../../widgets/douban_network_image.dart';
import '../../utils/slide_up_page_route.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'douban_detail_page.dart';
import 'douban_settings_page.dart';

/// 豆瓣搜索 body —— 可嵌入统一搜索页 SearchHubPage。
/// 综合（匿名首屏）/ 书籍 / 影视（登录后分类翻页）三段。
class DoubanSearchPageBody extends StatefulWidget {
  const DoubanSearchPageBody({super.key});

  @override
  State<DoubanSearchPageBody> createState() => _DoubanSearchPageBodyState();
}

class _DoubanSearchPageBodyState extends State<DoubanSearchPageBody> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _userPrefs = UserPrefs();
  final _svc = DoubanService.instance;

  // mix=综合 / book=书籍 / movie=影视
  late String _segment;
  String _query = '';
  bool _hasSearched = false;
  List<String> _history = [];

  final List<DoubanSearchItem> _list = [];
  int _start = 0;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _authInvalid = false;
  int _callSeq = 0;

  bool get _isMix => _segment == 'mix';
  bool get _hasMore => _isMix ? false : _list.length < _total;

  @override
  void initState() {
    super.initState();
    _segment = _userPrefs.doubanSearchSegment;
    if (!const {'mix', 'book', 'movie'}.contains(_segment)) _segment = 'mix';
    _svc.configure(_userPrefs.doubanCookies, proxy: _userPrefs.doubanProxy);
    _history = _userPrefs.searchHistory;
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loading &&
          !_loadingMore &&
          _hasMore) {
        _search(_query, _start);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _switchSegment(String segment) {
    if (_segment == segment) return;
    setState(() {
      _segment = segment;
      _list.clear();
      _start = 0;
      _total = 0;
      _hasSearched = false;
      _authInvalid = false;
      _query = '';
      _searchController.clear();
    });
    _userPrefs.setDoubanSearchSegment(segment);
  }

  void _doSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || keyword == _query && _hasSearched) return;
    setState(() {
      _query = keyword;
      _hasSearched = true;
      _list.clear();
      _start = 0;
      _total = 0;
      _loadingMore = false;
      _authInvalid = false;
    });
    _userPrefs.addSearchHistory(keyword);
    _history = _userPrefs.searchHistory;
    _search(keyword, 0);
  }

  Future<void> _search(String keyword, int start) async {
    final callSeq = ++_callSeq;
    if (!_isMix && !_svc.isLoggedIn) {
      if (callSeq == _callSeq) setState(() => _authInvalid = true);
      return;
    }
    setState(() {
      if (start == 0) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });
    try {
      if (_isMix) {
        final items = await _svc.searchMix(keyword);
        if (!mounted || callSeq != _callSeq) return;
        setState(() {
          _list
            ..clear()
            ..addAll(items);
          _total = items.length;
        });
      } else {
        final cat = _segment == 'book'
            ? DoubanService.catBook
            : DoubanService.catMovie;
        final result = await _svc.searchCategory(keyword, cat, start);
        if (!mounted || callSeq != _callSeq) return;
        setState(() {
          _list.addAll(result.items);
          _start = start + result.items.length;
          _total = result.total;
        });
      }
    } on DoubanAuthException {
      if (mounted && callSeq == _callSeq) setState(() => _authInvalid = true);
    } on DoubanNetworkException {
      if (mounted && callSeq == _callSeq) {
        ToastUtil.show(context, '搜索失败，请检查网络'.tr);
      }
    }
    if (mounted && callSeq == _callSeq) {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(child: _buildSearchBar(colors)),
                TextButton(
                  onPressed: _doSearch,
                  child: Text('搜索'.tr,
                      style:
                          TextStyle(fontSize: 14, color: colors.primary)),
                ),
              ],
            ),
          ),
          _buildSegmentBar(colors),
          Expanded(
            child: _hasSearched || _authInvalid
                ? _buildResults(colors)
                : _buildHistoryPanel(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentBar(ColorScheme colors) {
    final tabs = [
      ('mix', '综合'.tr),
      ('book', '书籍'.tr),
      ('movie', '影视'.tr),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final (value, label) in tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _switchSegment(value),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _segment == value
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _segment == value
                          ? colors.primary.withValues(alpha: 0.4)
                          : colors.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _segment == value
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.5),
                      )),
                ),
              ),
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
                hintText: '搜索影视、书籍...'.tr,
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
                  _list.clear();
                });
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.close,
                    size: 15,
                    color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          if (_query.isEmpty) const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme colors) {
    if (_authInvalid) {
      return _buildLoginPrompt(colors);
    }
    if (_loading) return _buildLoadingState(colors);
    if (_list.isEmpty) {
      return _buildEmptyState(colors, '未找到相关内容'.tr, Icons.search_off_outlined);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _list.length + 1,
      itemBuilder: (context, index) {
        if (index == _list.length) {
          return _buildBottomIndicator(colors);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.push(
                context,
                SlideUpPageRoute(
                    page: DoubanDetailPage(item: _list[index]))),
            child: _buildCard(colors, _list[index]),
          ),
        );
      },
    );
  }

  Widget _buildLoginPrompt(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_outlined,
                size: 48, color: colors.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('分类翻页搜索需要先登录豆瓣'.tr,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DoubanSettingsPage()));
                if (mounted) {
                  _svc.configure(_userPrefs.doubanCookies,
                      proxy: _userPrefs.doubanProxy);
                  setState(() => _authInvalid = !_svc.isLoggedIn);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('去登录'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ColorScheme colors, DoubanSearchItem item) {
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
              width: 100,
              child: item.coverUrl.isNotEmpty
                  ? DoubanNetworkImage(
                      url: item.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: _coverPlaceholder(colors))
                  : _coverPlaceholder(colors),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _buildTypeTag(colors, item.typeName),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (item.year.isNotEmpty)
                          Text(item.year,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4))),
                        if (item.rating.isNotEmpty) ...[
                          if (item.year.isNotEmpty) const SizedBox(width: 8),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade700),
                          const SizedBox(width: 2),
                          Text(item.rating,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4))),
                        ],
                      ],
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.subtitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.5),
                              height: 1.4),
                          maxLines: 3,
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

  Widget _buildTypeTag(ColorScheme colors, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: colors.primary)),
    );
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _buildHistoryPanel(ColorScheme colors) {
    if (_history.isEmpty) {
      return _buildEmptyState(
          colors, '搜索你想找的影视或书籍'.tr, Icons.explore_outlined);
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
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.4))),
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
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: colors.primary),
          ),
          const SizedBox(height: 16),
          Text('正在搜索...'.tr,
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildBottomIndicator(ColorScheme colors) {
    if (_loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.primary),
            ),
            const SizedBox(width: 8),
            Text('加载中...'.tr,
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
              _hasMore ? '' : '已经是所有数据啦'.tr,
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.3)),
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

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/epub/reader_dao.dart';
import '../../services/epub/epub_service.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import 'epub_detail_page.dart';

/// EPUB 书架页面
class EpubLibraryPage extends StatefulWidget {
  const EpubLibraryPage({super.key});

  @override
  State<EpubLibraryPage> createState() => _EpubLibraryPageState();
}

class _EpubLibraryPageState extends State<EpubLibraryPage> {
  final ReaderDao _dao = ReaderDao();
  final EpubService _service = EpubService();
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  int _sortMode = UserPrefs().epubSortMode;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    if (mounted) setState(() => _isLoading = true);
    final books = await _dao.getAllReaderBooks(sortMode: _sortMode);
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredBooks = _books;
    } else {
      _filteredBooks = _books.where((b) {
        final title = (b['title'] as String? ?? '').toLowerCase();
        final author = (b['author'] as String? ?? '').toLowerCase();
        return title.contains(query) || author.contains(query);
      }).toList();
    }
  }

  void _onSearchChanged() {
    setState(() => _applyFilter());
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchCtrl.clear();
        _applyFilter();
      }
    });
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.epub')) {
      if (mounted) {
        ToastUtil.show(context, '\u4EC5\u652F\u6301\u5BFC\u5165 .epub \u683C\u5F0F\u7684\u6587\u4EF6');
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final imported = await _service.importBook(path);

    if (mounted) Navigator.pop(context);

    if (imported != null) {
      await _loadBooks();
    } else if (mounted) {
      ToastUtil.show(context, 'EPUB \u89E3\u6790\u5931\u8D25\uFF0C\u8BF7\u68C0\u67E5\u6587\u4EF6');
    }
  }

  Future<void> _deleteBook(Map<String, dynamic> book) async {
    final colors = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('删除书籍',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定删除《${book['title']}》？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteBook(book['id']);
      await _loadBooks();
    }
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpubDetailPage(bookId: book['id'], book: book),
      ),
    ).then((_) {
      if (mounted) _loadBooks();
    });
  }

  void _showSortMenu() {
    final colors = Theme.of(context).colorScheme;
    final options = [
      (0, '按更新时间排序', Icons.update),
      (1, '按创建时间排序', Icons.calendar_today_outlined),
      (2, '按阅读进度排序', Icons.auto_stories_outlined),
      (3, '按书名排序', Icons.sort_by_alpha),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('书架排序', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
          const SizedBox(height: 8),
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
            _sortOption(ctx, options[i].$1, options[i].$2, options[i].$3, colors),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, int value, String label, IconData icon, ColorScheme colors) {
    final selected = _sortMode == value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: colors.onSurface)),
      trailing: selected ? Icon(Icons.check, size: 20, color: colors.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        if (_sortMode != value) {
          setState(() => _sortMode = value);
          UserPrefs().setEpubSortMode(value);
          _loadBooks();
        }
      },
    );
  }

  /// 找到最近在读的书（进度 > 0 且 < 1，按更新时间排序取第一本）
  Map<String, dynamic>? get _lastReadingBook {
    final reading = _books.where((b) {
      final p = (b['reading_percentage'] as num?)?.toDouble() ?? 0.0;
      return p > 0.0 && p < 1.0;
    }).toList();
    if (reading.isEmpty) return null;
    return reading.first;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWin = Platform.isWindows;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: isWin ? null : AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 16, color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: '搜索书名或作者',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.35)),
                  border: InputBorder.none,
                ),
                onChanged: (_) => _onSearchChanged(),
              )
            : Text('EPUB 阅读',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
        leading: IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.arrow_back, size: 20),
          onPressed: _isSearching ? _toggleSearch : () => Navigator.pop(context),
        ),
        actions: _buildActions(colors),
      ),
      body: Column(children: [
        // Windows: 自定义顶栏
        if (isWin)
          Container(
            height: 52,
            decoration: BoxDecoration(color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
            child: Row(children: [
              const SizedBox(width: 8),
              IconButton(icon: Icon(_isSearching ? Icons.close : Icons.arrow_back, color: colors.onSurface, size: 18),
                onPressed: _isSearching ? _toggleSearch : () => Navigator.pop(context)),
              Expanded(child: _isSearching
                  ? TextField(controller: _searchCtrl, autofocus: true,
                      style: TextStyle(fontSize: 14, color: colors.onSurface),
                      decoration: InputDecoration(hintText: '搜索书名或作者',
                        hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      onChanged: (_) => _onSearchChanged())
                  : Text('EPUB 阅读',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6)))),
              ..._buildActions(colors),
            ]),
          ),
        // 主体
        Expanded(child: _isLoading
            ? Center(child: CircularProgressIndicator(color: colors.primary))
            : _books.isEmpty
                ? _buildEmpty(colors)
                : _filteredBooks.isEmpty
                    ? Center(child: Text('无搜索结果', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35))))
                    : RefreshIndicator(
                        color: colors.primary,
                        onRefresh: _loadBooks,
                        child: _buildContent(colors),
                      )),
      ]),
    );
  }

  /// 主体内容：继续阅读横幅 + 书架列表
  Widget _buildContent(ColorScheme colors) {
    final lastBook = _lastReadingBook;
    return CustomScrollView(
      slivers: [
        // 继续阅读横幅
        if (lastBook != null && !_isSearching)
          SliverToBoxAdapter(child: _buildContinueReading(colors, lastBook)),
        // 书架列表
        _buildSliverListView(colors),
      ],
    );
  }

  /// 继续阅读横幅卡片 — 封面背景 + 毛玻璃
  Widget _buildContinueReading(ColorScheme colors, Map<String, dynamic> book) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final coverPath = book['cover_path'] as String?;
    final progress = (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
    final percentStr = '${(progress * 100).toInt()}%';
    final hasCover = coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openBook(book),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  // 底层：封面图做背景
                  if (hasCover)
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: Image.file(
                        File(coverPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: colors.primaryContainer),
                      ),
                    ),
                  // 毛玻璃遮罩层
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        height: 140,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.35),
                          borderRadius: hasCover ? BorderRadius.zero : BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 封面
                            Container(
                              width: 56,
                              height: 78,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: colors.outlineVariant,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(2, 3),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildCover(coverPath, colors),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: colors.onSurface,
                                      )),
                                  if (author.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurface.withValues(alpha: 0.55),
                                        )),
                                  ],
                                  const Spacer(),
                                  // 进度条 + 百分比
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 6,
                                            backgroundColor: colors.primary.withValues(alpha: 0.15),
                                            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(percentStr,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: colors.primary,
                                          )),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // 继续阅读按钮
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.play_arrow_rounded, size: 16, color: colors.onPrimary),
                                          const SizedBox(width: 4),
                                          Text('继续阅读',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: colors.onPrimary,
                                              )),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 书架分隔
          Padding(
            padding: const EdgeInsets.only(top: 20, left: 4, bottom: 4),
            child: Row(
              children: [
                Text('书架',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.45),
                    )),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 0.5,
                    color: colors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(ColorScheme colors) {
    return [
      if (!_isSearching)
        IconButton(
          icon: Icon(Icons.search, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
          onPressed: _toggleSearch,
        ),
      IconButton(
        icon: Icon(Icons.sort, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
        onPressed: _showSortMenu,
      ),
      IconButton(
        icon: Icon(Icons.add_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
        onPressed: _pickAndImport,
      ),
      const SizedBox(width: 4),
    ];
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_stories_outlined,
                  size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 24),
            Text('EPUB 阅读',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 8),
            Text('点击右上角导入 .epub 文件',
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickAndImport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('导入 EPUB',
                    style: TextStyle(fontSize: 15, color: colors.onPrimary, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sliver 书架 ────────────────────────────────────────────────────

  Widget _buildSliverListView(ColorScheme colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildListItem(colors, _filteredBooks[index]),
          childCount: _filteredBooks.length,
        ),
      ),
    );
  }

  Widget _buildListItem(ColorScheme colors, Map<String, dynamic> book) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final coverPath = book['cover_path'] as String?;
    final progress = (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
    final updatedAt = book['updated_at'] as String?;

    // 阅读状态推断
    final String statusLabel;
    final Color statusColor;
    if (progress >= 1.0) {
      statusLabel = '已读';
      statusColor = const Color(0xFF16A34A);
    } else if (progress > 0.0) {
      statusLabel = '在读';
      statusColor = colors.primary;
    } else {
      statusLabel = '未读';
      statusColor = const Color(0xFFDC2626);
    }

    // 最后阅读时间
    String? lastReadText;
    if (updatedAt != null && updatedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(updatedAt);
        lastReadText = _formatRelativeDate(dt);
      } catch (_) {}
    }

    return RepaintBoundary(
      child: GestureDetector(
      onTap: () => _openBook(book),
      onLongPress: () => _deleteBook(book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 封面
            Container(
              width: 48, height: 64,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildCover(coverPath, colors),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                  const SizedBox(height: 6),
                  // 状态标签 + 最后阅读时间
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                      ),
                      if (lastReadText != null) ...[
                        const SizedBox(width: 8),
                        Text(lastReadText,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.3),
                            )),
                      ],
                    ],
                  ),
                  // 进度条
                  if (progress > 0 && progress < 1.0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: colors.outlineVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.primary,
                            )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCover(String? path, ColorScheme colors) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            color: colors.outlineVariant,
            child: Icon(Icons.auto_stories_outlined, size: 22,
                color: colors.onSurface.withValues(alpha: 0.25)),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.auto_stories_outlined, size: 22,
          color: colors.onSurface.withValues(alpha: 0.25)),
    );
  }

  /// 相对时间格式化
  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.isNegative) return '${date.month}月${date.day}日';
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return '刚刚';
        return '${diff.inMinutes}分钟前';
      }
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}周前';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

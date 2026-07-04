import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../utils/epub/reader_dao.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'highlight_detail_sheet.dart';
import 'reader_screen.dart';

/// EPUB 句读（高亮）管理页面 —— 支持瀑布流/列表模式切换
class EpubHighlightsPage extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> book;
  final void Function(Map<String, dynamic> highlight)? onNavigateToHighlight;

  const EpubHighlightsPage({
    super.key,
    required this.bookId,
    required this.book,
    this.onNavigateToHighlight,
  });

  @override
  State<EpubHighlightsPage> createState() => _EpubHighlightsPageState();
}

class _EpubHighlightsPageState extends State<EpubHighlightsPage> {
  final ReaderDao _dao = ReaderDao();
  List<Map<String, dynamic>> _highlights = [];
  bool _isLoading = true;
  bool _isListMode = UserPrefs().highlightsViewMode == 1;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    setState(() => _isLoading = true);
    try {
      final all = await _dao.getHighlightsByBookId(widget.bookId);
      setState(() {
        _highlights = all.where((h) => h['color'] != 'excerpt').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ToastUtil.show(context, '加载失败: $e');
    }
  }

  void _toggleViewMode() {
    setState(() => _isListMode = !_isListMode);
    UserPrefs().setHighlightsViewMode(_isListMode ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('句读', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.refresh_rounded, size: 22),
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadHighlights,
          ),
          IconButton(
            icon: Icon(
              _isListMode ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
              size: 22,
            ),
            tooltip: _isListMode ? '瀑布流' : '列表',
            onPressed: _toggleViewMode,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _highlights.isEmpty
              ? _buildEmpty(colors)
              : _isListMode
                  ? _buildListView(colors)
                  : _buildMasonryView(colors),
    );
  }

  // ─── 瀑布流模式 ───

  Widget _buildMasonryView(ColorScheme colors) {
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemCount: _highlights.length,
      itemBuilder: (context, i) => _buildMasonryCard(_highlights[i], colors),
    );
  }

  Widget _buildMasonryCard(Map<String, dynamic> highlight, ColorScheme colors) {
    final content = highlight['content'] as String? ?? '';
    final chapter = highlight['chapter'] as String? ?? '';
    final chapterNum = int.tryParse(chapter);
    final createdAt = highlight['created_at'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showDetail(highlight, colors),
      onLongPress: () => _showDeleteConfirm(highlight['id'] as int, colors),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 高亮文本
            Text(
              content,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.85),
                height: 1.65,
              ),
            ),
            const SizedBox(height: 8),
            // 底部信息行
            Row(
              children: [
                if (chapterNum != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '第${chapterNum + 1}章',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                if (createdAt.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 列表模式 ───

  Widget _buildListView(ColorScheme colors) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _highlights.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildListCard(_highlights[i], colors),
    );
  }

  Widget _buildListCard(Map<String, dynamic> highlight, ColorScheme colors) {
    final content = highlight['content'] as String? ?? '';
    final chapter = highlight['chapter'] as String? ?? '';
    final chapterNum = int.tryParse(chapter);
    final createdAt = highlight['created_at'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showDetail(highlight, colors),
      onLongPress: () => _showDeleteConfirm(highlight['id'] as int, colors),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 章节 + 日期
            Row(
              children: [
                Icon(Icons.highlight_outlined, size: 13, color: const Color(0xFFFFC107)),
                if (chapterNum != null) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '第${chapterNum + 1}章',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const Spacer(),
                if (createdAt.isNotEmpty)
                  Text(
                    _formatDateFull(createdAt),
                    style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // 高亮文本
            Text(
              content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.85),
                height: 1.75,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 公共 ───

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.highlight_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('暂无句读', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> highlight, ColorScheme colors) {
    showHighlightDetailSheet(
      context,
      highlight: highlight,
      book: widget.book,
      onDelete: () => _deleteHighlight(highlight['id'] as int),
      onNavigate: () => _navigateToHighlight(highlight),
    );
  }

  void _navigateToHighlight(Map<String, dynamic> highlight) {
    final chapter = int.tryParse(highlight['chapter'] as String? ?? '') ?? 0;
    final xpath = _extractStartXPath(highlight['cfi'] as String? ?? '');
    final text = highlight['content'] as String? ?? '';

    if (widget.onNavigateToHighlight != null) {
      widget.onNavigateToHighlight!(highlight);
      return;
    }

    // 默认行为：先关闭当前页面，再打开阅读器跳转
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: widget.book['id'] as String,
          filePath: widget.book['file_path'] as String,
          title: widget.book['title'] as String? ?? '',
          bookData: widget.book,
          initialSpineIndex: chapter,
          scrollToXPath: xpath,
          scrollToText: text,
        ),
      ),
    );
  }

  String? _extractStartXPath(String cfi) {
    if (cfi.isEmpty) return null;
    try {
      final decoded = jsonDecode(cfi) as Map<String, dynamic>;
      return decoded['startXPath'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _formatDateFull(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _showDeleteConfirm(int id, ColorScheme colors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定删除这条句读？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteHighlight(id); },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHighlight(int id) async {
    await _dao.deleteHighlight(id);
    _loadHighlights();
    if (mounted) ToastUtil.show(context, '已删除');
  }
}

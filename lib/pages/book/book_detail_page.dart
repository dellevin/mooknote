import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'book_reviews_page.dart';
import 'book_excerpts_page.dart';
import 'book_share_page.dart';
import '../../utils/epub/reader_dao.dart';
import '../epub_reader/epub_highlights_page.dart';
import '../epub_reader/reader_screen.dart';

/// 书籍详情页 - 极简主义设计
class BookDetailPage extends StatefulWidget {
  final Book book;
  final bool embedded;

  const BookDetailPage({super.key, required this.book, this.embedded = false});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late int _detailStyle;
  final ValueNotifier<double> _coverOffset = ValueNotifier(0.0);
  double _coverDragStartOffset = 0.0;
  final ValueNotifier<bool> _draggingCover = ValueNotifier(false);
  final GlobalKey _coverImageKey = GlobalKey();
  double _coverImageHeight = 0.0;
  final ValueNotifier<bool> _showTitle = ValueNotifier(false);
  ScrollController? _overlayScrollController;

  @override
  void dispose() {
    _coverOffset.dispose();
    _draggingCover.dispose();
    _showTitle.dispose();
    _overlayScrollController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _detailStyle = UserPrefs().detailPageStyle;
    _coverOffset.value = UserPrefs().getCoverOffset(widget.book.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final book = context.watch<AppProvider>().books
        .where((b) => b.id == widget.book.id)
        .firstOrNull ?? widget.book;

    if (_detailStyle == 1) {
      return _buildOverlayStyle(book, colors);
    }
    return _buildStandardStyle(book, colors);
  }

  /// 标准样式
  Widget _buildStandardStyle(Book book, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          // 整体可滚动（封面 + 内容一起滑动）
          Padding(
            padding: EdgeInsets.only(top: topSafe + 48),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: _buildCoverSection(book),
                  ),
                  // 详细信息
                  _buildBasicInfo(book),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  _buildAuthorsSection(book),
                  if (book.genres.isNotEmpty) _buildGenresSection(book),
                  if (book.isbn != null && book.isbn!.isNotEmpty) _buildIsbnSection(book),
                  if (book.publisher != null && book.publisher!.isNotEmpty) _buildPublisherSection(book),
                  if (book.publishDate != null) _buildPublishDateSection(book),
                  if (book.startDate != null || book.finishDate != null) _buildReadingDatesSection(book),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  if (book.summary != null && book.summary!.isNotEmpty) _buildSummarySection(book),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  _buildExtraSections(book),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          _buildStandardTopBar(book.title, colors),
          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(book)),
        ],
      ),
    );
  }

  /// 毛玻璃层叠样式：海报背景 + 毛玻璃 + 内容
  Widget _buildOverlayStyle(Book book, ColorScheme colors) {
    final screenH = MediaQuery.of(context).size.height;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    _overlayScrollController ??= ScrollController()..addListener(() {
      final show = (_overlayScrollController?.offset ?? 0) > 10;
      if (_showTitle.value != show) _showTitle.value = show;
    });

    return Scaffold(
      body: Stack(
        children: [
          // 海报背景（高度不够时重复拼接）
          if (hasCover)
            Positioned.fill(
              child: Image(
                image: FileImage(File(book.coverPath!)),
                fit: BoxFit.cover,
                width: double.infinity,
                height: screenH,
                repeat: ImageRepeat.repeatY,
              ),
            )
          else
            Container(color: colors.surfaceContainerHighest),

          // 毛玻璃层
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),

          // 内容
          SafeArea(
            child: Column(
              children: [
                // 顶部栏：只在滚动后显示标题
                SizedBox(
                  height: 48,
                  child: Row(children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(widget.embedded ? Icons.close : Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: widget.embedded
                          ? () => context.read<AppProvider>().selectBook(null)
                          : () => Navigator.pop(context),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: _showTitle,
                      builder: (_, show, __) => AnimatedOpacity(
                        opacity: show ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                          child: Text(book.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStyleButton(),
                  ]),
                ),
                // 可滚动内容
                Expanded(
                  child: SingleChildScrollView(
                    controller: _overlayScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 封面缩略图 + 标题
                        _buildOverlayHeader(book),
                        const SizedBox(height: 20),
                        // 信息区块：无毛玻璃
                        _buildAuthorsSection(book),
                        if (book.isbn != null && book.isbn!.isNotEmpty) _buildIsbnSection(book),
                        if (book.publisher != null && book.publisher!.isNotEmpty) _buildPublisherSection(book),
                        if (book.publishDate != null) _buildPublishDateSection(book),
                        if (book.startDate != null || book.finishDate != null) _buildReadingDatesSection(book),
                        // 类型标签毛玻璃
                        if (book.genres.isNotEmpty) _buildGenresSection(book),
                        // 简介：内部已有毛玻璃卡片
                        if (book.summary != null && book.summary!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildSummarySection(book),
                        ],
                        const SizedBox(height: 12),
                        // 书评、书摘毛玻璃
                        _buildExtraSectionsOverlay(book),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(book)),
        ],
      ),
    );
  }

  /// 叠层模式顶部：封面小图 + 标题/评分
  Widget _buildOverlayHeader(Book book) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 封面缩略图
        Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: hasCover
              ? FadeInLocalImage(path: book.coverPath, fit: BoxFit.cover)
              : Container(color: Colors.white24, child: const Icon(Icons.menu_book, color: Colors.white38, size: 32)),
        ),
        const SizedBox(width: 16),
        // 标题 + 信息
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(book.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              if (book.authors.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(book.authors.join(' / '), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
              ],
              const SizedBox(height: 12),
              Row(children: [
                if (book.rating != null && book.rating! > 0) ...[
                  const Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                  const SizedBox(width: 4),
                  Text(book.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                  const SizedBox(width: 16),
                ],
                _statusChip(book.status),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButtons(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        const SizedBox(height: 12),
        _buildEpubReadButton(book),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: () => _showSharePoster(book),
          tooltip: '分享海报',
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  /// EPUB 阅读悬浮按钮（仅有关联 EPUB 时显示）
  Widget _buildEpubReadButton(Book book) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ReaderDao().getReaderBookByBookId(book.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final readerBook = snapshot.data!;
        return _buildFloatingButton(
          icon: Icons.auto_stories_outlined,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReaderScreen(
                  bookId: readerBook['id'] as String,
                  filePath: readerBook['file_path'] as String,
                  title: readerBook['title'] as String? ?? '',
                  coverPath: readerBook['cover_path'] as String?,
                  bookData: readerBook,
                ),
              ),
            );
          },
          tooltip: 'EPUB 阅读',
          backgroundColor: const Color(0xFF6750A4),
          foregroundColor: Colors.white,
        );
      },
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: foregroundColor),
        ),
      ),
    );
  }

  /// 固定在顶部的导航栏（纯色，与主体一致）
  Widget _buildStandardTopBar(String title, ColorScheme colors) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding),
        color: colors.surface,
        child: SizedBox(
          height: 48,
          child: Row(children: [
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(widget.embedded ? Icons.close : Icons.arrow_back_ios_new, color: colors.onSurface, size: 18),
              onPressed: widget.embedded
                  ? () => context.read<AppProvider>().selectBook(null)
                  : () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            _buildStyleButton(color: colors.onSurface),
          ]),
        ),
      ),
    );
  }

  Widget _buildCoverSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerH = constraints.maxHeight;
        return GestureDetector(
          onLongPressStart: hasCover ? (_) {
            HapticFeedback.mediumImpact();
            final ctx = _coverImageKey.currentContext;
            if (ctx != null) {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box != null) _coverImageHeight = box.size.height;
            }
            _draggingCover.value = true;
            _coverDragStartOffset = _coverOffset.value;
          } : null,
          onLongPressMoveUpdate: hasCover ? (d) {
            final raw = _coverDragStartOffset + d.offsetFromOrigin.dy;
            final imgH = _coverImageHeight > 0 ? _coverImageHeight : containerH;
            final minOffset = -(imgH - containerH).clamp(0, double.infinity);
            _coverOffset.value = (raw.clamp(minOffset, 0.0) as double);
          } : null,
          onLongPressEnd: hasCover ? (_) {
            _draggingCover.value = false;
            final offset = _coverOffset.value;
            UserPrefs().setCoverOffset(widget.book.id, offset);
            context.read<AppProvider>().updateBookCoverOffset(widget.book.id, offset);
          } : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _coverOffset,
            builder: (context, offset, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            top: offset,
                            left: 0, right: 0,
                            child: FadeInLocalImage(
                              key: _coverImageKey,
                              path: book.coverPath,
                              fit: BoxFit.fitWidth,
                              width: constraints.maxWidth,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildCoverPlaceholder(),
                  // 底部渐变 + 拖动遮罩
                  ValueListenableBuilder<bool>(
                    valueListenable: _draggingCover,
                    builder: (context, dragging, _) {
                      return Stack(
                        children: [
                          if (!dragging)
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colors.surface.withValues(alpha: 0),
                                        colors.surface,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (dragging) ...[
                            Positioned.fill(
                              child: Container(color: Colors.black.withValues(alpha: 0.3)),
                            ),
                            Positioned(
                              left: 0, right: 0, bottom: 20,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('上下滑动调整图片位置',
                                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无封面',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 样式选择按钮
  Widget _buildStyleButton({Color color = Colors.white}) {
    return IconButton(
      icon: Icon(Icons.tune, color: color, size: 20),
      tooltip: '切换样式',
      onPressed: _showStylePicker,
    );
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const names = ['默认样式', '毛玻璃层叠'];
    const icons = [Icons.article_outlined, Icons.blur_on_outlined];
    const subtitles = ['标准封面顶部布局', '封面背景 + 毛玻璃卡片'];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('详情页样式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 12),
          for (int i = 0; i < names.length; i++) ...[
            if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icons[i], size: 20, color: _detailStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(names[i], style: TextStyle(fontSize: 13, fontWeight: _detailStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: _detailStyle == i
                  ? Icon(Icons.check_circle, size: 20, color: colors.primary)
                  : Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () { setState(() => _detailStyle = i); UserPrefs().setDetailPageStyle(i); Navigator.pop(ctx); },
            ),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _statusChip(String status) {
    final colors = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'read' => ('已读', colors.primary, colors.onPrimary),
      'reading' => ('在读', colors.outlineVariant, colors.onSurface.withValues(alpha: 0.6)),
      'want_to_read' => ('想读', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.4)),
      'abandoned' => ('弃读', colors.error.withValues(alpha: 0.15), colors.error),
      _ => ('', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.3)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  /// EPUB 阅读进度条（仅有关联 EPUB 时显示）
  Widget _buildEpubProgressBar(Book book) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>?>(
      future: ReaderDao().getReaderBookByBookId(book.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final progress = (snapshot.data!['reading_percentage'] as num?)?.toDouble() ?? 0.0;
        if (progress <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBasicInfo(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              height: 1.3,
            ),
          ),
          if (book.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.alternateTitles.join(' / '),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
            ),
          ],
          // EPUB 阅读进度条
          _buildEpubProgressBar(book),
          const SizedBox(height: 16),
          Row(
            children: [
              if (book.rating != null) ...[
                Icon(
                  Icons.star,
                  size: 20,
                  color: colors.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  book.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(book),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '添加于 ${_formatDate(book.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(Book book) {
    final colors = Theme.of(context).colorScheme;
    String label;
    Color bgColor;
    Color textColor;
    switch (book.status) {
      case 'read':
        label = '已读';
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        break;
      case 'reading':
        label = '在读';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
        break;
      case 'want_to_read':
        label = '想读';
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurface.withValues(alpha: 0.4);
        break;
      case 'abandoned':
        label = '弃读';
        bgColor = colors.error.withValues(alpha: 0.15);
        textColor = colors.error;
        break;
      default:
        label = '未知';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAuthorsSection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '作者',
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.authors.join('，'),
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIsbnSection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'ISBN',
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.isbn!,
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublisherSection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '出版社',
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.publisher!,
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishDateSection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '出版时间',
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${book.publishDate!.year}年${book.publishDate!.month.toString().padLeft(2, '0')}月',
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingDatesSection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '阅读日期',
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (book.startDate != null)
                  _buildDateChip('开始', book.startDate!, isOverlay),
                if (book.finishDate != null)
                  _buildDateChip('读完', book.finishDate!, isOverlay),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isOverlay) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOverlay ? Colors.white.withValues(alpha: 0.12) : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${_formatDate(date)}',
        style: TextStyle(
          fontSize: 13,
          color: isOverlay ? Colors.white.withValues(alpha: 0.85) : colors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildGenresSection(Book book) {
    final isOverlay = _detailStyle == 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text('类型', style: TextStyle(fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: book.genres.map((g) => _buildGenreChip(g, isOverlay)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String label, bool isOverlay) {
    if (isOverlay) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
    );
  }

  Widget _buildSummarySection(Book book) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: isOverlay ? Colors.white : colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '简介',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isOverlay ? Colors.white : colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  book.summary!,
                  style: TextStyle(
                    fontSize: 15,
                    color: isOverlay ? Colors.white : colors.onSurface,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSections(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '更多',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '书评',
            subtitleFuture: context.read<AppProvider>().getBookReviewCount(book.id),
            emptyText: '暂无书评',
            unit: '条书评',
            onTap: () => _navigateToReviews(book),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.format_quote_outlined,
            title: '摘抄',
            subtitleFuture: context.read<AppProvider>().getBookExcerptCount(book.id),
            emptyText: '暂无摘抄',
            unit: '条摘抄',
            onTap: () => _navigateToExcerpts(book),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.highlight_outlined,
            title: '句读',
            subtitleFuture: _getEpubHighlightCount(book.id),
            emptyText: '暂无句读',
            unit: '条句读',
            onTap: () => _navigateToEpubHighlights(book),
          ),
        ],
      ),
    );
  }

  /// EPUB 阅读入口（通过关联的 reader_books）
  /// 叠层模式：书评、摘抄各自独立毛玻璃卡片
  Widget _buildExtraSectionsOverlay(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildFrostedExtraItem(
            icon: Icons.rate_review_outlined,
            title: '书评',
            subtitleFuture: context.read<AppProvider>().getBookReviewCount(book.id),
            emptyText: '暂无书评',
            unit: '条书评',
            onTap: () => _navigateToReviews(book),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.format_quote_outlined,
            title: '摘抄',
            subtitleFuture: context.read<AppProvider>().getBookExcerptCount(book.id),
            emptyText: '暂无摘抄',
            unit: '条摘抄',
            onTap: () => _navigateToExcerpts(book),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.highlight_outlined,
            title: '句读',
            subtitleFuture: _getEpubHighlightCount(book.id),
            emptyText: '暂无句读',
            unit: '条句读',
            onTap: () => _navigateToEpubHighlights(book),
          ),
        ],
      ),
    );
  }

  /// 毛玻璃书评/摘抄卡片
  Widget _buildFrostedExtraItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      FutureBuilder<int>(
                        future: subtitleFuture,
                        builder: (ctx, snap) {
                          final count = snap.data ?? 0;
                          return Text(count > 0 ? '$count $unit' : emptyText,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)));
                        },
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraSectionItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count $unit' : emptyText,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReviews(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewsPage(book: book),
      ),
    );
  }

  void _navigateToExcerpts(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookExcerptsPage(book: book),
      ),
    );
  }

  /// 获取关联 EPUB 的句读（高亮）数量
  Future<int> _getEpubHighlightCount(String bookId) async {
    final readerBook = await ReaderDao().getReaderBookByBookId(bookId);
    if (readerBook == null) return 0;
    final highlights = await ReaderDao().getHighlightsByBookId(readerBook['id'] as String);
    return highlights.where((h) => h['color'] != 'excerpt').length;
  }

  /// 跳转到 EPUB 句读管理页
  void _navigateToEpubHighlights(Book book) async {
    final readerBook = await ReaderDao().getReaderBookByBookId(book.id);
    if (!mounted) return;
    if (readerBook == null) {
      ToastUtil.show(context, '该书籍尚未关联EPUB数据，请关联后使用');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpubHighlightsPage(
          bookId: readerBook['id'] as String,
          book: readerBook,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    final provider = context.read<AppProvider>();
    Navigator.pushNamed(context, '/book-form', arguments: widget.book).then((_) {
      provider.setEditRefresh();
      provider.loadBooks();
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除"${widget.book.title}"吗？删除后可在回收站恢复。',
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(widget.book.id);
              if (!mounted) return;
              Navigator.pop(context);
              if (widget.embedded) {
                context.read<AppProvider>().selectBook(null);
              } else {
                Navigator.pop(context);
              }
              ToastUtil.show(context, '已删除');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }




  void _showSharePoster(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookSharePage(book: book),
      ),
    );
  }
}

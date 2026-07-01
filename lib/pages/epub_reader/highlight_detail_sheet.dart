import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/toast_util.dart';

/// 句读详情弹窗 —— 类似分享卡片的样式
/// 从 epub_detail_page 和 epub_highlights_page 共用
void showHighlightDetailSheet(
  BuildContext context, {
  required Map<String, dynamic> highlight,
  required Map<String, dynamic> book,
  required VoidCallback onDelete,
  VoidCallback? onNavigate,
}) {
  final colors = Theme.of(context).colorScheme;
  final content = highlight['content'] as String? ?? '';
  final chapter = highlight['chapter'] as String? ?? '';
  final chapterNum = int.tryParse(chapter);
  final createdAt = highlight['created_at'] as String? ?? '';
  final bookTitle = book['title'] as String? ?? '';

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部装饰条
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名 + 章节标题行
                  Row(
                    children: [
                      Icon(Icons.book_outlined, size: 16, color: const Color(0xFFFFC107)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bookTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chapterNum != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEB3B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '第 ${chapterNum + 1} 章',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 引号装饰 + 高亮文本
                  Stack(
                    children: [
                      Positioned(
                        left: -4,
                        top: -8,
                        child: Text(
                          '"',
                          style: TextStyle(
                            fontSize: 48,
                            color: const Color(0xFFFFEB3B).withValues(alpha: 0.4),
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: SelectableText(
                          content,
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.onSurface.withValues(alpha: 0.85),
                            height: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 日期
                  if (createdAt.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  // 分隔线
                  Container(height: 0.5, color: colors.outlineVariant),
                  const SizedBox(height: 16),
                  // 操作按钮
                  Row(
                    children: [
                      _buildActionButton(
                        colors,
                        icon: Icons.content_copy_outlined,
                        label: '复制',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: content));
                          Navigator.pop(ctx);
                          ToastUtil.show(context, '已复制');
                        },
                      ),
                      if (onNavigate != null)
                        _buildActionButton(
                          colors,
                          icon: Icons.menu_book_outlined,
                          label: '跳转',
                          onTap: () {
                            Navigator.pop(ctx);
                            onNavigate();
                          },
                        ),
                      _buildActionButton(
                        colors,
                        icon: Icons.delete_outline,
                        label: '删除',
                        onTap: () {
                          Navigator.pop(ctx);
                          onDelete();
                        },
                        isDanger: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildActionButton(
  ColorScheme colors, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool isDanger = false,
}) {
  final color = isDanger ? colors.error : colors.onSurface.withValues(alpha: 0.6);
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(String isoString) {
  try {
    final dt = DateTime.parse(isoString);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

String _formatDateFromDateTime(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// 摘抄详情弹窗 —— 和句读弹窗风格一致
void showExcerptDetailSheet(
  BuildContext context, {
  required String content,
  required String chapter,
  required String comment,
  required DateTime createdAt,
  required String bookTitle,
  required VoidCallback onDelete,
}) {
  final colors = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部装饰条
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 书名 + 章节
                    Row(
                      children: [
                        Icon(Icons.book_outlined, size: 16, color: const Color(0xFF2196F3)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bookTitle,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chapter.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              chapter,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 引号 + 摘抄内容
                    Stack(
                      children: [
                        Positioned(
                          left: -4,
                          top: -8,
                          child: Text(
                            '"',
                            style: TextStyle(
                              fontSize: 48,
                              color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: SelectableText(
                            content,
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.onSurface.withValues(alpha: 0.85),
                              height: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // 感悟
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border(
                            left: BorderSide(color: colors.primary.withValues(alpha: 0.4), width: 2),
                          ),
                        ),
                        child: Text(
                          comment,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.6),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 日期
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateFromDateTime(createdAt),
                          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 分隔线
                    Container(height: 0.5, color: colors.outlineVariant),
                    const SizedBox(height: 16),
                    // 操作按钮
                    Row(
                      children: [
                        _buildActionButton(
                          colors,
                          icon: Icons.content_copy_outlined,
                          label: '复制',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: content));
                            Navigator.pop(ctx);
                            ToastUtil.show(context, '已复制');
                          },
                        ),
                        _buildActionButton(
                          colors,
                          icon: Icons.delete_outline,
                          label: '删除',
                          onTap: () {
                            Navigator.pop(ctx);
                            onDelete();
                          },
                          isDanger: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}


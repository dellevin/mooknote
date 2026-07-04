import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 文本选中后弹出的工具条
class EpubSelectionToolbar extends StatelessWidget {
  /// 选中文字的屏幕坐标区域
  final Rect selectionRect;

  /// 点击复制按钮的回调
  final VoidCallback onCopy;

  /// 点击高亮按钮的回调
  final VoidCallback onHighlight;

  /// 点击摘抄到笔记的回调
  final VoidCallback onExcerpt;

  /// 点击取消高亮按钮的回调
  final VoidCallback? onRemoveHighlight;

  /// 点击取消摘抄按钮的回调
  final VoidCallback? onRemoveExcerpt;

  /// 点击外部区域关闭
  final VoidCallback onDismiss;

  const EpubSelectionToolbar({
    super.key,
    required this.selectionRect,
    required this.onCopy,
    required this.onHighlight,
    required this.onExcerpt,
    this.onRemoveHighlight,
    this.onRemoveExcerpt,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // 计算工具条位置：优先在选区上方，空间不足时放下方
    final mediaQuery = MediaQuery.of(context);
    final selectionTop = selectionRect.top;
    final selectionBottom = selectionRect.bottom;
    const toolbarHeight = 44.0;
    const margin = 8.0;
    final showAbove = selectionTop > toolbarHeight + margin + 80;
    final top = showAbove
        ? selectionTop - toolbarHeight - margin
        : selectionBottom + margin;

    // 水平居中于选区，但不超出屏幕
    final showRemoveHL = onRemoveHighlight != null;
    final showRemoveExcerpt = onRemoveExcerpt != null;
    final buttonCount = 2 + (showRemoveHL || !showRemoveExcerpt ? 1 : 0) + (showRemoveExcerpt ? 1 : 0);
    final toolbarWidth = buttonCount * 72.0;
    double left = selectionRect.center.dx - toolbarWidth / 2;
    left = left.clamp(12.0, mediaQuery.size.width - toolbarWidth - 12.0);

    return Stack(
      children: [
        // 全屏遮罩，点击关闭
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top < 0 ? margin : top,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            color: colors.surface,
            surfaceTintColor: colors.surfaceTint,
            child: SizedBox(
              height: toolbarHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildButton(
                    context,
                    icon: Icons.copy_outlined,
                    label: '复制',
                    onTap: onCopy,
                    color: colors.primary,
                  ),
                  _divider(colors),
                  if (showRemoveHL)
                    _buildButton(
                      context,
                      icon: Icons.highlight_off_outlined,
                      label: '取消高亮',
                      onTap: onRemoveHighlight!,
                      color: colors.error,
                    )
                  else
                    _buildButton(
                      context,
                      icon: Icons.highlight_outlined,
                      label: '高亮',
                      onTap: onHighlight,
                      color: colors.primary,
                    ),
                  _divider(colors),
                  if (showRemoveExcerpt)
                    _buildButton(
                      context,
                      icon: Icons.edit_off_outlined,
                      label: '取消摘抄',
                      onTap: onRemoveExcerpt!,
                      color: colors.error,
                    )
                  else
                    _buildButton(
                      context,
                      icon: Icons.edit_note_outlined,
                      label: '摘抄',
                      onTap: onExcerpt,
                      color: colors.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(ColorScheme colors) {
    return Container(
      width: 0.5,
      height: 22,
      color: colors.outlineVariant,
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 复制文字到剪贴板的辅助函数
Future<void> copyTextToClipboard(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 浮动工具栏 — 参考微信阅读划线界面
class SelectionOverlay extends StatefulWidget {
  final String selectedText;
  final Rect position; // WebView 坐标系内的位置
  final VoidCallback onCopy;
  final VoidCallback onHighlight;
  final VoidCallback? onExcerpt; // null = 不显示书摘按钮
  final ColorScheme colorScheme;
  final bool isDark;

  const SelectionOverlay({
    super.key,
    required this.selectedText,
    required this.position,
    required this.onCopy,
    required this.onHighlight,
    this.onExcerpt,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  State<SelectionOverlay> createState() => _SelectionOverlayState();
}

class _SelectionOverlayState extends State<SelectionOverlay> {
  static const int _visibleCount = 6;

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.selectedText));
    if (mounted) Navigator.of(context).pop();
    widget.onCopy();
  }

  void _onItemTap(int index) {
    switch (index) {
      case 0:
        _copyToClipboard();
        break;
      case 1:
        Navigator.of(context).pop();
        widget.onHighlight();
        break;
      case 2:
        Navigator.of(context).pop();
        break;
      case 3:
        if (widget.onExcerpt != null) {
          Navigator.of(context).pop();
          widget.onExcerpt!();
        }
        break;
      case 4:
        Navigator.of(context).pop();
        break;
      case 5:
        Navigator.of(context).pop();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade900;
    return Positioned(
      left: clampDouble(widget.position.left, 8, MediaQuery.of(context).size.width - _visibleCount * 70),
      top: clampDouble(widget.position.top - 48, 0, widget.position.top),
      child: GestureDetector(
        onTapUp: (_) => Navigator.of(context).pop(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _ToolbarItem(icon: Icons.copy, label: '复制', onTap: () => _onItemTap(0), color: widget.colorScheme.primary),
            const SizedBox(width: 12),
            _ToolbarItem(icon: Icons.format_underlined, label: '划线', onTap: () => _onItemTap(1), color: widget.colorScheme.primary),
            const SizedBox(width: 12),
            _ToolbarItem(icon: Icons.edit_note_outlined, label: '写想法', onTap: () => _onItemTap(2), color: widget.colorScheme.primary),
            if (widget.onExcerpt != null) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 28, color: Colors.white30),
              const SizedBox(width: 12),
              _ToolbarItem(icon: Icons.bookmark_border, label: '书摘', onTap: () => _onItemTap(3), color: widget.colorScheme.primary),
            ],
            const SizedBox(width: 12),
            _ToolbarItem(icon: Icons.search, label: 'AI 问书', onTap: () => _onItemTap(4), color: widget.colorScheme.primary),
            const SizedBox(width: 12),
            _ToolbarItem(icon: Icons.headphones, label: '听当前', onTap: () => _onItemTap(5), color: widget.colorScheme.primary),
          ]),
        ),
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ToolbarItem({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      ]),
    );
  }
}

double clampDouble(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

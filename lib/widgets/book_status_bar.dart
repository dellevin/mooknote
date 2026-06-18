import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 阅读状态选择栏 - 交叉渐变动画
class BookStatusBar extends StatelessWidget {
  const BookStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
          ),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SizedBox(
              height: 40,
              child: Row(children: [
                _buildTab(colors, '已读', Icons.check_circle_outline, provider.bookStatusIndex == 0, () => provider.setBookStatusIndex(0)),
                _buildTab(colors, '在读', Icons.menu_book_outlined, provider.bookStatusIndex == 1, () => provider.setBookStatusIndex(1)),
                _buildTab(colors, '想读', Icons.bookmark_outlined, provider.bookStatusIndex == 2, () => provider.setBookStatusIndex(2)),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(ColorScheme colors, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Icon(icon, key: ValueKey(isSelected), size: 16,
                    color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(label, key: ValueKey('$label$isSelected')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 阅读状态选择栏 - 平滑过渡动画
class BookStatusBar extends StatelessWidget {
  const BookStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final currentIndex = provider.bookStatusIndex;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = constraints.maxWidth / 3;
                return SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        left: currentIndex * tabWidth,
                        top: 0, bottom: 0, width: tabWidth,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          _buildTab(colors, '已读', Icons.check_circle_outline, currentIndex == 0,
                              () => provider.setBookStatusIndex(0)),
                          _buildTab(colors, '在读', Icons.menu_book_outlined, currentIndex == 1,
                              () => provider.setBookStatusIndex(1)),
                          _buildTab(colors, '想读', Icons.bookmark_outlined, currentIndex == 2,
                              () => provider.setBookStatusIndex(2)),
                        ],
                      ),
                    ],
                  ),
                );
              },
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
        child: AnimatedOpacity(
          opacity: isSelected ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: SizedBox.expand(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isSelected ? colors.onPrimary : colors.onSurface),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? colors.onPrimary : colors.onSurface,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

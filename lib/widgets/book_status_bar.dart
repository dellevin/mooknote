import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';

/// 阅读状态选择栏
class BookStatusBar extends StatelessWidget {
  const BookStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildStatusItem(
                context,
                '读完',
                AppTheme.readColor,
                Icons.check_circle,
                0,
                provider.bookStatusIndex,
                () => provider.setBookStatusIndex(0),
              ),
              const SizedBox(width: 12),
              _buildStatusItem(
                context,
                '在读',
                AppTheme.readingColor,
                Icons.auto_stories,
                1,
                provider.bookStatusIndex,
                () => provider.setBookStatusIndex(1),
              ),
              const SizedBox(width: 12),
              _buildStatusItem(
                context,
                '准备读',
                AppTheme.wantToReadColor,
                Icons.bookmark_border,
                2,
                provider.bookStatusIndex,
                () => provider.setBookStatusIndex(2),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建状态项
  Widget _buildStatusItem(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

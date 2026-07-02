import 'package:flutter/material.dart';
import '../providers/app_provider.dart';

/// 新增记录弹窗 — 供底部导航栏和 NavigationRail 共用

void showQuickAddSheet(BuildContext context, AppProvider provider) {
  final currentTab = provider.mainTabIndex;
  switch (currentTab) {
    case 0:
      final statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch'};
      final currentStatus =
          statusMap[provider.movieStatusIndex] ?? 'want_to_watch';
      Navigator.pushNamed(context, '/movie-form',
          arguments: {'initialStatus': currentStatus});
    case 1:
      final statusMap = {0: 'read', 1: 'reading', 2: 'want_to_read', 3: 'abandoned'};
      final currentStatus =
          statusMap[provider.bookStatusIndex] ?? 'want_to_read';
      Navigator.pushNamed(context, '/book-form',
          arguments: {'initialStatus': currentStatus});
    case 2:
      Navigator.pushNamed(context, '/note-form');
    default:
      showAddSheet(context, provider);
  }
}

void showAddSheet(BuildContext context, AppProvider provider) {
  final colors = Theme.of(context).colorScheme;
  final outerContext = context;
  showModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bc = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: bc.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text('新增记录',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: bc.onSurface)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildOption(
                colors: bc,
                icon: Icons.movie_outlined,
                title: '添加观影',
                subtitle: '记录你看过的电影',
                onTap: () {
                  Navigator.pop(ctx);
                  final statusMap = {
                    0: 'watched',
                    1: 'watching',
                    2: 'want_to_watch',
                  };
                  final s =
                      statusMap[provider.movieStatusIndex] ?? 'want_to_watch';
                  Navigator.pushNamed(outerContext, '/movie-form',
                      arguments: {'initialStatus': s});
                },
              ),
              _buildOption(
                colors: bc,
                icon: Icons.menu_book_outlined,
                title: '添加阅读',
                subtitle: '记录你读过的书',
                onTap: () {
                  Navigator.pop(ctx);
                  final statusMap = {
                    0: 'read',
                    1: 'reading',
                    2: 'want_to_read',
                    3: 'abandoned',
                  };
                  final s =
                      statusMap[provider.bookStatusIndex] ?? 'want_to_read';
                  Navigator.pushNamed(outerContext, '/book-form',
                      arguments: {'initialStatus': s});
                },
              ),
              _buildOption(
                colors: bc,
                icon: Icons.note_outlined,
                title: '添加笔记',
                subtitle: '记录你的想法和笔记',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(outerContext, '/note-form');
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildOption({
  required ColorScheme colors,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25), size: 20),
        ],
      ),
    ),
  );
}

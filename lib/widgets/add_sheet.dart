import 'package:flutter/material.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/slide_up_page_route.dart';
import '../widgets/app_overlay.dart';
import '../widgets/custom_module_icon.dart';
import '../l10n/app_strings.dart';
import '../pages/custom_module/custom_module_form_page.dart';
import '../pages/quick_add/quick_add_page.dart';

/// 新增记录弹窗 — 供底部导航栏和 NavigationRail 共用

void showQuickAddSheet(BuildContext context, AppProvider provider) {
  final currentTab = provider.mainTabIndex;
  switch (currentTab) {
    case 0:
      final statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch', 3: 'abandoned'};
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
    case 3:
      final statusMap = {0: 'completed', 1: 'playing', 2: 'want_to_play', 3: 'abandoned'};
      final currentStatus =
          statusMap[provider.gameStatusIndex] ?? 'want_to_play';
      Navigator.pushNamed(context, '/game-form',
          arguments: {'initialStatus': currentStatus});
    default:
      showAddSheet(context, provider);
  }
}

void showAddSheet(BuildContext context, AppProvider provider) {
  final colors = Theme.of(context).colorScheme;
  final outerContext = context;
  final userPrefs = UserPrefs();

  final options = <Widget>[];
  if (userPrefs.showMovieTab) {
    options.add(_buildOption(
      colors: colors,
      icon: Icons.movie_outlined,
      accent: const Color(0xFF5B8DEF),
      title: '添加观影'.tr,
      subtitle: '记录你看过的电影'.tr,
      onTap: () {
        Navigator.pop(outerContext);
        final statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch', 3: 'abandoned'};
        final s = statusMap[provider.movieStatusIndex] ?? 'want_to_watch';
        Navigator.pushNamed(outerContext, '/movie-form',
            arguments: {'initialStatus': s});
      },
      onQuickAdd: () {
        Navigator.pop(outerContext);
        Navigator.push(
          outerContext,
          SlideUpPageRoute(
              page: const QuickAddPage(initialCategory: 'movie')),
        );
      },
    ));
  }
  if (userPrefs.showBookTab) {
    options.add(_buildOption(
      colors: colors,
      icon: Icons.menu_book_outlined,
      accent: const Color(0xFF46A758),
      title: '添加阅读'.tr,
      subtitle: '记录你读过的书'.tr,
      onTap: () {
        Navigator.pop(outerContext);
        final statusMap = {0: 'read', 1: 'reading', 2: 'want_to_read', 3: 'abandoned'};
        final s = statusMap[provider.bookStatusIndex] ?? 'want_to_read';
        Navigator.pushNamed(outerContext, '/book-form',
            arguments: {'initialStatus': s});
      },
      onQuickAdd: () {
        Navigator.pop(outerContext);
        Navigator.push(
          outerContext,
          SlideUpPageRoute(
              page: const QuickAddPage(initialCategory: 'book')),
        );
      },
    ));
  }
  if (userPrefs.showGameTab) {
    options.add(_buildOption(
      colors: colors,
      icon: Icons.sports_esports_outlined,
      accent: const Color(0xFF8E6CEF),
      title: '添加游戏'.tr,
      subtitle: '记录你玩过的游戏'.tr,
      onTap: () {
        Navigator.pop(outerContext);
        final statusMap = {0: 'completed', 1: 'playing', 2: 'want_to_play', 3: 'abandoned'};
        final s = statusMap[provider.gameStatusIndex] ?? 'want_to_play';
        Navigator.pushNamed(outerContext, '/game-form',
            arguments: {'initialStatus': s});
      },
      onQuickAdd: () {
        Navigator.pop(outerContext);
        Navigator.push(
          outerContext,
          SlideUpPageRoute(
              page: const QuickAddPage(initialCategory: 'game')),
        );
      },
    ));
  }
  if (userPrefs.showNoteTab) {
    options.add(_buildOption(
      colors: colors,
      icon: Icons.sticky_note_2_outlined,
      accent: const Color(0xFFF2994A),
      title: '添加笔记'.tr,
      subtitle: '记录你的想法和笔记'.tr,
      onTap: () {
        Navigator.pop(outerContext);
        Navigator.pushNamed(outerContext, '/note-form');
      },
    ));
  }
  // 自定义分类模块：排在固定模块之后
  for (final m in provider.enabledCustomModules) {
    options.add(_buildOption(
      colors: colors,
      icon: Icons.dashboard_customize_outlined,
      accent: const Color(0xFF26A69A),
      customIcon: m.icon,
      title: m.name,
      subtitle: '自定义分类模块'.tr,
      onTap: () {
        Navigator.pop(outerContext);
        Navigator.push(outerContext,
            SlideUpPageRoute(page: CustomModuleFormPage(module: m)));
      },
    ));
  }

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bc = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: bc.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('新增记录'.tr,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: bc.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...options,
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
  required Color accent,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  VoidCallback? onQuickAdd,
  String customIcon = '',
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: customIcon.isNotEmpty
                ? buildCustomModuleIcon(customIcon, size: 18, color: accent)
                : Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          if (onQuickAdd != null)
            _buildQuickAddButton(onQuickAdd)
          else
            Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25), size: 18),
        ],
      ),
    ),
  );
}

/// 快捷添加按钮：黑底白字，“快捷 / 添加”两行文字
Widget _buildQuickAddButton(VoidCallback onTap) {
  const labelStyle = TextStyle(
    fontSize: 10,
    height: 1.15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('快捷'.tr, style: labelStyle),
          Text('添加'.tr, style: labelStyle),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import '../../widgets/app_back_button.dart';
import '../../l10n/app_strings.dart';
import 'enhanced_search_settings_page.dart';
import 'tmdb_settings_page.dart';
import 'bangumi_settings_page.dart';

/// 在线搜索 API 设置入口：聚合增强搜索 / TMDB / Bangumi 三个数据源
class OnlineSearchApiSettingsPage extends StatelessWidget {
  const OnlineSearchApiSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('在线搜索 API'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('选择数据源进行配置'.tr,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildItem(
                  context,
                  icon: Icons.manage_search,
                  title: '增强搜索'.tr,
                  subtitle: '在线搜索影视和书籍信息'.tr,
                  page: const EnhancedSearchSettingsPage(),
                ),
                _divider(colors),
                _buildItem(
                  context,
                  icon: Icons.movie_filter_outlined,
                  title: 'TMDB 搜索'.tr,
                  subtitle: '使用 TMDB API 搜索电影和剧集'.tr,
                  page: const TmdbSettingsPage(),
                ),
                _divider(colors),
                _buildItem(
                  context,
                  icon: Icons.explore_outlined,
                  title: 'Bangumi 搜索'.tr,
                  subtitle: '使用 Bangumi API 搜索动画、书籍和游戏'.tr,
                  page: const BangumiSettingsPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) => Divider(
        height: 0.5,
        indent: 68,
        endIndent: 20,
        color: colors.outlineVariant,
      );

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon,
                  color: colors.onSurface.withValues(alpha: 0.6), size: 18),
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
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

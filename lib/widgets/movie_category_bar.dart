import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 影视分类选择栏 - 可横向滚动，带动画指示器
class MovieCategoryBar extends StatelessWidget {
  const MovieCategoryBar({super.key});

  static const _categories = [
    ('电影', 'movie'),
    ('电视剧', 'tv'),
    ('动漫', 'anime'),
    ('综艺', 'variety'),
    ('纪录片', 'documentary'),
    ('微短剧', 'short'),
    ('其他', 'other'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final currentIndex = provider.movieCategoryIndex;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: colors.surface),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = _categories.length;
                final tabWidth = constraints.maxWidth / count;
                return SizedBox(
                  height: 36,
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
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: List.generate(count, (i) {
                          final isSelected = currentIndex == i;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => provider.setMovieCategoryIndex(i),
                              child: AnimatedOpacity(
                                opacity: isSelected ? 1.0 : 0.5,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: Center(
                                  child: FittedBox(
                                    child: Text(
                                      _categories[i].$1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? colors.onPrimary : colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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

  /// 根据索引获取分类值
  static String categoryValue(int index) =>
      _categories[index.clamp(0, _categories.length - 1)].$2;

  /// 根据索引获取分类标签
  static String categoryLabel(int index) =>
      _categories[index.clamp(0, _categories.length - 1)].$1;

  /// 分类数量
  static int get count => _categories.length;
}

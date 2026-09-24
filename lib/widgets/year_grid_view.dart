import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../utils/responsive.dart';

/// 年份分组网格视图：按年份倒序分段显示，无年份的归入"其他"（排最后）。
/// 组内顺序保持传入列表的顺序（由当前排序方式与分页加载顺序决定）。
class YearGridView<T> extends StatelessWidget {
  final List<T> items;
  final int? Function(T item) yearOf;
  final Widget Function(T item) itemBuilder;
  final ScrollController controller;

  /// 固定列数（null 或 <=0 时按宽度自适应）
  final int? fixedCrossAxisCount;
  final bool hasMore;
  final Widget loadMoreIndicator;

  const YearGridView({
    super.key,
    required this.items,
    required this.yearOf,
    required this.itemBuilder,
    required this.controller,
    this.fixedCrossAxisCount,
    this.hasMore = false,
    this.loadMoreIndicator = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = <int, List<T>>{};
    final others = <T>[];
    for (final item in items) {
      final year = yearOf(item);
      if (year == null) {
        others.add(item);
      } else {
        groups.putIfAbsent(year, () => []).add(item);
      }
    }
    final years = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (fixedCrossAxisCount != null && fixedCrossAxisCount! > 0)
            ? fixedCrossAxisCount!
            : responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
        final sections = <Widget>[];

        void addSection(String title, List<T> list) {
          sections.add(SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('${list.length}',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.35))),
                  ),
                ],
              ),
            ),
          ));
          sections.add(SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => itemBuilder(list[i]),
              childCount: list.length,
            ),
          ));
        }

        for (final y in years) {
          addSection('$y', groups[y]!);
        }
        if (others.isNotEmpty) addSection('其他'.tr, others);
        if (hasMore) {
          sections.add(SliverToBoxAdapter(child: loadMoreIndicator));
        }

        return CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverMainAxisGroup(slivers: sections),
            ),
          ],
        );
      },
    );
  }
}

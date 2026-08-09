import 'package:flutter/material.dart';

/// 通用状态选择栏，支持 4 种样式
///   0: 胶囊滑块（默认）
///   1: 下划线
///   2: 芯片组
///   3: 下拉
class StatusBarShell extends StatelessWidget {
  const StatusBarShell({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onChanged,
    this.style = 0,
  });

  final List<StatusBarTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final int style;

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case 1:
        return _UnderlineBar(tabs: tabs, currentIndex: currentIndex, onChanged: onChanged);
      case 2:
        return _ChipBar(tabs: tabs, currentIndex: currentIndex, onChanged: onChanged);
      case 3:
        return _DropdownBar(tabs: tabs, currentIndex: currentIndex, onChanged: onChanged);
      default:
        return _PillBar(tabs: tabs, currentIndex: currentIndex, onChanged: onChanged);
    }
  }
}

class StatusBarTab {
  const StatusBarTab({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

// ---------- 0: 胶囊滑块 ----------
class _PillBar extends StatelessWidget {
  const _PillBar({required this.tabs, required this.currentIndex, required this.onChanged});
  final List<StatusBarTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colors.surface,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / tabs.length;
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
                      for (int i = 0; i < tabs.length; i++)
                        _PillItem(
                          colors: colors,
                          tab: tabs[i],
                          isSelected: currentIndex == i,
                          onTap: () => onChanged(i),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({required this.colors, required this.tab, required this.isSelected, required this.onTap});
  final ColorScheme colors;
  final StatusBarTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Icon(tab.icon, size: 16, color: isSelected ? colors.onPrimary : colors.onSurface),
                const SizedBox(width: 6),
                Text(tab.label,
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

// ---------- 1: 下划线 ----------
class _UnderlineBar extends StatelessWidget {
  const _UnderlineBar({required this.tabs, required this.currentIndex, required this.onChanged});
  final List<StatusBarTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: colors.surface,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tabs[i].icon, size: 16,
                              color: currentIndex == i ? colors.primary : colors.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(tabs[i].label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: currentIndex == i ? FontWeight.w600 : FontWeight.w500,
                                color: currentIndex == i ? colors.primary : colors.onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: currentIndex == i ? colors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- 2: 芯片组 ----------
class _ChipBar extends StatelessWidget {
  const _ChipBar({required this.tabs, required this.currentIndex, required this.onChanged});
  final List<StatusBarTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: colors.surface,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: currentIndex == i ? colors.primary : Colors.transparent,
                    border: Border.all(
                      color: currentIndex == i ? colors.primary : colors.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tabs[i].icon, size: 15,
                          color: currentIndex == i ? colors.onPrimary : colors.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(tabs[i].label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: currentIndex == i ? FontWeight.w600 : FontWeight.w500,
                            color: currentIndex == i ? colors.onPrimary : colors.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------- 3: 下拉 ----------
class _DropdownBar extends StatelessWidget {
  const _DropdownBar({required this.tabs, required this.currentIndex, required this.onChanged});
  final List<StatusBarTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final current = tabs[currentIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<int>(
            onSelected: onChanged,
            itemBuilder: (context) => [
              for (int i = 0; i < tabs.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  child: Row(
                    children: [
                      Icon(tabs[i].icon, size: 18,
                          color: i == currentIndex ? colors.primary : colors.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(tabs[i].label,
                          style: TextStyle(
                            fontWeight: i == currentIndex ? FontWeight.w600 : FontWeight.w500,
                            color: i == currentIndex ? colors.primary : colors.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(current.icon, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(current.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      )),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

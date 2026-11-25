import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_back_button.dart';

/// 详情页模块 / 更多入口内容 的排序与显隐设置页
///
/// [type] 取值：movie / book / game；[isExtra] 为 false 时设置详情页模块，
/// 为 true 时设置「更多入口」子项。长按拖拽排序，开关控制显隐。
/// 列表项仿照详情页对应模块的样式渲染，便于对照调整。
class DetailItemsSettingsPage extends StatefulWidget {
  final String type;
  final bool isExtra;
  const DetailItemsSettingsPage({
    super.key,
    required this.type,
    this.isExtra = false,
  });

  @override
  State<DetailItemsSettingsPage> createState() =>
      _DetailItemsSettingsPageState();
}

class _DetailItemsSettingsPageState extends State<DetailItemsSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  late List<({String id, bool visible})> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.isExtra
        ? _userPrefs.getDetailExtraItems(widget.type)
        : _userPrefs.getDetailModules(widget.type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.isExtra ? '更多入口内容'.tr : '详情页模块'.tr),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text('重置'.tr,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5))),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        onReorder: _onReorder,
        itemBuilder: (_, i) =>
            widget.isExtra ? _buildExtraItem(i, colors) : _buildModuleItem(i, colors),
      ),
    );
  }

  // ─── 列表项 ────────────────────────────────────────────────────

  /// 详情页模块：分区标题（竖条 + 标题，与详情页一致）+ 该模块的缩略预览
  Widget _buildModuleItem(int index, ColorScheme colors) {
    final m = _items[index];
    final titleColor =
        m.visible ? colors.onSurface : colors.onSurface.withValues(alpha: 0.35);
    return Container(
      key: ValueKey(m.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 16),
      decoration: _cardDecoration(colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                  color: titleColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_labelOf(m.id).tr,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor)),
            ),
            Switch(value: m.visible, onChanged: (v) => _toggle(index, v)),
            _dragHandle(index, colors),
          ]),
          const SizedBox(height: 14),
          Opacity(
            opacity: m.visible ? 1 : 0.35,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _modulePreview(m.id, colors),
            ),
          ),
        ],
      ),
    );
  }

  /// 更多入口子项：与详情页「更多」里的入口卡片同样式（图标盒 + 标题 + 副标题）
  Widget _buildExtraItem(int index, ColorScheme colors) {
    final m = _items[index];
    final contentColor =
        m.visible ? colors.onSurface : colors.onSurface.withValues(alpha: 0.35);
    return Container(
      key: ValueKey(m.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: _cardDecoration(colors),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          child: Icon(_extraIcon(m.id),
              size: 20, color: contentColor.withValues(alpha: 0.6)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_labelOf(m.id).tr,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: contentColor)),
              const SizedBox(height: 6),
              _bar(colors, 56, height: 8),
            ],
          ),
        ),
        Switch(value: m.visible, onChanged: (v) => _toggle(index, v)),
        _dragHandle(index, colors),
      ]),
    );
  }

  BoxDecoration _cardDecoration(ColorScheme colors) {
    return BoxDecoration(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
    );
  }

  Widget _dragHandle(int index, ColorScheme colors) {
    return ReorderableDragStartListener(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Icon(Icons.drag_indicator,
            size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }

  // ─── 模块缩略预览（灰色占位，不读真实数据） ──────────────────────

  Widget _modulePreview(String id, ColorScheme colors) {
    return switch (id) {
      // 演职员/书籍/游戏信息：左侧字段名 + 右侧内容的信息行
      'credits' => Column(children: [
          for (final w in [140.0, 110.0, 170.0])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                SizedBox(width: 48, child: _bar(colors, 30)),
                const SizedBox(width: 12),
                _bar(colors, w),
              ]),
            ),
        ]),
      // 类型标签：一排 chip
      'genres' => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in [56.0, 72.0, 48.0]) _bar(colors, w, height: 26),
        ]),
      // 角色 / 关联人物：一排圆形头像 + 名字
      'characters' || 'people' => Row(children: [
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(height: 8),
                _bar(colors, 32, height: 8),
              ]),
            ),
        ]),
      // 简介：多行文本
      'summary' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(colors, double.infinity),
            const SizedBox(height: 10),
            _bar(colors, double.infinity),
            const SizedBox(height: 10),
            _bar(colors, 180),
          ],
        ),
      // 影评/书评/评价预览：带头像与标题的卡片
      'reviews' => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                const SizedBox(width: 8),
                _bar(colors, 72),
              ]),
              const SizedBox(height: 12),
              _bar(colors, double.infinity, height: 8),
              const SizedBox(height: 8),
              _bar(colors, 140, height: 8),
            ],
          ),
        ),
      // 更多入口：入口卡片
      'extra' => Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            child: Icon(Icons.grid_view_outlined,
                size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(colors, 72),
            const SizedBox(height: 8),
            _bar(colors, 48, height: 8),
          ]),
        ]),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _bar(ColorScheme colors, double width, {double height = 10}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  /// 「更多入口」子项 id → 图标（与详情页入口一致）
  IconData _extraIcon(String id) {
    return switch (id) {
      'progress' => switch (widget.type) {
          'book' => Icons.menu_book_outlined,
          'game' => Icons.flag_outlined,
          _ => Icons.video_library_outlined,
        },
      'reviews' => Icons.rate_review_outlined,
      'posters' || 'screenshots' => Icons.photo_library_outlined,
      'excerpts' => Icons.format_quote_outlined,
      'characters' => Icons.people_outline,
      _ => Icons.grid_view_outlined,
    };
  }

  // ─── 数据 ──────────────────────────────────────────────────────

  /// 模块 / 子项 id → 显示名（按当前模块区分文案）
  String _labelOf(String id) {
    if (widget.isExtra) {
      return switch (id) {
        'progress' => switch (widget.type) {
            'book' => '阅读进度',
            'game' => '游戏进度',
            _ => '观看进度',
          },
        'reviews' => switch (widget.type) {
            'book' => '书评',
            'game' => '游戏评价',
            _ => '影评',
          },
        'posters' => '海报墙',
        'excerpts' => '摘抄',
        'screenshots' => '游戏截图',
        'characters' => '角色',
        _ => id,
      };
    }
    return switch (id) {
      'credits' => switch (widget.type) {
          'book' => '书籍信息',
          'game' => '游戏信息',
          _ => '演职员信息',
        },
      'genres' => '类型标签',
      'characters' => '角色',
      'people' => '关联人物',
      'summary' => '简介',
      'reviews' => switch (widget.type) {
          'book' => '书评预览',
          'game' => '评价预览',
          _ => '影评预览',
        },
      'extra' => '更多入口',
      _ => id,
    };
  }

  void _save() {
    if (widget.isExtra) {
      _userPrefs.setDetailExtraItems(widget.type, _items);
    } else {
      _userPrefs.setDetailModules(widget.type, _items);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _items.insert(newIndex, _items.removeAt(oldIndex));
    });
    _save();
  }

  void _toggle(int index, bool visible) {
    setState(() {
      _items[index] = (id: _items[index].id, visible: visible);
    });
    _save();
  }

  void _reset() {
    setState(() {
      _items = [
        for (final id in widget.isExtra
            ? UserPrefs.detailExtraItemIds[widget.type] ?? const <String>[]
            : UserPrefs.detailModuleIds)
          (id: id, visible: true)
      ];
    });
    _save();
    ToastUtil.show(context, '已恢复默认'.tr);
  }
}

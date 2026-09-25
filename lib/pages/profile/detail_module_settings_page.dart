import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';

String _typeLabel(String type) => switch (type) {
      'book' => '阅读',
      'game' => '游戏',
      _ => '影视',
    };

IconData _typeIcon(String type) => switch (type) {
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      _ => Icons.movie_outlined,
    };

String _moduleLabel(String type, String id) {
  return switch (id) {
    'credits' => switch (type) {
        'book' => '书籍信息',
        'game' => '游戏信息',
        _ => '演职员信息',
      },
    'genres' => '类型标签',
    'characters' => '角色',
    'people' => '关联人物',
    'summary' => '简介',
    'reviews' => switch (type) {
        'book' => '书评预览',
        'game' => '评价预览',
        _ => '影评预览',
      },
    'extra' => '更多入口',
    _ => id,
  };
}

/// 详情页设置：影视 / 阅读 / 游戏 三个入口，点击进入对应模块编辑页
class DetailModuleSettingsPage extends StatefulWidget {
  const DetailModuleSettingsPage({super.key});

  @override
  State<DetailModuleSettingsPage> createState() =>
      _DetailModuleSettingsPageState();
}

class _DetailModuleSettingsPageState extends State<DetailModuleSettingsPage> {
  final _userPrefs = UserPrefs();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('详情页设置'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final type in ['movie', 'book', 'game'])
            _buildTypeTile(colors, type),
        ],
      ),
    );
  }

  Widget _buildTypeTile(ColorScheme colors, String type) {
    final modules = _userPrefs.getDetailModules(type);
    final visible = modules.where((m) => m.visible).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => _DetailModuleEditorPage(type: type)));
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(type), size: 20, color: colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_typeLabel(type).tr,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      '显示 {a}/{b} 个模块'
                          .trf({'a': '$visible', 'b': '${modules.length}'}),
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单个类型的详情页模块编辑（全屏）：线框样式模拟详情页结构，拖动排序、开关显隐
class _DetailModuleEditorPage extends StatefulWidget {
  final String type;
  const _DetailModuleEditorPage({required this.type});

  @override
  State<_DetailModuleEditorPage> createState() =>
      _DetailModuleEditorPageState();
}

class _DetailModuleEditorPageState extends State<_DetailModuleEditorPage> {
  final _userPrefs = UserPrefs();
  late List<({String id, bool visible})> _modules =
      _userPrefs.getDetailModules(widget.type);

  void _save() => _userPrefs.setDetailModules(widget.type, _modules);

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _modules.insert(newIndex, _modules.removeAt(oldIndex));
    });
    _save();
  }

  void _toggle(int index, bool visible) {
    setState(() {
      _modules[index] = (id: _modules[index].id, visible: visible);
    });
    _save();
  }

  void _reset() {
    setState(() {
      _modules = [
        for (final id in UserPrefs.detailModuleIds) (id: id, visible: true)
      ];
    });
    _save();
    ToastUtil.show(context, '已恢复默认'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_typeLabel(widget.type).tr),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text('重置'.tr,
                style:
                    TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '拖动调整{type}详情页模块顺序，开关控制显示'
                .trf({'type': _typeLabel(widget.type).tr}),
            style: TextStyle(
                fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ),
        onReorder: _onReorder,
        children: [
          for (var i = 0; i < _modules.length; i++) _buildFrame(i, colors),
        ],
      ),
    );
  }

  /// 单个模块的线框卡片：标题 + 开关 + 拖动手柄，下方是模拟详情页形态的骨架
  Widget _buildFrame(int index, ColorScheme colors) {
    final m = _modules[index];
    return Container(
      key: ValueKey(m.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _moduleLabel(widget.type, m.id).tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: m.visible
                        ? colors.onSurface
                        : colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Switch(
                value: m.visible,
                onChanged: (v) => _toggle(index, v),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.drag_indicator,
                      size: 18,
                      color: colors.onSurface.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
          Opacity(
            opacity: m.visible ? 1 : 0.35,
            child: Padding(
              padding: const EdgeInsets.only(right: 14, top: 2),
              child: _buildSkeleton(m.id, colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(ColorScheme colors, double width, {double height = 5}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }

  /// 模拟详情页各模块形态的迷你骨架
  Widget _buildSkeleton(String id, ColorScheme colors) {
    final ghost = colors.onSurface.withValues(alpha: 0.08);
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return switch (id) {
        // 信息行：标签 + 内容
        'credits' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final vw in [0.30, 0.45, 0.22])
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    _bar(colors, 30),
                    const SizedBox(width: 10),
                    _bar(colors, w * vw),
                  ]),
                ),
            ],
          ),
        // 类型标签：小胶囊
        'genres' => Row(children: [
            for (final cw in [42.0, 54.0, 36.0])
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: cw,
                height: 15,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                      width: 0.5),
                ),
              ),
          ]),
        // 角色 / 关联人物：头像圆 + 名字条
        'characters' || 'people' => Row(children: [
            for (var k = 0; k < 4; k++)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(children: [
                  Container(
                      width: 26,
                      height: 26,
                      decoration:
                          BoxDecoration(color: ghost, shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  _bar(colors, 22, height: 4),
                ]),
              ),
          ]),
        // 简介：多行文本
        'summary' => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(colors, w),
              const SizedBox(height: 5),
              _bar(colors, w),
              const SizedBox(height: 5),
              _bar(colors, w * 0.55),
            ],
          ),
        // 评价预览：头像块 + 文本行
        'reviews' => Column(children: [
            for (final fw in [0.30, 0.40])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: ghost, borderRadius: BorderRadius.circular(6))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(colors, w * fw, height: 4),
                        const SizedBox(height: 4),
                        _bar(colors, (w - 32) * 0.8, height: 4),
                      ],
                    ),
                  ),
                ]),
              ),
          ]),
        // 更多入口：小按钮
        'extra' => Row(children: [
            for (var k = 0; k < 3; k++)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ghost,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.7),
                      width: 0.5),
                ),
                child: Row(children: [
                  Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.18),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  _bar(colors, 24, height: 4),
                ]),
              ),
          ]),
        _ => const SizedBox.shrink(),
      };
    });
  }
}

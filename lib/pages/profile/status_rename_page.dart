import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/status_labels.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';

/// 主页模块状态自定义：影视 / 阅读 / 游戏各 4 个状态。
/// 支持自定义显示文案（留空用默认名）与拖拽调整显示顺序；底层状态 key 不变。
class StatusRenamePage extends StatefulWidget {
  const StatusRenamePage({super.key});

  @override
  State<StatusRenamePage> createState() => _StatusRenamePageState();
}

class _StatusRenamePageState extends State<StatusRenamePage> {
  static const _modules = [
    ('movie', '影视'),
    ('book', '阅读'),
    ('game', '游戏'),
  ];

  final UserPrefs _prefs = UserPrefs();
  // type → (statusKey → 输入控制器)
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  // type → 当前展示顺序（状态 key）
  final Map<String, List<String>> _order = {};

  @override
  void initState() {
    super.initState();
    for (final (type, _) in _modules) {
      final saved = _prefs.customStatusLabels(type);
      final keys = StatusLabels.orderedKeys(type);
      _controllers[type] = {
        for (final key in keys) key: TextEditingController(text: saved[key] ?? ''),
      };
      _order[type] = List<String>.from(keys);
    }
  }

  @override
  void dispose() {
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    for (final (type, _) in _modules) {
      final map = <String, String>{};
      _controllers[type]!.forEach((key, c) {
        final v = c.text.trim();
        if (v.isNotEmpty) map[key] = v;
      });
      await _prefs.setCustomStatusLabels(type, map);
      await _prefs.setCustomStatusOrder(type, _order[type]!);
    }
    if (!mounted) return;
    context.read<AppProvider>().notifyStatusLabelsChanged();
    ToastUtil.show(context, '已保存'.tr);
    Navigator.pop(context);
  }

  void _resetAll() {
    setState(() {
      for (final (type, _) in _modules) {
        for (final c in _controllers[type]!.values) {
          c.clear();
        }
        _order[type] = List<String>.from(StatusLabels.defaults[type]!.keys);
      }
    });
  }

  void _onReorder(String type, int oldIndex, int newIndex) {
    setState(() {
      final list = _order[type]!;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('主页模块状态自定义'.tr),
        actions: [
          TextButton(onPressed: _resetAll, child: Text('恢复默认'.tr)),
          TextButton(onPressed: _save, child: Text('保存'.tr)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text('留空则使用默认名称，自定义名称最多 8 个字'.tr,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.45))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text('拖动右侧手柄可调整状态显示顺序'.tr,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.45))),
          ),
          for (final (type, title) in _modules) ...[
            _buildSectionHeader(colors, title.tr),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _order[type]!.length,
              itemBuilder: (context, i) =>
                  _buildField(colors, type, _order[type]![i], i),
              onReorder: (oldIndex, newIndex) =>
                  _onReorder(type, oldIndex, newIndex),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme colors, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.55))),
    );
  }

  Widget _buildField(ColorScheme colors, String type, String key, int index) {
    final defaultLabel = StatusLabels.defaults[type]![key]!.tr;
    return Container(
      key: ValueKey('$type-$key'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(defaultLabel,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: TextField(
              controller: _controllers[type]![key],
              maxLength: 8,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                isCollapsed: true,
                counterText: '',
                border: InputBorder.none,
                hintText: defaultLabel,
                hintStyle: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.drag_indicator,
                  size: 20,
                  color: colors.onSurface.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

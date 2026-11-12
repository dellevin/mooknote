import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/custom_module_icon.dart';
import '../../l10n/app_strings.dart';
import 'custom_module_design_list_page.dart';

/// 自定义分类模块管理页（侧边栏工具区进入）
class CustomModuleManagePage extends StatefulWidget {
  const CustomModuleManagePage({super.key});

  @override
  State<CustomModuleManagePage> createState() => _CustomModuleManagePageState();
}

class _CustomModuleManagePageState extends State<CustomModuleManagePage> {
  final CustomModuleItemDao _itemDao = CustomModuleItemDao();
  final Map<String, int> _itemCounts = {};
  late int _layoutStyle; // 0 列表，1 网格

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().customModuleLayoutStyle;
    _loadItemCounts();
  }

  Future<void> _loadItemCounts() async {
    final modules = context.read<AppProvider>().customModules;
    for (final m in modules) {
      try {
        _itemCounts[m.id] = await _itemDao.getItemCount(m.id);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text('自定义分类'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_module_outlined, size: 22),
            tooltip: '切换方式'.tr,
            onPressed: _showLayoutSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final modules = provider.customModules;
          if (modules.isEmpty) return _buildEmptyState(colors);
          if (_layoutStyle == 1) return _buildGrid(context, modules, colors);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildModuleCard(context, modules[i], colors),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModuleDialog(context),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add, size: 20),
        label: Text('新建模块'.tr),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('还没有自定义模块'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('点击右下角新建属于你的分类'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, CustomModule module, ColorScheme colors) {
    final count = _itemCounts[module.id] ?? 0;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: buildCustomModuleIcon(module.icon, size: 18, color: colors.primary),
        ),
        title: Text(module.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        subtitle: Text(
          '{n} 个条目'.trf({'n': count}) + (module.isEnabled ? '' : ' · ${'已停用'.tr}'),
          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.45)),
        ),
        trailing: IconButton(
          icon: Icon(Icons.more_vert, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
          visualDensity: VisualDensity.compact,
          tooltip: '更多操作'.tr,
          onPressed: () => _showModuleActions(context, module),
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CustomModuleDesignListPage(moduleId: module.id),
          ));
        },
      ),
    );
  }

  /// 网格视图：一行三个，长按或点击进入设计页，长按弹出操作菜单
  Widget _buildGrid(BuildContext context, List<CustomModule> modules, ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: modules.length,
      itemBuilder: (context, i) => _buildGridCell(context, modules[i], colors),
    );
  }

  Widget _buildGridCell(BuildContext context, CustomModule module, ColorScheme colors) {
    final count = _itemCounts[module.id] ?? 0;
    return Opacity(
      opacity: module.isEnabled ? 1 : 0.4,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => CustomModuleDesignListPage(moduleId: module.id),
          )),
          onLongPress: () => _showModuleActions(context, module),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant, width: 0.6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: buildCustomModuleIcon(module.icon, size: 24, color: colors.primary),
                ),
                const SizedBox(height: 10),
                Text(module.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('{n} 个条目'.trf({'n': count}),
                      style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 布局切换底部弹窗：列表 / 网格
  Future<void> _showLayoutSheet() async {
    final colors = Theme.of(context).colorScheme;
    final options = <(int, IconData, String)>[
      (0, Icons.view_agenda_outlined, '列表'.tr),
      (1, Icons.grid_view_outlined, '网格'.tr),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('切换方式'.tr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
              ),
            ),
            for (final opt in options)
              InkWell(
                onTap: () async {
                  final navigator = Navigator.of(sheetContext);
                  await UserPrefs().setCustomModuleLayoutStyle(opt.$1);
                  if (!mounted) return;
                  setState(() => _layoutStyle = opt.$1);
                  navigator.pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Icon(opt.$2, size: 20, color: colors.onSurface.withValues(alpha: 0.7)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt.$3, style: TextStyle(fontSize: 15, color: colors.onSurface)),
                      ),
                      if (_layoutStyle == opt.$1)
                        Icon(Icons.check_circle, size: 20, color: colors.primary),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 模块操作底部弹窗：设计表单 / 编辑 / 启用·停用 / 删除
  void _showModuleActions(BuildContext context, CustomModule module) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        // 状态始终以 provider 中的实时数据为准，避免本地缓存导致开关显示错误
        final current =
            sheetContext.watch<AppProvider>().getCustomModuleById(module.id) ?? module;
        final enabled = current.isEnabled;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(module.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
                    ),
                    if (!enabled)
                      Text('已停用'.tr,
                          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ),
              _buildActionRow(
                icon: Icons.dashboard_customize_outlined,
                label: '设计表单'.tr,
                colors: colors,
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CustomModuleDesignListPage(moduleId: module.id),
                  ));
                },
              ),
              _buildActionRow(
                icon: Icons.edit_note,
                label: '编辑'.tr,
                colors: colors,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showModuleDialog(context, existing: module);
                },
              ),
              _buildActionRow(
                icon: Icons.power_settings_new,
                label: '停用'.tr,
                colors: colors,
                trailing: Switch(
                  // 打开=停用，关闭=启用（正常）
                  value: !enabled,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) =>
                      context.read<AppProvider>().setCustomModuleEnabled(module.id, !v),
                ),
                onTap: () =>
                    context.read<AppProvider>().setCustomModuleEnabled(module.id, !enabled),
              ),
              _buildActionRow(
                icon: Icons.delete_forever,
                label: '删除'.tr,
                colors: colors,
                danger: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, module);
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required ColorScheme colors,
    required VoidCallback onTap,
    bool danger = false,
    Widget? trailing,
  }) {
    final color = danger ? colors.error : colors.onSurface.withValues(alpha: 0.75);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  /// 新建/重命名模块弹窗
  /// 新建/重命名模块弹窗（底部弹出，与表单设计的字段配置弹层同款结构）
  void _showModuleDialog(BuildContext context, {CustomModule? existing}) {
    final colors = Theme.of(context).colorScheme;
    String selectedIcon = existing?.icon ?? '';
    final isEdit = existing != null;

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => OwnedTextController(
        initialText: existing?.name ?? '',
        builder: (ctx, controller) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Text(isEdit ? '重命名模块'.tr : '新建模块'.tr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: !isEdit,
                  maxLength: 10,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '模块名称（如：追剧、播客）'.tr,
                    hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
                    counterStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(height: 12),
                Text('图标'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                // FontAwesome 图标网格，上下滑动选择；再次点击已选图标可取消
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: kCustomModuleIcons.length,
                    itemBuilder: (ctx, i) {
                      final iconData = kCustomModuleIcons[i];
                      final iconKey = iconData.codePoint.toString();
                      final selected = selectedIcon == iconKey;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedIcon = selected ? '' : iconKey),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected ? colors.primary : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            iconData,
                            size: 17,
                            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        ToastUtil.show(context, '请输入模块名称'.tr);
                        return;
                      }
                      final provider = context.read<AppProvider>();
                      if (isEdit) {
                        await provider.updateCustomModule(existing.copyWith(name: name, icon: selectedIcon));
                      } else {
                        await provider.addCustomModule(name, icon: selectedIcon);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(isEdit ? '保存'.tr : '创建'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CustomModule module) {
    final colors = Theme.of(context).colorScheme;
    final count = _itemCounts[module.id] ?? 0;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('删除模块'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          '删除「{name}」后，其下的{items}表单设计将一并删除。'.trf({
            'name': module.name,
            'items': count > 0 ? ' {n} 个条目和所有'.trf({'n': count}) : '',
          }),
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              await context.read<AppProvider>().deleteCustomModule(module.id);
              _itemCounts.remove(module.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('删除'.tr),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/toast_util.dart';
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

  @override
  void initState() {
    super.initState();
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
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final modules = provider.customModules;
          if (modules.isEmpty) return _buildEmptyState(colors);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildModuleCard(context, modules[i], colors),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showModuleDialog(context),
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
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: buildCustomModuleIcon(module.icon, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
        title: Text(module.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        subtitle: Text(
          '{n} 个条目'.trf({'n': count}) + (module.isEnabled ? '' : ' · ${'已停用'.tr}'),
          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) {
            switch (v) {
              case 'design':
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CustomModuleDesignListPage(moduleId: module.id),
                ));
                break;
              case 'rename':
                _showModuleDialog(context, existing: module);
                break;
              case 'delete':
                _confirmDelete(context, module);
                break;
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'design', child: Text('设计表单'.tr)),
            PopupMenuItem(value: 'rename', child: Text('编辑'.tr)),
            PopupMenuItem(value: 'delete', child: Text('删除'.tr, style: TextStyle(color: colors.error))),
          ],
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CustomModuleDesignListPage(moduleId: module.id),
          ));
        },
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

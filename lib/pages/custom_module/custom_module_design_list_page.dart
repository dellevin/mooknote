import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../widgets/app_overlay.dart';
import '../../l10n/app_strings.dart';
import 'custom_module_design_page.dart';

/// 自定义模块的表单设计列表页：展示该模块下所有表单设计
/// 支持新增/重命名/删除/切换使用中，点击进入单个设计的编辑页
class CustomModuleDesignListPage extends StatefulWidget {
  final String moduleId;
  const CustomModuleDesignListPage({super.key, required this.moduleId});

  @override
  State<CustomModuleDesignListPage> createState() => _CustomModuleDesignListPageState();
}

class _CustomModuleDesignListPageState extends State<CustomModuleDesignListPage> {
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();
  List<CustomModuleDesign> _designs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _designs = await _designDao.getDesignsForModule(widget.moduleId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  /// 进入某个设计的编辑页，返回后刷新（字段数可能变化）
  Future<void> _openEditor(CustomModuleDesign design) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CustomModuleDesignPage(moduleId: widget.moduleId, designId: design.id),
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final module = context.watch<AppProvider>().getCustomModuleById(widget.moduleId);
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(module != null ? '${module.name} · 表单设计' : '表单设计'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: colors.surface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _designs.isEmpty
              ? _buildEmptyState(colors)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _designs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _buildDesignCard(_designs[i], colors),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDesignDialog,
        icon: const Icon(Icons.add, size: 20),
        label: Text('新建设计'.tr),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_outlined, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('还没有表单设计'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('点击右下角新建一个表单设计'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _buildDesignCard(CustomModuleDesign design, ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(Icons.article_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
        title: Text(design.name,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        subtitle: Text(
          '{n} 个字段'.trf({'n': design.fields.length}) + (design.isActive ? ' · ${'使用中'.tr}' : ''),
          style: TextStyle(
            fontSize: 12,
            color: design.isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.45),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (design.isActive)
              Icon(Icons.check_circle, size: 18, color: colors.primary),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                switch (v) {
                  case 'activate':
                    _activateDesign(design);
                    break;
                  case 'rename':
                    _showRenameDialog(design);
                    break;
                  case 'delete':
                    _confirmDelete(design);
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (!design.isActive)
                  PopupMenuItem(value: 'activate', child: Text('设为使用中'.tr)),
                PopupMenuItem(value: 'rename', child: Text('编辑'.tr)),
                PopupMenuItem(value: 'delete', child: Text('删除'.tr, style: TextStyle(color: colors.error))),
              ],
            ),
          ],
        ),
        onTap: () => _openEditor(design),
      ),
    );
  }

  Future<void> _activateDesign(CustomModuleDesign design) async {
    await _designDao.setActiveDesign(widget.moduleId, design.id);
    if (!mounted) return;
    await context.read<AppProvider>().loadCustomModules();
    await _load();
  }

  void _showNewDesignDialog() {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: '设计 ${_designs.length + 1}');
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('新建设计'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true, maxLength: 10,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '设计名称'.tr,
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final now = DateTime.now();
              final design = CustomModuleDesign(
                id: const Uuid().v4(),
                moduleId: widget.moduleId,
                name: name,
                createdAt: now,
                updatedAt: now,
              );
              await _designDao.insertDesign(design);
              // 第一份设计自动设为使用中
              if (_designs.isEmpty) {
                await _designDao.setActiveDesign(widget.moduleId, design.id);
                if (mounted) await context.read<AppProvider>().loadCustomModules();
              }
              if (!mounted) return;
              if (ctx.mounted) Navigator.pop(ctx);
              // 新建后直接进入编辑页添加字段
              _openEditor(design);
            },
            child: Text('创建'.tr),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(CustomModuleDesign design) {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: design.name);
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重命名设计'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true, maxLength: 10,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await _designDao.updateDesign(design.copyWith(name: name, updatedAt: DateTime.now()));
              await _load();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('保存'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(CustomModuleDesign design) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('删除设计'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          '删除「${design.name}」？已录入条目的数据会保留，但不再按此表单显示。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              await _designDao.deleteDesign(widget.moduleId, design.id);
              if (!mounted) return;
              await context.read<AppProvider>().loadCustomModules();
              await _load();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('删除'.tr),
          ),
        ],
      ),
    );
  }
}

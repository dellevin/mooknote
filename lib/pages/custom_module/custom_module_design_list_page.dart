import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../utils/toast_util.dart';
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
        title: Text(module != null ? '{name} · 表单设计'.trf({'name': module.name}) : '表单设计'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: colors.surface,
        actions: [
          TextButton(
            onPressed: _importDesign,
            child: Text('导入'.tr),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _designs.isEmpty
              ? _buildEmptyState(colors)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _designs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _buildDesignCard(_designs[i], colors),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewDesignDialog,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
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
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(design),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: design.isActive
                ? Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(Icons.article_outlined, size: 18, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(design.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _buildMiniPill(
                          '{n} 个字段'.trf({'n': design.fields.length}),
                          bg: colors.surface,
                          fg: colors.onSurface.withValues(alpha: 0.55),
                        ),
                        if (design.isActive) ...[
                          const SizedBox(width: 6),
                          _buildMiniPill('使用中'.tr,
                              bg: colors.primary.withValues(alpha: 0.12), fg: colors.primary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
                visualDensity: VisualDensity.compact,
                tooltip: '更多操作'.tr,
                onPressed: () => _showDesignActions(design),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPill(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(text, style: TextStyle(fontSize: 10, color: fg)),
    );
  }

  /// 设计操作底部弹窗：设为使用中 / 编辑 / 导出 / 删除
  void _showDesignActions(CustomModuleDesign design) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(design.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
                  ),
                  if (design.isActive)
                    Text('使用中'.tr,
                        style: TextStyle(fontSize: 11, color: colors.primary)),
                ],
              ),
            ),
            if (!design.isActive)
              _buildActionRow(
                icon: Icons.check_circle_outline,
                label: '设为使用中'.tr,
                colors: colors,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _activateDesign(design);
                },
              ),
            _buildActionRow(
              icon: Icons.edit_note,
              label: '编辑'.tr,
              colors: colors,
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(design);
              },
            ),
            _buildActionRow(
              icon: Icons.ios_share,
              label: '导出'.tr,
              colors: colors,
              onTap: () {
                Navigator.pop(sheetContext);
                _exportDesign(design);
              },
            ),
            _buildActionRow(
              icon: Icons.delete_forever,
              label: '删除'.tr,
              colors: colors,
              danger: true,
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmDelete(design);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required ColorScheme colors,
    required VoidCallback onTap,
    bool danger = false,
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
          ],
        ),
      ),
    );
  }

  Future<void> _activateDesign(CustomModuleDesign design) async {
    await _designDao.setActiveDesign(widget.moduleId, design.id);
    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.loadCustomModules();
    // 激活状态变化要通知保活的 tab 页刷新（本页可能从管理页进入，返回时 tab 不会重载）
    provider.bumpCustomModuleItemsVersion();
    await _load();
  }

  void _showNewDesignDialog() {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => OwnedTextController(
        initialText: '设计 ${_designs.length + 1}',
        builder: (ctx, controller) => AlertDialog(
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
              // 模块当前没有启用中的设计时，新设计自动设为使用中
              if (!_designs.any((d) => d.isActive)) {
                await _designDao.setActiveDesign(widget.moduleId, design.id);
                if (mounted) await context.read<AppProvider>().loadCustomModules();
                if (mounted) context.read<AppProvider>().bumpCustomModuleItemsVersion();
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
        ),
    );
  }

  void _showRenameDialog(CustomModuleDesign design) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => OwnedTextController(
        initialText: design.name,
        builder: (ctx, controller) => AlertDialog(
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
          '删除「{name}」？已录入条目的数据会保留，但不再按此表单显示。'.trf({'name': design.name}),
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              await _designDao.deleteDesign(widget.moduleId, design.id);
              if (!mounted) return;
              final provider = context.read<AppProvider>();
              await provider.loadCustomModules();
              // 删掉的可能正是启用中的设计，通知保活的 tab 页刷新
              provider.bumpCustomModuleItemsVersion();
              await _load();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('删除'.tr),
          ),
        ],
      ),
    );
  }

  // ─── 导入 / 导出设计 ────────────────────────────────────────────────────

  /// 导出设计为 JSON 文件：Android 写入 Download/mooknote/design/，桌面端存到指定位置
  Future<void> _exportDesign(CustomModuleDesign design) async {
    try {
      final payload = {
        'format': 'mooknote-form-design',
        'version': 1,
        'name': design.name,
        'fields': design.fields.map((f) => f.toJson()).toList(),
      };
      final content = const JsonEncoder.withIndent('  ').convert(payload);
      final fileName = '表单设计_${design.name}.json';
      // 直接写入 /sdcard/Download/mooknote/design/
      {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          if (mounted) ToastUtil.show(context, '需要存储权限才能导出'.tr);
          return;
        }
        final dir = Directory('/sdcard/Download/mooknote/design');
        await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content);
        if (mounted) {
          ToastUtil.show(context, '已导出到 {path}'.trf({'path': file.path}));
        }
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '导出失败: $e'.tr);
    }
  }

  /// 从 JSON 文件导入设计：作为当前模块的新设计插入（不覆盖已有设计）
  Future<void> _importDesign() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入表单设计'.tr,
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      final String content;
      if (picked.bytes != null) {
        content = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        content = await File(picked.path!).readAsString();
      } else {
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map ||
          decoded['format'] != 'mooknote-form-design' ||
          decoded['fields'] is! List) {
        if (mounted) ToastUtil.show(context, '文件无效：不是表单设计文件'.tr);
        return;
      }
      // 逐字段容错解析（与 fromJson 一致），但至少要有一个可用字段
      final fields = <CustomFieldDef>[];
      for (final e in decoded['fields'] as List) {
        try {
          fields.add(CustomFieldDef.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {}
      }
      if (fields.isEmpty) {
        if (mounted) ToastUtil.show(context, '文件无效：没有可用字段'.tr);
        return;
      }

      var name = (decoded['name'] ?? '').toString().trim();
      if (name.isEmpty) name = '导入的设计'.tr;
      final now = DateTime.now();
      final design = CustomModuleDesign(
        id: const Uuid().v4(),
        moduleId: widget.moduleId,
        name: name,
        fields: fields,
        createdAt: now,
        updatedAt: now,
      );
      await _designDao.insertDesign(design);
      // 模块当前没有启用中的设计时，导入的设计自动设为使用中
      if (!_designs.any((d) => d.isActive)) {
        await _designDao.setActiveDesign(widget.moduleId, design.id);
        if (mounted) await context.read<AppProvider>().loadCustomModules();
        if (mounted) context.read<AppProvider>().bumpCustomModuleItemsVersion();
      }
      if (!mounted) return;
      ToastUtil.show(context, '已导入「{name}」（{n} 个字段）'
          .trf({'name': design.name, 'n': fields.length}));
      _load();
    } catch (e) {
      if (mounted) ToastUtil.show(context, '导入失败: $e'.tr);
    }
  }
}

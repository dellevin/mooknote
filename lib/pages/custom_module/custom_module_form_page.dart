import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/custom_module_field.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/edit_sheets.dart';
import '../../widgets/genre_selector_page.dart';
import '../../l10n/app_strings.dart';

/// 自定义模块条目 新增/编辑 表单页：按激活设计的 fields_json 动态渲染
/// （字段控件渲染与设计页共用 custom_module_field.dart，保证两处 UI 一致）
class CustomModuleFormPage extends StatefulWidget {
  final CustomModule module;
  final CustomModuleItem? item; // null = 新增

  const CustomModuleFormPage({super.key, required this.module, this.item});

  @override
  State<CustomModuleFormPage> createState() => _CustomModuleFormPageState();
}

class _CustomModuleFormPageState extends State<CustomModuleFormPage> {
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();
  final CustomModuleItemDao _itemDao = CustomModuleItemDao();
  final ImagePicker _picker = ImagePicker();

  CustomModuleDesign? _design;
  bool _loading = true;

  /// 全部字段值 {fieldKey: value}
  final Map<String, dynamic> _values = {};

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _loadDesign();
  }

  Future<void> _loadDesign() async {
    try {
      _design = await _designDao.getActiveDesign(widget.module.id);
      if (_design != null) _initValues();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _initValues() {
    final data = widget.item?.data ?? const {};
    for (final f in _design!.fields) {
      switch (f.type) {
        case CustomFieldType.text:
        case CustomFieldType.longText:
          _values[f.key] = data[f.key]?.toString() ?? '';
          break;
        case CustomFieldType.multiText:
          _values[f.key] = parseStringListGeneric(data[f.key]);
          break;
        case CustomFieldType.count:
          final v = data[f.key];
          _values[f.key] = v is int ? v : (v is num ? v.toInt() : 0);
          break;
        case CustomFieldType.duration:
          final v = data[f.key];
          _values[f.key] = v is num ? v.toInt() : null;
          break;
        case CustomFieldType.rating:
          final v = data[f.key];
          _values[f.key] = v is num ? v.toDouble() : null;
          break;
        case CustomFieldType.status:
        case CustomFieldType.date:
        case CustomFieldType.poster:
          _values[f.key] = data[f.key];
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑'.tr : '新增'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: colors.surface,
        actions: [
          if (!_loading && _design != null)
            TextButton(
              onPressed: _save,
              child: Text('保存'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _design == null
              ? _buildNoDesign(colors)
              : _buildForm(colors),
    );
  }

  Widget _buildNoDesign(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard_outlined, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('该模块还没有启用中的表单设计'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('请先到 侧边栏 → 分类模块 中设计表单'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  // ─── 表单渲染 ───

  Widget _buildForm(ColorScheme colors) {
    final fields = _design!.fields;
    final posterField = _design!.firstFieldOf(CustomFieldType.poster);
    if (fields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('当前设计还没有字段，请先到设计页添加'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
        ),
      );
    }
    // 与影视表单一致的卡片样式：
    // 海报/长文本独占一行；连续的状态/评分合并为一张整行卡；
    // 单文本/多文本/时间/次数 为半行的连续两个并排一行，否则独占一行
    bool isControl(CustomFieldType t) =>
        t == CustomFieldType.status || t == CustomFieldType.rating;
    bool isPairable(CustomFieldDef f) =>
        f.halfWidth &&
        (f.type == CustomFieldType.text ||
            f.type == CustomFieldType.multiText ||
            f.type == CustomFieldType.date ||
            f.type == CustomFieldType.duration ||
            f.type == CustomFieldType.count);

    final bodyFields = fields.where((f) => f.type != CustomFieldType.poster).toList();
    final rowWidgets = <Widget>[];
    var i = 0;
    while (i < bodyFields.length) {
      final f = bodyFields[i];
      if (isControl(f.type)) {
        final group = <CustomFieldDef>[f];
        while (i + 1 < bodyFields.length && isControl(bodyFields[i + 1].type)) {
          group.add(bodyFields[++i]);
        }
        rowWidgets.add(_buildControlCard(group, colors));
      } else if (isPairable(f)) {
        final pair = <CustomFieldDef>[f];
        if (i + 1 < bodyFields.length && isPairable(bodyFields[i + 1])) {
          pair.add(bodyFields[++i]);
        }
        rowWidgets.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: pair.length == 2
              ? [
                  Expanded(child: _buildField(pair[0], colors)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField(pair[1], colors)),
                ]
              // 落单的半行字段仍占半行，另一侧留空（位置遵循 halfOnLeft，与设计页一致）
              : pair[0].halfOnLeft
                  ? [
                      Expanded(child: _buildField(pair[0], colors)),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ]
                  : [
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildField(pair[0], colors)),
                    ],
        ));
      } else {
        rowWidgets.add(_buildField(f, colors));
      }
      i++;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 海报固定在顶部居中（与影视表单一致）
          if (posterField != null) ...[
            Center(child: _buildPoster(posterField, colors)),
            const SizedBox(height: 16),
          ],
          for (final w in rowWidgets) ...[
            w,
            if (w != rowWidgets.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildPoster(CustomFieldDef f, ColorScheme colors) {
    return customModulePosterField(
      f,
      _values[f.key] as String?,
      colors,
      onPick: () => _pickCover(f.key),
      onRemove: () => setState(() => _values[f.key] = null),
    );
  }

  Widget _buildField(CustomFieldDef f, ColorScheme colors) {
    switch (f.type) {
      case CustomFieldType.poster:
      case CustomFieldType.status:
      case CustomFieldType.rating:
        return const SizedBox.shrink(); // 海报在顶部；状态/评分由 _buildControlCard 合并渲染
      case CustomFieldType.text:
        return customModuleTextCard(f, _values[f.key] as String?, colors,
            multiline: false, onTap: () => _editText(f, multiline: false));
      case CustomFieldType.longText:
        return customModuleTextCard(f, _values[f.key] as String?, colors,
            multiline: true, onTap: () => _editText(f, multiline: true));
      case CustomFieldType.multiText:
        final items = (_values[f.key] as List<String>?) ?? [];
        return customModuleMultiTextCard(
          f, items, colors,
          onTap: () => _editMultiTextItems(f, items),
        );
      case CustomFieldType.date:
        return customModuleDateCard(
          f, _values[f.key] as String?, colors,
          onTap: () => _pickDate(f),
          onClear: () => setState(() => _values[f.key] = null),
        );
      case CustomFieldType.duration:
        return customModuleDurationCard(
          f, _values[f.key] as int?, colors,
          onTap: () => _pickDuration(f),
          onClear: () => setState(() => _values[f.key] = null),
        );
      case CustomFieldType.count:
        return customModuleCountCard(f, (_values[f.key] as int?) ?? 0, colors,
            (v) => setState(() => _values[f.key] = v));
    }
  }

  /// 状态/评分合并卡（与影视表单的「状态评分」卡一致：整行一张卡，每个字段卡内一行）
  Widget _buildControlCard(List<CustomFieldDef> group, ColorScheme colors) {
    return customModuleCard(
      colors,
      child: Column(
        children: [
          for (var i = 0; i < group.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildControlRow(group[i], colors),
          ],
        ],
      ),
    );
  }

  Widget _buildControlRow(CustomFieldDef f, ColorScheme colors) {
    switch (f.type) {
      case CustomFieldType.status:
        return customModuleStatusRow(f, _values[f.key] as String?, colors,
            (v) => setState(() => _values[f.key] = v));
      case CustomFieldType.rating:
        return customModuleRatingRow(f, _values[f.key] as double?, colors,
            (v) => setState(() => _values[f.key] = v));
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── 字段交互 ───

  Future<void> _pickCover(String fieldKey) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 1200, imageQuality: 85,
      );
      if (picked == null) return;
      final itemId = widget.item?.id ?? const Uuid().v4();
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getCustomModuleCoverPath(widget.module.id, itemId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (!mounted) return;
      setState(() => _values[fieldKey] = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: {e}'.trf({'e': e}));
    }
  }

  /// 单文本/长文本：底部弹层编辑（与影视表单 名称/剧情简介 一致）
  Future<void> _editText(CustomFieldDef f, {required bool multiline}) async {
    final result = await TextEditSheet.show(
      context: context,
      title: f.label,
      initialText: _values[f.key]?.toString() ?? '',
      hintText: '请输入 {x}'.trf({'x': f.label}),
      multiline: multiline,
    );
    if (!mounted || result == null) return;
    setState(() => _values[f.key] = result);
  }

  /// 多文本：底部弹层编辑（与影视表单 导演/编剧 一致，候选来自本模块已录条目的同字段值）
  Future<void> _editMultiTextItems(CustomFieldDef f, List<String> items) async {
    final allItems = await _itemDao.getItemsForModule(widget.module.id);
    if (!mounted) return;
    final existing = <String>{};
    for (final it in allItems) {
      existing.addAll(parseStringListGeneric(it.data[f.key]));
    }
    final result = await GenreSelectorPage.show(
      context: context,
      title: f.label,
      existingTags: existing.toList(),
      initialSelected: items,
      asBottomSheet: true,
    );
    if (!mounted || result == null) return;
    setState(() => _values[f.key] = result);
  }

  Future<void> _pickDate(CustomFieldDef f) async {
    final iso = _values[f.key] as String?;
    final picked = await showDatePickerSheet(
      context: context,
      title: f.label,
      initial: iso != null ? DateTime.tryParse(iso) : null,
    );
    if (picked != null) setState(() => _values[f.key] = picked.toIso8601String());
  }

  /// 时长：时:分滚轮底部弹层（与影视表单 影视总时长 一致），值存总分钟数
  Future<void> _pickDuration(CustomFieldDef f) async {
    final result = await DurationPicker.show(
      context: context,
      initialMinutes: (_values[f.key] as int?) ?? 0,
      title: f.label,
    );
    if (!mounted || result == null) return;
    setState(() => _values[f.key] = result);
  }

  // ─── 保存 ───

  Future<void> _save() async {
    final design = _design!;
    // 必填校验
    for (final f in design.fields) {
      if (!f.required) continue;
      final v = _values[f.key];
      final empty = v == null ||
          (v is String && v.trim().isEmpty) ||
          (v is List && v.isEmpty);
      if (empty) {
        ToastUtil.show(context, '请填写「{label}」'.trf({'label': f.label}));
        return;
      }
    }
    // 提取列表展示列
    String title = '';
    final titleField = design.titleField;
    if (titleField != null) title = _values[titleField.key]?.toString() ?? '';
    final posterField = design.firstFieldOf(CustomFieldType.poster);
    final ratingField = design.firstFieldOf(CustomFieldType.rating);
    final statusField = design.firstFieldOf(CustomFieldType.status);

    // 清理 null 值，保持 data_json 精简
    final data = <String, dynamic>{};
    _values.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is List && v.isEmpty) return;
      data[k] = v;
    });

    final now = DateTime.now();
    final item = CustomModuleItem(
      id: widget.item?.id ?? const Uuid().v4(),
      moduleId: widget.module.id,
      title: title,
      coverPath: posterField != null ? _values[posterField.key] as String? : null,
      rating: ratingField != null ? _values[ratingField.key] as double? : null,
      status: statusField != null ? _values[statusField.key] as String? : null,
      data: data,
      createdAt: widget.item?.createdAt ?? now,
      updatedAt: now,
    );
    if (_isEdit) {
      await _itemDao.updateItem(item);
    } else {
      await _itemDao.insertItem(item);
    }
    if (!mounted) return;
    // 通知 tab 页刷新（条目可能来自底部 + 弹窗等外部入口）
    context.read<AppProvider>().bumpCustomModuleItemsVersion();
    Navigator.pop(context, true);
  }
}

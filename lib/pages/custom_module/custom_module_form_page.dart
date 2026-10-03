import 'dart:convert';
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
import '../../utils/image_picker_helper.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/custom_module_field.dart';
import '../../widgets/duration_picker.dart';
import '../../widgets/edit_sheets.dart';
import '../../widgets/fade_in_local_image.dart';
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

  /// 条目 id：新增时页面级生成一次（封面/多图目录与最终保存的条目 id 保持一致）
  late final String _itemId = widget.item?.id ?? const Uuid().v4();

  /// 原型编辑模式：直接编辑条目 JSON（仅编辑已有条目时可用）
  bool _rawMode = false;
  final _JsonEditingController _rawController = _JsonEditingController();
  String? _rawError;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _loadDesign();
  }

  @override
  void dispose() {
    _rawController.dispose();
    super.dispose();
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
        case CustomFieldType.progress:
        case CustomFieldType.dateRange:
          _values[f.key] = data[f.key];
          break;
        case CustomFieldType.multiImage:
          _values[f.key] = parseStringListGeneric(data[f.key]);
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
          if (!_loading && _design != null) ...[
            if (_isEdit)
              IconButton(
                icon: Icon(
                  _rawMode ? Icons.dashboard_customize_outlined : Icons.data_object,
                  size: 20,
                  color: colors.primary,
                ),
                tooltip: _rawMode ? '表单编辑'.tr : '原型编辑（JSON）'.tr,
                onPressed: _toggleRawMode,
              ),
            TextButton(
              onPressed: _rawMode ? _saveRaw : _save,
              child: Text('保存'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _design == null
              ? _buildNoDesign(colors)
              : _rawMode
                  ? _buildRawEditor(colors)
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
          Text('请先到 侧边栏 → 自定义分类 中设计表单'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
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
            f.type == CustomFieldType.progress ||
            f.type == CustomFieldType.dateRange ||
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
      case CustomFieldType.progress:
        return customModuleProgressCard(
          f, _values[f.key], colors,
          onTap: () => _editProgress(f),
          onClear: () => setState(() => _values[f.key] = null),
        );
      case CustomFieldType.dateRange:
        return customModuleDateRangeCard(
          f, _values[f.key], colors,
          onTap: () => _editDateRange(f),
          onClear: () => setState(() => _values[f.key] = null),
        );
      case CustomFieldType.multiImage:
        final paths = (_values[f.key] as List<String>?) ?? [];
        return customModuleMultiImageCard(
          f, paths, colors,
          onAdd: () => _pickMultiImages(f),
          onTapImage: (i) => _previewImage(paths, i),
          onRemoveImage: (i) => setState(() => paths.removeAt(i)),
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
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getCustomModuleCoverPath(widget.module.id, _itemId, fileName);
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

  /// 进度：弹层输入 当前/总量；保存时都为 0 视为未填写
  Future<void> _editProgress(CustomFieldDef f) async {
    final (cur, total) = parseCustomModuleProgress(_values[f.key]) ?? (0, 0);
    final result = await showEditSheet<Map<String, int>>(
      context: context,
      title: f.label,
      contentBuilder: (ctx) => OwnedTextController(
        initialText: cur > 0 ? cur.toString() : '',
        builder: (ctx, curCtrl) => OwnedTextController(
          initialText: total > 0 ? total.toString() : '',
          builder: (ctx, totalCtrl) {
            final colors = Theme.of(ctx).colorScheme;
            Widget numField(String label, String hint, TextEditingController ctrl) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  numField('当前进度'.tr, '如 12'.tr, curCtrl),
                  const SizedBox(height: 16),
                  numField('总量'.tr, '如 24'.tr, totalCtrl),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, {
                        'current': int.tryParse(curCtrl.text.trim()) ?? 0,
                        'total': int.tryParse(totalCtrl.text.trim()) ?? 0,
                      }),
                      child: Text('保存'.tr),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    final c = result['current'] ?? 0, t = result['total'] ?? 0;
    setState(() => _values[f.key] = (c == 0 && t == 0) ? null : {'current': c, 'total': t});
  }

  /// 日期区间：弹层两行分别选 开始/结束日期；保存时都为空视为未填写
  Future<void> _editDateRange(CustomFieldDef f) async {
    var (start, end) = parseCustomModuleDateRange(_values[f.key]);
    final result = await showEditSheet<Map<String, String>>(
      context: context,
      title: f.label,
      actionBuilder: (ctx) => editSheetDoneButton(ctx, '确定'.tr, () {
        Navigator.pop(ctx, {
          if (start != null) 'start': start!,
          if (end != null) 'end': end!,
        });
      }),
      contentBuilder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final colors = Theme.of(ctx).colorScheme;
          Widget row(String label, String? iso, VoidCallback onPick, VoidCallback onClear) {
            final d = iso != null ? DateTime.tryParse(iso) : null;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(label, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
              subtitle: Text(
                d != null
                    ? '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}'
                    : '点击选择'.tr,
                style: TextStyle(fontSize: 15, color: d != null ? colors.onSurface : colors.onSurface.withValues(alpha: 0.3)),
              ),
              trailing: iso != null
                  ? GestureDetector(onTap: onClear, child: Icon(Icons.close, size: 18, color: colors.onSurface.withValues(alpha: 0.4)))
                  : null,
              onTap: onPick,
            );
          }
          return Column(children: [
            row('开始日期'.tr, start, () async {
              final d = await showDatePickerSheet(context: ctx, title: '开始日期'.tr, initial: start != null ? DateTime.tryParse(start!) : null);
              if (d != null) setSheetState(() => start = d.toIso8601String());
            }, () => setSheetState(() => start = null)),
            row('结束日期'.tr, end, () async {
              final d = await showDatePickerSheet(context: ctx, title: '结束日期'.tr, initial: end != null ? DateTime.tryParse(end!) : null);
              if (d != null) setSheetState(() => end = d.toIso8601String());
            }, () => setSheetState(() => end = null)),
          ]);
        },
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _values[f.key] = result.isEmpty ? null : result);
  }

  /// 多图：多选本地图片复制到条目图片目录
  Future<void> _pickMultiImages(CustomFieldDef f) async {
    try {
      final files = await pickLocalImages(context);
      if (!mounted || files.isEmpty) return;
      final dir = await ImagePathHelper.instance.getCustomModuleImagesDir(widget.module.id, _itemId);
      await ImagePathHelper.instance.ensureDirExists(dir);
      final paths = (_values[f.key] as List<String>?) ?? <String>[];
      for (final file in files) {
        final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_${paths.length}$ext';
        final targetPath = p.join(dir, fileName);
        await file.copy(targetPath);
        paths.add(targetPath);
      }
      setState(() => _values[f.key] = paths);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: {e}'.trf({'e': e}));
    }
  }

  /// 图片预览（与笔记详情一致：点按关闭）
  void _previewImage(List<String> paths, int index) {
    appDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: FadeInLocalImage(path: paths[index], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 原型编辑（JSON） ───

  void _toggleRawMode() {
    setState(() {
      _rawMode = !_rawMode;
      if (_rawMode) {
        _rawError = null;
        _rawController.text =
            const JsonEncoder.withIndent('  ').convert(_currentDataMerged());
      }
    });
  }

  /// 原始 data 叠加当前表单值：设计外旧字段也要展示出来，供手动清理/修正
  Map<String, dynamic> _currentDataMerged() {
    final merged = Map<String, dynamic>.from(widget.item?.data ?? const {});
    _values.forEach((k, v) {
      if (v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty)) {
        merged.remove(k);
      } else {
        merged[k] = v;
      }
    });
    return merged;
  }

  Widget _buildRawEditor(ColorScheme colors) {
    _rawController.colors = colors;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _rawController,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: colors.onSurface,
                height: 1.5,
              ),
              // 全局主题给输入框加了下划线边框，这里要全部显式置空
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) {
                if (_rawError != null) setState(() => _rawError = null);
              },
            ),
          ),
        ),
        if (_rawError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Icon(Icons.error_outline, size: 14, color: colors.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_rawError!,
                    style: TextStyle(fontSize: 12, color: colors.error)),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            '直接编辑条目 JSON，保存时校验格式与字段类型，不通过不会保存'.tr,
            style: TextStyle(
                fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
          ),
        ),
      ],
    );
  }

  /// 校验原型编辑内容，返回错误信息（null = 通过）
  String? _validateRawData(String text) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      return 'JSON 语法错误：${e.message}'.tr;
    }
    if (decoded is! Map) return '内容必须是 JSON 对象 {...}'.tr;

    final byKey = {for (final f in _design!.fields) f.key: f};
    for (final entry in decoded.entries) {
      final f = byKey[entry.key];
      if (f == null) continue; // 设计之外的旧字段不校验类型，允许保留或自行删除
      final v = entry.value;
      if (v == null) continue;
      final err = _checkFieldValue(f, v);
      if (err != null) return '「${f.label}」$err';
    }
    // 必填校验与表单模式一致
    for (final f in _design!.fields) {
      if (!f.required) continue;
      final v = decoded[f.key];
      final empty = v == null ||
          (v is String && v.trim().isEmpty) ||
          (v is List && v.isEmpty);
      if (empty) return '「${f.label}」为必填项'.tr;
    }
    return null;
  }

  /// 按当前设计的字段类型校验单个值，返回错误描述（null = 通过）
  String? _checkFieldValue(CustomFieldDef f, dynamic v) {
    switch (f.type) {
      case CustomFieldType.text:
      case CustomFieldType.longText:
      case CustomFieldType.poster:
        return v is String ? null : '必须是字符串'.tr;
      case CustomFieldType.status:
        if (v is! String) return '必须是字符串'.tr;
        if (f.options.isNotEmpty && !f.options.contains(v)) {
          return '必须是已定义的状态选项之一'.tr;
        }
        return null;
      case CustomFieldType.date:
        if (v is! String) return '必须是字符串'.tr;
        return DateTime.tryParse(v) != null ? null : '日期格式无效'.tr;
      case CustomFieldType.multiText:
      case CustomFieldType.multiImage:
        return (v is List && v.every((e) => e is String))
            ? null
            : '必须是字符串数组'.tr;
      case CustomFieldType.count:
      case CustomFieldType.duration:
        return v is int ? null : '必须是整数'.tr;
      case CustomFieldType.rating:
        return v is num ? null : '必须是数字'.tr;
      case CustomFieldType.progress:
        return (v is Map && v['current'] is int && v['total'] is int)
            ? null
            : '必须是 {"current": 整数, "total": 整数}'.tr;
      case CustomFieldType.dateRange:
        if (v is! Map) return '必须是 {"start": "日期", "end": "日期"}'.tr;
        for (final k in ['start', 'end']) {
          final d = v[k];
          if (d != null && (d is! String || DateTime.tryParse(d) == null)) {
            return '日期格式无效'.tr;
          }
        }
        return null;
    }
  }

  /// 原型编辑保存：先校验，通过后直接用 JSON 作为条目 data
  Future<void> _saveRaw() async {
    final err = _validateRawData(_rawController.text);
    if (err != null) {
      setState(() => _rawError = err);
      return;
    }
    final decoded =
        Map<String, dynamic>.from(jsonDecode(_rawController.text) as Map);
    // 清理 null/空值，保持 data_json 精简
    final data = <String, dynamic>{};
    decoded.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is List && v.isEmpty) return;
      data[k] = v;
    });

    final design = _design!;
    String title = '';
    final titleField = design.titleField;
    if (titleField != null) title = data[titleField.key]?.toString() ?? '';
    final posterField = design.firstFieldOf(CustomFieldType.poster);
    final ratingField = design.firstFieldOf(CustomFieldType.rating);
    final statusField = design.firstFieldOf(CustomFieldType.status);
    final ratingV = ratingField != null ? data[ratingField.key] : null;

    final item = CustomModuleItem(
      id: _itemId,
      moduleId: widget.module.id,
      title: title,
      coverPath: posterField != null ? data[posterField.key] as String? : null,
      rating: ratingV is num ? ratingV.toDouble() : null,
      status: statusField != null ? data[statusField.key] as String? : null,
      data: data,
      createdAt: widget.item!.createdAt,
      updatedAt: DateTime.now(),
    );
    await _itemDao.updateItem(item);
    if (!mounted) return;
    context.read<AppProvider>().bumpCustomModuleItemsVersion();
    Navigator.pop(context, true);
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
      id: _itemId,
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

/// 原型编辑用的 JSON 语法高亮控制器：
/// 键名=蓝、字符串=红、数字=绿、true/false/null=紫，颜色随明暗主题切换
class _JsonEditingController extends TextEditingController {
  ColorScheme? colors;

  static final RegExp _tokenPattern = RegExp(
    r'("(?:\\.|[^"\\])*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false|null)\b',
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final text = value.text;
    if (text.isEmpty) return TextSpan(text: text, style: base);

    final isDark = colors?.brightness == Brightness.dark;
    final keyColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final stringColor = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final numberColor = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final keywordColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF7C3AED);

    final children = <TextSpan>[];
    var pos = 0;
    for (final m in _tokenPattern.allMatches(text)) {
      if (m.start > pos) {
        children.add(TextSpan(text: text.substring(pos, m.start)));
      }
      final color = m.group(1) != null
          ? (m.group(2) != null ? keyColor : stringColor)
          : m.group(3) != null
              ? numberColor
              : keywordColor;
      children.add(TextSpan(
        text: m.group(0)!,
        style: base.copyWith(color: color),
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      children.add(TextSpan(text: text.substring(pos)));
    }
    return TextSpan(style: base, children: children);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/custom_module_field.dart';
import '../../widgets/custom_module_icon.dart';
import '../../l10n/app_strings.dart';

/// 自定义模块单个表单设计的编辑页：字段增删改排
/// （从表单设计列表页进入；返回或点右上角保存均可保存，无字段的设计不允许保存）
class CustomModuleDesignPage extends StatefulWidget {
  final String moduleId;
  final String designId;
  const CustomModuleDesignPage({super.key, required this.moduleId, required this.designId});

  @override
  State<CustomModuleDesignPage> createState() => _CustomModuleDesignPageState();
}

class _CustomModuleDesignPageState extends State<CustomModuleDesignPage> {
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();
  CustomModuleDesign? _design;
  bool _loading = true;

  /// poster/status/rating/count 每种至多一个
  static const _singletonTypes = {
    CustomFieldType.poster,
    CustomFieldType.status,
    CustomFieldType.rating,
    CustomFieldType.count,
  };

  @override
  void initState() {
    super.initState();
    _loadDesign();
  }

  Future<void> _loadDesign() async {
    try {
      final designs = await _designDao.getDesignsForModule(widget.moduleId);
      for (final d in designs) {
        if (d.id == widget.designId) {
          _design = d;
          break;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  /// 字段变更后持久化当前设计
  Future<void> _persistFields(List<CustomFieldDef> fields) async {
    final d = _design;
    if (d == null) return;
    final updated = d.copyWith(fields: fields, updatedAt: DateTime.now());
    await _designDao.updateDesign(updated);
    _design = updated;
    if (mounted) setState(() {});
  }

  /// 返回前校验：无字段的设计不允许保存，丢弃后返回（返回始终允许）
  Future<void> _discardEmptyDesignAndPop() async {
    final d = _design;
    if (d != null && d.fields.isEmpty) {
      await _designDao.deleteDesign(widget.moduleId, d.id);
    }
    if (mounted) Navigator.pop(context);
  }

  /// 右上角保存按钮：字段变更已实时落库，这里仅校验非空后退出
  void _saveAndPop() {
    final d = _design;
    if (d == null) return;
    if (d.fields.isEmpty) {
      ToastUtil.show(context, '请至少添加一个字段'.tr);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final module = context.watch<AppProvider>().getCustomModuleById(widget.moduleId);
    final design = _design;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _discardEmptyDesignAndPop();
      },
      child: Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(
          design != null
              ? (module != null ? '${module.name} · ${design.name}' : design.name)
              : '表单设计'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: colors.surface,
        actions: [
          if (design != null) ...[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '添加字段'.tr,
              onPressed: _showFieldTypePicker,
            ),
            TextButton(
              onPressed: _saveAndPop,
              child: Text('保存'.tr,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : design == null
              ? Center(
                  child: Text('设计不存在或已删除'.tr,
                      style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
                )
              : _buildFieldList(colors),
      ),
    );
  }

  // ─── 字段列表 ───

  Widget _buildFieldList(ColorScheme colors) {
    final active = _design!;
    final fields = active.fields;
    if (fields.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('还没有字段'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 6),
            Text('点击右上角 + 添加表单字段'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
          ],
        ),
      );
    }
    final rows = _groupRows(fields);
    // 每行的起始字段下标（缝隙拖放目标的插入位置用）
    final starts = <int>[];
    var acc = 0;
    for (final r in rows) {
      starts.add(acc);
      acc += r.length;
    }
    // 行间缝隙也是拖放目标：落到缝隙 = 独占一行；落到卡片上 = 半行并排
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: rows.length * 2 + 1,
      itemBuilder: (context, i) {
        if (i.isEven) {
          final g = i ~/ 2;
          return _buildGapTarget(g < starts.length ? starts[g] : fields.length, colors);
        }
        return _buildFieldRow(rows[i ~/ 2], colors);
      },
    );
  }

  /// 可半行的类型（单文本/多文本/时间/次数）；状态/评分固定整行合并卡，海报/长文本固定整行
  static bool _halfCapable(CustomFieldType t) =>
      t == CustomFieldType.text ||
      t == CustomFieldType.multiText ||
      t == CustomFieldType.date ||
      t == CustomFieldType.count;

  /// halfWidth 不由用户开关控制，完全由拖放位置决定（见 _dropOnField / _dropOnGap）
  static bool _pairable(CustomFieldDef f) => f.halfWidth && _halfCapable(f.type);

  /// 分行：开启半行的连续两个字段并排一行，其余独占一行
  List<List<CustomFieldDef>> _groupRows(List<CustomFieldDef> fields) {
    final rows = <List<CustomFieldDef>>[];
    var i = 0;
    while (i < fields.length) {
      if (_pairable(fields[i]) && i + 1 < fields.length && _pairable(fields[i + 1])) {
        rows.add([fields[i], fields[i + 1]]);
        i += 2;
      } else {
        rows.add([fields[i]]);
        i++;
      }
    }
    return rows;
  }

  /// 正在拖拽的字段（原位置半透明提示；同时用于让单个半行字段显示虚框落点）
  CustomFieldDef? _draggingField;

  /// 落到字段卡上：插入到目标前面；两者都是可半行类型时并排为一行，否则独占一行
  void _dropOnField(CustomFieldDef dragged, CustomFieldDef target) {
    if (dragged.key == target.key) return;
    final active = _design;
    if (active == null) return;
    final list = List<CustomFieldDef>.from(active.fields);
    list.removeWhere((f) => f.key == dragged.key);
    final idx = list.indexWhere((f) => f.key == target.key);
    if (idx == -1) return;
    var d = dragged;
    if (_halfCapable(d.type) && _halfCapable(target.type)) {
      d = d.copyWith(halfWidth: true);
      if (!target.halfWidth) list[idx] = target.copyWith(halfWidth: true);
    } else if (d.halfWidth) {
      d = d.copyWith(halfWidth: false);
    }
    list.insert(idx, d);
    _persistFields(list);
  }

  /// 落到行间缝隙：在该位置独占一行
  void _dropOnGap(CustomFieldDef dragged, int insertIndex) {
    final active = _design;
    if (active == null) return;
    final list = List<CustomFieldDef>.from(active.fields);
    final from = list.indexWhere((f) => f.key == dragged.key);
    if (from == -1) return;
    var idx = insertIndex;
    if (from < idx) idx--;
    if (from == idx && !dragged.halfWidth) return; // 位置没变且本来就是整行
    final d = list.removeAt(from).copyWith(halfWidth: false);
    if (idx > list.length) idx = list.length;
    list.insert(idx, d);
    _persistFields(list);
  }

  /// 拖到虚框占位上：与该半行字段并排（按落单字段的左右位置决定插前还是插后）
  void _pairWithField(CustomFieldDef dragged, CustomFieldDef target) {
    if (dragged.key == target.key) return;
    final active = _design;
    if (active == null) return;
    final list = List<CustomFieldDef>.from(active.fields);
    list.removeWhere((f) => f.key == dragged.key);
    final idx = list.indexWhere((f) => f.key == target.key);
    if (idx == -1) return;
    list.insert(target.halfOnLeft ? idx + 1 : idx, dragged.copyWith(halfWidth: true));
    _persistFields(list);
  }

  /// 半行落单字段切换左右位置（拖到自己的虚框上触发）
  void _toggleHalfSide(CustomFieldDef field) {
    final active = _design;
    if (active == null) return;
    final list = List<CustomFieldDef>.from(active.fields);
    final idx = list.indexWhere((f) => f.key == field.key);
    if (idx == -1) return;
    list[idx] = field.copyWith(halfOnLeft: !field.halfOnLeft);
    _persistFields(list);
  }

  /// 行间缝隙拖放目标：常态几乎不可见，有字段悬停时显示一条主色提示线
  Widget _buildGapTarget(int insertIndex, ColorScheme colors) {
    return DragTarget<CustomFieldDef>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => _dropOnGap(d.data, insertIndex),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Container(
          height: 12,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: hovering
              ? Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
              : null,
        );
      },
    );
  }

  /// 列表内容区宽度（左右各 16 padding）与半行卡宽度（中间 10 间距）
  double get _fullCardWidth => MediaQuery.of(context).size.width - 32;
  double get _halfCardWidth => (_fullCardWidth - 10) / 2;

  /// 一行字段（1~2 个）：与新增/编辑表单页渲染完全一致的预览卡（行间距由缝隙拖放目标提供）
  Widget _buildFieldRow(List<CustomFieldDef> row, ColorScheme colors) {
    if (row.length == 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildPreviewCard(row[0], colors, _halfCardWidth)),
          const SizedBox(width: 10),
          Expanded(child: _buildPreviewCard(row[1], colors, _halfCardWidth)),
        ],
      );
    }
    final f = row[0];
    if (_pairable(f)) {
      // 单个半行字段：卡片占半行，另半边灰色虚框占位（默认卡片靠左；拖到自己的虚框上可切换左右）
      final card = Expanded(child: _buildPreviewCard(f, colors, _halfCardWidth));
      final slot = Expanded(child: _buildHalfPlaceholder(f, colors));
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: f.halfOnLeft
              ? [card, const SizedBox(width: 10), slot]
              : [slot, const SizedBox(width: 10), card],
        ),
      );
    }
    return _buildPreviewCard(f, colors, _fullCardWidth);
  }

  /// 半行虚框占位：拖其他半行字段上来即并排；拖字段自己上来则切换左右位置
  Widget _buildHalfPlaceholder(CustomFieldDef after, ColorScheme colors) {
    return DragTarget<CustomFieldDef>(
      onWillAcceptWithDetails: (d) => d.data.key == after.key || _halfCapable(d.data.type),
      onAcceptWithDetails: (d) {
        if (d.data.key == after.key) {
          _toggleHalfSide(after);
        } else {
          _pairWithField(d.data, after);
        }
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final color = hovering ? colors.primary : colors.outlineVariant;
        return CustomPaint(
          painter: _DashedBorderPainter(
            color,
            fillColor: hovering
                ? colors.primary.withValues(alpha: 0.08)
                : colors.onSurface.withValues(alpha: 0.05),
          ),
          child: Center(
            child: Icon(Icons.add, size: 20, color: color.withValues(alpha: hovering ? 0.8 : 0.5)),
          ),
        );
      },
    );
  }

  /// 预览卡：共享组件渲染（不可交互），点击弹出 删除/编辑，长按整卡拖拽换位
  /// width 用于拖拽跟随幽灵保持与卡片同宽（不能用 LayoutBuilder：IntrinsicHeight 不支持）
  Widget _buildPreviewCard(CustomFieldDef field, ColorScheme colors, double width) {
    return DragTarget<CustomFieldDef>(
      onWillAcceptWithDetails: (d) => d.data.key != field.key,
      onAcceptWithDetails: (d) => _dropOnField(d.data, field),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return LongPressDraggable<CustomFieldDef>(
          data: field,
          onDragStarted: () {
            HapticFeedback.mediumImpact();
            setState(() => _draggingField = field);
          },
          onDragEnd: (_) => setState(() => _draggingField = null),
          onDraggableCanceled: (_, __) => setState(() => _draggingField = null),
          // 长按触发后跟随手指的卡片：放大 + 阴影，呈现「拿起来」的浮动效果
          feedback: IgnorePointer(
            child: Transform.scale(
              scale: 1.04,
              child: Material(
                elevation: 10,
                shadowColor: colors.shadow.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                child: SizedBox(
                  width: width,
                  child: _buildFieldPreview(field, colors),
                ),
              ),
            ),
          ),
          child: Stack(
            children: [
              Opacity(
                opacity: _draggingField?.key == field.key ? 0.35 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: hovering ? Border.all(color: colors.primary, width: 1.5) : null,
                  ),
                  child: IgnorePointer(child: _buildFieldPreview(field, colors)),
                ),
              ),
              // 透明手势层：必须命中测试（opaque）以覆盖卡片内全部区域，同时不遮挡预览内容
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showFieldConfigSheet(existing: field),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 不可交互的字段预览（与表单页同一套共享渲染组件）
  Widget _buildFieldPreview(CustomFieldDef f, ColorScheme colors) {
    switch (f.type) {
      case CustomFieldType.poster:
        return Center(child: customModulePosterField(f, null, colors, onPick: () {}, onRemove: () {}));
      case CustomFieldType.status:
        return customModuleCard(colors, child: customModuleStatusRow(f, null, colors, (_) {}));
      case CustomFieldType.rating:
        return customModuleCard(colors, child: customModuleRatingRow(f, null, colors, (_) {}));
      case CustomFieldType.count:
        return customModuleCountCard(f, 0, colors, (_) {}, interactive: false);
      case CustomFieldType.text:
        return customModuleTextCard(f, null, colors, multiline: false, onTap: () {});
      case CustomFieldType.longText:
        return customModuleTextCard(f, null, colors, multiline: true, onTap: () {});
      case CustomFieldType.multiText:
        return customModuleMultiTextCard(f, const [], colors, onTap: () {});
      case CustomFieldType.date:
        return customModuleDateCard(f, null, colors, onTap: () {}, onClear: () {});
    }
  }

  /// 长按删除字段（已有条目中该字段的值保留在 data 中，仅不再显示）
  void _confirmDeleteField(CustomFieldDef field) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('删除字段'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          '删除「${field.label}」字段？已录入条目中该字段的内容会被保留，但不再显示。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () {
              Navigator.pop(ctx);
              final active = _design;
              if (active == null) return;
              _persistFields(active.fields.where((f) => f.key != field.key).toList());
            },
            child: Text('删除'.tr),
          ),
        ],
      ),
    );
  }

  (String, IconData) _fieldTypeInfo(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.poster: return ('海报图'.tr, Icons.image_outlined);
      case CustomFieldType.status: return ('状态'.tr, Icons.flag_outlined);
      case CustomFieldType.rating: return ('评分'.tr, Icons.star_outline);
      case CustomFieldType.count: return ('次数'.tr, Icons.plus_one);
      case CustomFieldType.text: return ('单文本'.tr, Icons.short_text);
      case CustomFieldType.multiText: return ('多文本'.tr, Icons.format_list_bulleted);
      case CustomFieldType.date: return ('时间'.tr, Icons.calendar_today_outlined);
      case CustomFieldType.longText: return ('长文本'.tr, Icons.notes);
    }
  }

  // ─── 添加字段：类型选择 ───

  void _showFieldTypePicker() {
    final colors = Theme.of(context).colorScheme;
    final active = _design!;
    final usedSingletons = active.fields.map((f) => f.type).where(_singletonTypes.contains).toSet();

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('添加字段'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 12),
              // 窗口较矮时 8 个字段类型可能超出弹层高度，需可滚动
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in CustomFieldType.values) ...[
                        _buildTypeTile(ctx, type, usedSingletons.contains(type), colors),
                        if (type != CustomFieldType.values.last)
                          Divider(height: 0.5, indent: 44, color: colors.outlineVariant),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTile(BuildContext ctx, CustomFieldType type, bool disabled, ColorScheme colors) {
    final (label, icon) = _fieldTypeInfo(type);
    final desc = _fieldTypeDesc(type);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: !disabled,
      leading: Icon(icon, size: 22, color: disabled ? colors.onSurface.withValues(alpha: 0.25) : colors.onSurface.withValues(alpha: 0.7)),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
          color: disabled ? colors.onSurface.withValues(alpha: 0.3) : colors.onSurface)),
      subtitle: Text(disabled ? '已添加（该类型仅可添加一个）'.tr : desc,
          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: disabled ? 0.25 : 0.45))),
      onTap: () {
        Navigator.pop(ctx);
        _showFieldConfigSheet(newType: type);
      },
    );
  }

  String _fieldTypeDesc(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.poster: return '导入一张封面图'.tr;
      case CustomFieldType.status: return '自定义状态选项（如 想看/在看/看过）'.tr;
      case CustomFieldType.rating: return '星级评分'.tr;
      case CustomFieldType.count: return '次数统计（加减号控制）'.tr;
      case CustomFieldType.text: return '一行短文本（如 名称）'.tr;
      case CustomFieldType.multiText: return '多个文本条目（如 导演、编剧）'.tr;
      case CustomFieldType.date: return '选择一个日期'.tr;
      case CustomFieldType.longText: return '多行长文本（如 简介）'.tr;
    }
  }

  // ─── 字段配置（新增/编辑） ───

  void _showFieldConfigSheet({CustomFieldType? newType, CustomFieldDef? existing}) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = existing != null;
    final type = isEdit ? existing.type : newType!;
    final (typeLabel, _) = _fieldTypeInfo(type);

    final labelController = TextEditingController(text: isEdit ? existing.label : _defaultLabel(type));
    bool required = isEdit ? existing.required : false;
    bool isTitle = isEdit ? existing.isTitle : false;
    bool halfWidth = isEdit ? existing.halfWidth : false;
    String selectedIcon = isEdit ? existing.icon : '';
    List<String> options = isEdit ? List.from(existing.options) : (type == CustomFieldType.status ? ['想看', '在看', '看过'] : <String>[]);
    final optionController = TextEditingController();

    final supportsRequired = type == CustomFieldType.text || type == CustomFieldType.multiText || type == CustomFieldType.longText;
    // 半行：单文本/多文本/时间/次数 可开（也可在列表里拖到其他半行字段上并排）
    final supportsHalf = _halfCapable(type);

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
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
                Text('${isEdit ? '编辑' : '添加'}$typeLabel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController, autofocus: !isEdit, maxLength: 10,
                  style: TextStyle(fontSize: 15, color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: '字段名称'.tr,
                    labelStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5)),
                    counterStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
                if (supportsRequired)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('必填'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
                    value: required,
                    onChanged: (v) => setSheetState(() => required = v),
                  ),
                // 海报卡不渲染标签图标，无需选择
                if (type != CustomFieldType.poster) ...[
                  const SizedBox(height: 8),
                  Text('图标'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 8),
                  // FontAwesome 图标网格，上下滑动选择；再次点击已选图标恢复类型默认
                  SizedBox(
                    height: 160,
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
                              size: 16,
                              color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (type == CustomFieldType.text)
                  // 强制恰好一个标题：当前标题字段的开关锁定为开（不可关），
                  // 在其他文本字段上开启会自动顶掉它；都没有时保存逻辑兜底用第一个文本字段
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('设为标题'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
                    subtitle: Text(
                      isEdit && existing.isTitle
                          ? '列表页以此字段作为条目标题（需保留一个标题，可在其他文本字段上开启来更换）'.tr
                          : '列表页以此字段作为条目标题'.tr,
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                    ),
                    value: isTitle,
                    onChanged: isEdit && existing.isTitle ? null : (v) => setSheetState(() => isTitle = v),
                  ),
                if (supportsHalf)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('半行显示'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
                    subtitle: Text('与相邻的半行字段并排为一行'.tr,
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
                    value: halfWidth,
                    onChanged: (v) => setSheetState(() => halfWidth = v),
                  ),
                if (type == CustomFieldType.status) ...[
                  const SizedBox(height: 8),
                  Text('状态选项'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      for (final opt in options)
                        InputChip(
                          label: Text(opt, style: const TextStyle(fontSize: 13)),
                          onDeleted: () => setSheetState(() => options.remove(opt)),
                          deleteIconColor: colors.onSurface.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: optionController, maxLength: 8,
                          style: TextStyle(fontSize: 14, color: colors.onSurface),
                          decoration: InputDecoration(
                            hintText: '新选项名称'.tr, counterText: '',
                            hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addOption(options, optionController, setSheetState),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: colors.primary),
                        onPressed: () => _addOption(options, optionController, setSheetState),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // 编辑时底部两个按钮：左边删除、右边保存；新增时单个添加按钮
                if (isEdit)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteField(existing);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
                          ),
                          child: Text('删除'.tr),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _saveField(ctx, type, labelController.text, required, isTitle, halfWidth, options, selectedIcon, existing),
                          child: Text('保存'.tr),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _saveField(ctx, type, labelController.text, required, isTitle, halfWidth, options, selectedIcon, existing),
                      child: Text('添加'.tr),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addOption(List<String> options, TextEditingController controller, StateSetter setSheetState) {
    final v = controller.text.trim();
    if (v.isEmpty || options.contains(v)) return;
    setSheetState(() {
      options.add(v);
      controller.clear();
    });
  }

  String _defaultLabel(CustomFieldType type) {
    switch (type) {
      case CustomFieldType.poster: return '海报';
      case CustomFieldType.status: return '状态';
      case CustomFieldType.rating: return '评分';
      case CustomFieldType.count: return '次数';
      case CustomFieldType.text: return '名称';
      case CustomFieldType.multiText: return '';
      case CustomFieldType.date: return '时间';
      case CustomFieldType.longText: return '简介';
    }
  }

  Future<void> _saveField(BuildContext ctx, CustomFieldType type, String label, bool required,
      bool isTitle, bool halfWidth, List<String> options, String icon, CustomFieldDef? existing) async {
    label = label.trim();
    if (label.isEmpty) {
      ToastUtil.show(context, '请输入字段名称'.tr);
      return;
    }
    if (type == CustomFieldType.status && options.isEmpty) {
      ToastUtil.show(context, '请至少添加一个状态选项'.tr);
      return;
    }
    final active = _design!;
    final list = List<CustomFieldDef>.from(active.fields);

    if (existing != null) {
      final idx = list.indexWhere((f) => f.key == existing.key);
      if (idx == -1) return;
      list[idx] = existing.copyWith(label: label, required: required, isTitle: isTitle, halfWidth: halfWidth, options: options, icon: icon);
    } else {
      list.add(CustomFieldDef(
        key: 'f_${const Uuid().v4().substring(0, 8)}',
        type: type,
        label: label,
        required: required,
        isTitle: isTitle,
        halfWidth: halfWidth,
        options: options,
        icon: icon,
      ));
    }
    // 标题字段唯一：设了新标题则清掉其他文本字段的标题标记
    if (isTitle) {
      final savedKey = existing?.key ?? list.last.key;
      for (var i = 0; i < list.length; i++) {
        if (list[i].key != savedKey && list[i].isTitle) {
          list[i] = list[i].copyWith(isTitle: false);
        }
      }
    }
    // 第一个文本字段缺省作为标题（无标题字段且存在文本字段时）
    if (!list.any((f) => f.type == CustomFieldType.text && f.isTitle)) {
      final firstTextIdx = list.indexWhere((f) => f.type == CustomFieldType.text);
      if (firstTextIdx != -1) {
        list[firstTextIdx] = list[firstTextIdx].copyWith(isTitle: true);
      }
    }
    await _persistFields(list);
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

/// 虚线圆角边框（半行占位框用），内部可带填充色
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final Color fillColor;
  const _DashedBorderPainter(this.color, {this.fillColor = const Color(0x00000000)});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(0.5), const Radius.circular(12));
    if (fillColor.a > 0) {
      canvas.drawRRect(rrect, Paint()..color = fillColor);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.fillColor != fillColor;
}

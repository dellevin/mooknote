import 'package:flutter/material.dart';
import '../../models/data_models.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/app_overlay.dart';
import '../../utils/slide_up_page_route.dart';
import '../../l10n/app_strings.dart';
import 'custom_module_form_page.dart';

/// 自定义模块条目详情页：按激活设计动态渲染只读字段，数据缺失的字段不显示
class CustomModuleDetailPage extends StatefulWidget {
  final CustomModule module;
  final String itemId;

  const CustomModuleDetailPage({super.key, required this.module, required this.itemId});

  @override
  State<CustomModuleDetailPage> createState() => _CustomModuleDetailPageState();
}

class _CustomModuleDetailPageState extends State<CustomModuleDetailPage> {
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();
  final CustomModuleItemDao _itemDao = CustomModuleItemDao();

  CustomModuleItem? _item;
  CustomModuleDesign? _design;
  List<CustomModuleDesign> _designs = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _design = await _designDao.getActiveDesign(widget.module.id);
      _designs = await _designDao.getDesignsForModule(widget.module.id);
      _item = await _itemDao.getItemById(widget.itemId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final item = _item;
    return Scaffold(
      backgroundColor: colors.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : item == null
              ? Center(child: Text('条目不存在'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5))))
              : PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (!didPop) Navigator.pop(context, _changed);
                  },
                  child: _buildBody(item, colors),
                ),
    );
  }

  Future<void> _openEdit() async {
    final changed = await Navigator.push(context, SlideUpPageRoute(
      page: CustomModuleFormPage(module: widget.module, item: _item),
    ));
    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  void _confirmDelete() {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('删除条目'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定删除「${_item!.title.isEmpty ? '未命名' : _item!.title}」吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.error),
            onPressed: () async {
              await _itemDao.deleteItem(widget.itemId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ToastUtil.show(context, '已删除'.tr);
                Navigator.pop(context, true);
              }
            },
            child: Text('删除'.tr),
          ),
        ],
      ),
    );
  }

  // ─── 动态渲染（影视详情标准样式：海报横幅 + 标题评分状态头 + 无卡片字段分区）───

  Widget _buildBody(CustomModuleItem item, ColorScheme colors) {
    if (_design == null && _designs.isEmpty && item.data.isEmpty) {
      return Center(child: Text('表单设计已被删除'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5))));
    }
    // 合并所有设计的字段定义（激活设计排前，决定显示顺序）：
    // 切换使用中设计只影响录入表单，详情页要完整展示已存数据
    final knownKeys = <String>{};
    final fields = <CustomFieldDef>[];
    final active = _design;
    if (active != null) {
      for (final f in active.fields) {
        if (knownKeys.add(f.key)) fields.add(f);
      }
    }
    for (final d in _designs) {
      if (d.id == active?.id) continue;
      for (final f in d.fields) {
        if (knownKeys.add(f.key)) fields.add(f);
      }
    }
    // 海报：取所有设计的海报字段中第一个有值的
    String? posterPath;
    for (final f in fields) {
      if (f.type == CustomFieldType.poster) {
        final v = item.data[f.key] as String?;
        if (v != null && v.isNotEmpty) {
          posterPath = v;
          break;
        }
      }
    }

    final title = item.title.isNotEmpty ? item.title : widget.module.name;
    // 头部提取：第一个有值的评分/状态字段（其余评分/状态字段仍在正文显示）
    String? headerRatingKey, headerStatusKey;
    double? rating;
    String? status;
    for (final f in fields) {
      if (f.type == CustomFieldType.rating && headerRatingKey == null && _hasValue(item.data[f.key])) {
        headerRatingKey = f.key;
        rating = (item.data[f.key] as num).toDouble();
      } else if (f.type == CustomFieldType.status && headerStatusKey == null && _hasValue(item.data[f.key])) {
        headerStatusKey = f.key;
        status = item.data[f.key].toString();
      }
    }

    // 头部元信息：日期字段最多显示前两个（其余留在正文），次数字段仍在头部
    var headerDateCount = 0;
    final metaFields = <CustomFieldDef>[];
    for (final f in fields) {
      if (!_hasValue(item.data[f.key])) continue;
      if (f.type == CustomFieldType.date) {
        if (headerDateCount < 2) {
          metaFields.add(f);
          headerDateCount++;
        }
      } else if (f.type == CustomFieldType.count) {
        metaFields.add(f);
      }
    }
    final metaKeys = metaFields.map((f) => f.key).toSet();
    final bodyFields = [
      for (final f in fields)
        if (f.type != CustomFieldType.poster &&
            f.key != headerRatingKey &&
            f.key != headerStatusKey &&
            !metaKeys.contains(f.key) &&
            _hasValue(item.data[f.key]))
          f,
    ];
    // 兜底：字段定义已被删除的遗留数据，用 key 作标签显示，保证数据不丢
    final orphans = [
      for (final e in item.data.entries)
        if (!knownKeys.contains(e.key) && _hasValue(e.value)) e,
    ];

    final topSafe = MediaQuery.of(context).padding.top;
    // fit: expand 让 Stack 撑满屏幕，否则内容少时 Stack 收缩到内容高度，
    // Positioned(bottom) 的浮动按钮会跑到内容底部而不是屏幕右下角
    return Stack(
      fit: StackFit.expand,
      children: [
        // 整体可滚动（海报 + 内容一起滑动）
        Padding(
          padding: EdgeInsets.only(top: topSafe + 48),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：左小海报 + 右标题/评分状态/日期次数（紧凑布局，无海报时信息占满整行）
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (posterPath != null) ...[
                        Container(
                          width: 100, height: 140,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: FadeInLocalImage(path: posterPath, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
                            if (rating != null || status != null) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                if (rating != null) ...[
                                  Icon(Icons.star, size: 18, color: colors.onSurface),
                                  const SizedBox(width: 4),
                                  Text(rating % 1 == 0 ? rating.toInt().toString() : rating.toStringAsFixed(1),
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                                  const SizedBox(width: 10),
                                ],
                                if (status != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(6)),
                                    child: Text(status,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onPrimary)),
                                  ),
                              ]),
                            ],
                            for (final f in metaFields) ...[
                              const SizedBox(height: 6),
                              Text(_metaText(f, item.data[f.key]),
                                  style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (bodyFields.isNotEmpty || orphans.isNotEmpty)
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                // 字段分区（标签小字在上，值在下）
                for (final f in bodyFields)
                  _buildFieldSection(f.label, _fieldValue(f, item.data[f.key], colors), colors),
                for (final e in orphans)
                  _buildFieldSection(e.key, _orphanValue(e.value, colors), colors),
                // 时间信息（底部留白避让浮动按钮）
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 110),
                  child: Center(
                    child: Text(
                      '创建于 ${_formatDate(item.createdAt)} · 更新于 ${_formatDate(item.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 顶部导航栏（与影视详情一致）
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: topSafe),
            color: colors.surface,
            child: SizedBox(
              height: 48,
              child: Row(children: [
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: colors.onSurface, size: 18),
                  onPressed: () => Navigator.pop(context, _changed),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 4),
              ]),
            ),
          ),
        ),
        // 右下角浮动按钮（影视详情同款：40px 圆形按钮竖排，编辑主题色 / 删除红色）
        Positioned(
          right: 16, bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFloatingButton(
                icon: Icons.edit_outlined, tooltip: '编辑'.tr, onPressed: _openEdit,
                backgroundColor: colors.primary, foregroundColor: colors.onPrimary,
              ),
              const SizedBox(height: 12),
              _buildFloatingButton(
                icon: Icons.delete_outline, tooltip: '删除'.tr, onPressed: _confirmDelete,
                backgroundColor: colors.error, foregroundColor: colors.onError,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: backgroundColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, size: 18, color: foregroundColor),
        ),
      ),
    );
  }

  /// 头部元信息行：「标签：值」（日期 / 次数字段）
  String _metaText(CustomFieldDef f, dynamic v) {
    if (f.type == CustomFieldType.date) {
      final d = DateTime.tryParse(v.toString());
      return '${f.label}：${d != null ? _formatDate(d) : v}';
    }
    final count = '{n} 次'.trf({'n': (v as num).toInt()});
    return '${f.label}：$count';
  }

  /// 字段分区：小标签在上，值在下（无卡片，影视详情模块样式）
  Widget _buildFieldSection(String label, Widget value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: value),
        ],
      ),
    );
  }

  Widget _fieldValue(CustomFieldDef f, dynamic value, ColorScheme colors) {
    switch (f.type) {
      case CustomFieldType.poster:
        return const SizedBox.shrink();
      case CustomFieldType.status:
        return Align(alignment: Alignment.centerLeft, child: _chip(value.toString(), colors, filled: true));
      case CustomFieldType.rating:
        final r = (value as num).toDouble();
        return Row(children: [
          const Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
          const SizedBox(width: 4),
          Text(r % 1 == 0 ? r.toInt().toString() : r.toString(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]);
      case CustomFieldType.count:
        return Text('{n} 次'.trf({'n': (value as num).toInt()}),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface));
      case CustomFieldType.text:
        return Text(value.toString(),
            style: TextStyle(fontSize: 15, height: 1.5, color: colors.onSurface));
      case CustomFieldType.multiText:
        final items = parseStringListGeneric(value);
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final s in items) _chip(s, colors)]);
      case CustomFieldType.date:
        final date = DateTime.tryParse(value.toString());
        return Text(date != null ? _formatDate(date) : value.toString(),
            style: TextStyle(fontSize: 15, color: colors.onSurface));
      case CustomFieldType.longText:
        return Text(value.toString(),
            style: TextStyle(fontSize: 15, height: 1.7, color: colors.onSurface.withValues(alpha: 0.85)));
    }
  }

  Widget _orphanValue(dynamic value, ColorScheme colors) {
    if (value is List) {
      return Wrap(spacing: 8, runSpacing: 8,
          children: [for (final s in value.map((x) => x.toString())) _chip(s, colors)]);
    }
    return Text(value.toString(), style: TextStyle(fontSize: 15, height: 1.5, color: colors.onSurface));
  }

  bool _hasValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    if (v is num) return v != 0; // 评分/次数为 0 视为未填写
    return true;
  }

  Widget _chip(String text, ColorScheme colors, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? colors.primary.withValues(alpha: 0.12) : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: filled ? colors.primary : colors.onSurface.withValues(alpha: 0.7))),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/data_models.dart';
import '../l10n/app_strings.dart';
import 'custom_module_icon.dart';
import 'fade_in_local_image.dart';

/// 自定义模块字段渲染 —— 新增/编辑表单页与表单设计页共用，保证两处 UI 一致。
/// 设计页传空回调并在外层包 IgnorePointer，即为不可交互的预览模式。

/// 卡片容器
Widget customModuleCard(ColorScheme colors, {required Widget child, EdgeInsets? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.outlineVariant, width: 0.5),
    ),
    child: child,
  );
}

/// 卡片左上角：图标 + 字段名（+ 必填 *）；字段设了自定义图标则优先于类型默认图标
Widget customModuleFieldLabel(CustomFieldDef f, ColorScheme colors, {IconData? icon}) {
  final effectiveIcon = (f.icon.isNotEmpty ? customModuleIconData(f.icon) : null) ?? icon;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (effectiveIcon != null) ...[
        Icon(effectiveIcon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
      ],
      Text(f.label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
      if (f.required)
        Text(' *', style: TextStyle(fontSize: 12, color: colors.error)),
    ],
  );
}

/// 海报（表单顶部居中）：120x170 占位/封面 + 移除按钮
Widget customModulePosterField(CustomFieldDef f, String? path, ColorScheme colors,
    {required VoidCallback onPick, required VoidCallback onRemove}) {
  final hasPoster = path != null && path.isNotEmpty;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: onPick,
        child: Container(
          width: 120, height: 170,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: hasPoster
              ? FadeInLocalImage(path: path, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 28, color: colors.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 6),
                    Text(f.label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                ),
        ),
      ),
      if (hasPoster)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 14, color: colors.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text('移除'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

/// 状态行（合并卡内一行：标签在左，选项 chips 在右）
Widget customModuleStatusRow(CustomFieldDef f, String? selected, ColorScheme colors,
    ValueChanged<String?> onChanged) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: customModuleFieldLabel(f, colors, icon: Icons.flag_outlined),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Wrap(
          spacing: 8, runSpacing: 8,
          children: f.options.map((opt) {
            final isSelected = selected == opt;
            return GestureDetector(
              onTap: () => onChanged(isSelected ? null : opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}

/// 评分行（合并卡内一行：星星 + 可手动输入 0-10 的输入框，与影视表单一致）
Widget customModuleRatingRow(CustomFieldDef f, double? rating, ColorScheme colors,
    ValueChanged<double?> onChanged) {
  final r = rating ?? 0;
  final starRating = r / 2;
  return Row(
    children: [
      customModuleFieldLabel(f, colors, icon: Icons.star_outline),
      const SizedBox(width: 12),
      ...List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = starValue <= starRating;
        final isHalf = starValue == starRating.ceil() && starRating % 1 != 0;
        return GestureDetector(
          // 点左右半边分别给半星/整星（豆瓣式）：左半 = N-0.5 星，右半 = N 星
          onTapDown: (d) {
            final half = d.localPosition.dx < 14; // 星 24 + 左右各 2 padding
            final newRating = (starValue * 2 - (half ? 1 : 0)).toDouble();
            onChanged(r == newRating ? null : newRating);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              isHalf ? Icons.star_half : (isFilled ? Icons.star : Icons.star_border),
              size: 24,
              color: (isFilled || isHalf) ? const Color(0xFFFFB800) : colors.outline,
            ),
          ),
        );
      }),
      const SizedBox(width: 8),
      _RatingManualInput(value: rating, onChanged: onChanged),
      if (r > 0) ...[
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onChanged(null),
          child: Icon(Icons.close, size: 15, color: colors.onSurface.withValues(alpha: 0.3)),
        ),
      ],
    ],
  );
}

/// 评分手动输入框（0-10，最多 1 位小数）：内部持有 controller，
/// 外部值变化（点星/清除）时同步，正在输入时不打扰
class _RatingManualInput extends StatefulWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  const _RatingManualInput({required this.value, required this.onChanged});

  @override
  State<_RatingManualInput> createState() => _RatingManualInputState();
}

class _RatingManualInputState extends State<_RatingManualInput> {
  late final TextEditingController _controller;

  static String _fmt(double? v) =>
      v == null ? '' : (v % 1 == 0 ? v.toInt().toString() : v.toString());

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(covariant _RatingManualInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当前文本解析值与外部值相等说明是用户在输入（含 "7." 中间态），不重置
    if (double.tryParse(_controller.text) != widget.value) {
      _controller.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48, height: 28,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        inputFormatters: [_RatingInputFormatter()],
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: '0-10',
          hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          isDense: true,
        ),
        onChanged: (text) => widget.onChanged(double.tryParse(text)),
      ),
    );
  }
}

/// 评分输入格式化器：只允许 0-10，最多1位小数
class _RatingInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d{0,2}\.?\d{0,1}$').hasMatch(text)) return oldValue;
    final n = double.tryParse(text);
    if (n != null && n > 10) return oldValue;
    return newValue;
  }
}

/// 次数卡（与影视表单 观看次数 卡一致：标签在上，− N 次 + 步进器在下，可半行）
/// interactive=false 用于设计页预览：加减号全部置灰
Widget customModuleCountCard(CustomFieldDef f, int count, ColorScheme colors,
    ValueChanged<int> onChanged, {bool interactive = true}) {
  return customModuleCard(
    colors,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        customModuleFieldLabel(f, colors, icon: Icons.repeat_outlined),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _stepButton(colors, icon: Icons.remove,
                onTap: interactive && count > 0 ? () => onChanged(count - 1) : null),
            Text('{n} 次'.trf({'n': count}),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
            _stepButton(colors, icon: Icons.add,
                onTap: interactive ? () => onChanged(count + 1) : null),
          ],
        ),
      ],
    ),
  );
}

Widget _stepButton(ColorScheme colors, {required IconData icon, VoidCallback? onTap}) {
  final enabled = onTap != null;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: enabled ? colors.primary.withValues(alpha: 0.1) : colors.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: enabled ? colors.primary : colors.onSurface.withValues(alpha: 0.25)),
    ),
  );
}

/// 单文本 / 长文本卡（与影视表单 名称/剧情简介 卡一致：标签在上，值在下，点卡片底部弹层编辑）
Widget customModuleTextCard(CustomFieldDef f, String? value, ColorScheme colors,
    {required bool multiline, required VoidCallback onTap}) {
  final v = value ?? '';
  final hasValue = v.isNotEmpty;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      // 撑满父级宽度：设计页预览（Stack 松散约束）下避免塌成内容宽度
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            customModuleFieldLabel(f, colors, icon: multiline ? Icons.notes : Icons.short_text),
            const SizedBox(height: 8),
            if (multiline)
              // 长文本卡固定占 5 行高度（15 字号 × 1.5 行高 × 5），空值/短内容也撑满
              Container(
                constraints: const BoxConstraints(minHeight: 15 * 1.5 * 5),
                alignment: Alignment.topLeft,
                child: Text(
                  hasValue ? v : '点击填写'.tr,
                  style: TextStyle(
                    fontSize: 15,
                    color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
                    fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                    height: 1.5,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                hasValue ? v : '点击填写'.tr,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    ),
  );
}

/// 多文本卡（与影视表单 导演/编剧 卡一致：标签在上，值「N个：A、B、C」在下，点卡片弹层编辑）
Widget customModuleMultiTextCard(CustomFieldDef f, List<String> items, ColorScheme colors,
    {required VoidCallback onTap}) {
  final hasValue = items.isNotEmpty;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      // 强制撑满父级宽度：卡内子组件都按内容收缩，
      // 在设计页预览（Stack 松散约束）下会塌成内容宽度
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            customModuleFieldLabel(f, colors, icon: Icons.format_list_bulleted),
            const SizedBox(height: 8),
            Text(
              hasValue
                  ? '{n}个：{x}'.trf({'n': items.length, 'x': items.join('、')})
                  : '点击填写'.tr,
              style: TextStyle(
                fontSize: 15,
                color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

/// 格式化时长（分钟）：120 -> "2小时0分"，0 -> ""
String formatCustomModuleDuration(int minutes) {
  if (minutes <= 0) return '';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0 && m > 0) return '{h}小时{m}分'.trf({'h': h, 'm': m});
  if (h > 0) return '{h}小时'.trf({'h': h});
  return '{m}分'.trf({'m': m});
}

/// 时长卡（与时间卡一致：标签行在上、时长值在下，点卡片弹出时:分滚轮，可半行）
Widget customModuleDurationCard(CustomFieldDef f, int? minutes, ColorScheme colors,
    {required VoidCallback onTap, required VoidCallback onClear}) {
  final hasValue = minutes != null && minutes > 0;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              customModuleFieldLabel(f, colors, icon: Icons.schedule_outlined),
              if (hasValue) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasValue ? formatCustomModuleDuration(minutes) : '点击填写'.tr,
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

/// 进度值解析：{'current': c, 'total': t}，缺失/异常返回 null
(int, int)? parseCustomModuleProgress(dynamic v) {
  if (v is! Map) return null;
  final c = v['current'], t = v['total'];
  final current = c is num ? c.toInt() : int.tryParse(c?.toString() ?? '');
  final total = t is num ? t.toInt() : int.tryParse(t?.toString() ?? '');
  if (current == null && total == null) return null;
  return (current ?? 0, total ?? 0);
}

/// 进度卡（标签行在上，进度条 + 「12/24」在下，点卡片弹层编辑，可半行）
Widget customModuleProgressCard(CustomFieldDef f, dynamic value, ColorScheme colors,
    {required VoidCallback onTap, required VoidCallback onClear}) {
  final progress = parseCustomModuleProgress(value);
  final hasValue = progress != null && (progress.$1 > 0 || progress.$2 > 0);
  final (current, total) = progress ?? (0, 0);
  final ratio = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              customModuleFieldLabel(f, colors, icon: Icons.timelapse),
              if (hasValue) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasValue ? '$current/$total' : '点击填写'.tr,
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 日期区间值解析：{'start': iso?, 'end': iso?}
(String?, String?) parseCustomModuleDateRange(dynamic v) {
  if (v is! Map) return (null, null);
  final s = v['start']?.toString(), e = v['end']?.toString();
  return ((s == null || s.isEmpty) ? null : s, (e == null || e.isEmpty) ? null : e);
}

/// 日期区间显示：「2026.01.03 ~ 2026.02.15」，允许单边
String formatCustomModuleDateRange(dynamic v) {
  final (s, e) = parseCustomModuleDateRange(v);
  String fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null
        ? iso
        : '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
  if (s == null && e == null) return '';
  if (s != null && e != null) return '${fmt(s)} ~ ${fmt(e)}';
  return s != null ? '${fmt(s)} ~' : '~ ${fmt(e!)}';
}

/// 日期区间卡（与时间卡一致：标签行在上、区间值在下，点卡片弹层编辑，可半行）
Widget customModuleDateRangeCard(CustomFieldDef f, dynamic value, ColorScheme colors,
    {required VoidCallback onTap, required VoidCallback onClear}) {
  final text = formatCustomModuleDateRange(value);
  final hasValue = text.isNotEmpty;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              customModuleFieldLabel(f, colors, icon: Icons.date_range_outlined),
              if (hasValue) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasValue ? text : '点击填写'.tr,
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

/// 多图卡（标签行在上，横向缩略图 + 末尾添加块在下，固定整行）
/// 缩略图点按预览、右上角 × 移除；设计页预览传空回调即为不可交互
Widget customModuleMultiImageCard(CustomFieldDef f, List<String> paths, ColorScheme colors,
    {required VoidCallback onAdd,
    required void Function(int index) onTapImage,
    required void Function(int index) onRemoveImage}) {
  return customModuleCard(
    colors,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            customModuleFieldLabel(f, colors, icon: Icons.photo_library_outlined),
            if (paths.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('{n}张'.trf({'n': paths.length}),
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, i) {
              if (i == paths.length) {
                // 末尾添加块
                return GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.add, size: 22, color: colors.onSurface.withValues(alpha: 0.35)),
                  ),
                );
              }
              return Stack(children: [
                GestureDetector(
                  onTap: () => onTapImage(i),
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.outlineVariant, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FadeInLocalImage(path: paths[i], width: 64, height: 64, fit: BoxFit.cover),
                  ),
                ),
                Positioned(top: -4, right: -4,
                  child: GestureDetector(
                    onTap: () => onRemoveImage(i),
                    child: Container(width: 16, height: 16,
                      decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.6), shape: BoxShape.circle),
                      child: Icon(Icons.close, size: 11, color: colors.surface)),
                  ),
                ),
              ]);
            },
          ),
        ),
      ],
    ),
  );
}

/// 时间卡（与影视表单 上映/观看日期 卡一致：标签行在上、日期值在下，点卡片任意处选择）
Widget customModuleDateCard(CustomFieldDef f, String? iso, ColorScheme colors,
    {required VoidCallback onTap, required VoidCallback onClear}) {
  final date = iso != null ? DateTime.tryParse(iso) : null;
  final hasValue = date != null;
  return GestureDetector(
    onTap: onTap,
    child: customModuleCard(
      colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              customModuleFieldLabel(f, colors, icon: Icons.calendar_today_outlined),
              if (hasValue) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasValue
                ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                : '点击填写'.tr,
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

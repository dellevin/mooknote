import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/app_overlay.dart';
import '../l10n/app_strings.dart';

/// 时长选择器底部弹窗
/// - 默认「时:分」两列（影视时长）
/// - [showDays] 为 true 时为「天 / 时 / 分」三列（阅读时长）
/// 返回总分钟数，取消返回 null
class DurationPicker {
  /// 显示时长选择器
  /// [initialMinutes] 初始总分钟数
  static Future<int?> show({
    required BuildContext context,
    int initialMinutes = 0,
    String title = '影视总时长',
    bool showDays = false,
  }) {
    return appModalBottomSheet<int>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _DurationPickerSheet(
        initialMinutes: initialMinutes,
        title: title,
        showDays: showDays,
      ),
    );
  }
}

class _DurationPickerSheet extends StatefulWidget {
  final int initialMinutes;
  final String title;
  final bool showDays;

  const _DurationPickerSheet({
    required this.initialMinutes,
    required this.title,
    required this.showDays,
  });

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _days;
  late int _hours;
  late int _minutes;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  static const _maxDays = 100; // 0-99
  static const _maxHours = 100; // 0-99

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMinutes;
    if (widget.showDays) {
      _days = initial ~/ 1440;
      _hours = (initial % 1440) ~/ 60;
    } else {
      _days = 0;
      _hours = initial ~/ 60;
    }
    _minutes = initial % 60;
    _dayCtrl = FixedExtentScrollController(initialItem: _days);
    _hourCtrl = FixedExtentScrollController(initialItem: _hours);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  int get _totalMinutes => _days * 1440 + _hours * 60 + _minutes;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 标题 + 操作按钮
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('取消'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
                ),
                Expanded(
                  child: Center(
                    child: Text(widget.title.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _totalMinutes),
                  child: Text('确定'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 时长显示
            Text(
              _formatDisplay(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            // 滚轮
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  if (widget.showDays) ...[
                    // 天
                    Expanded(
                      child: _buildWheel(
                        controller: _dayCtrl,
                        itemCount: _maxDays,
                        suffix: '天',
                        onChanged: (i) => setState(() => _days = i),
                      ),
                    ),
                  ],
                  // 小时
                  Expanded(
                    child: _buildWheel(
                      controller: _hourCtrl,
                      itemCount: _maxHours,
                      suffix: '时',
                      onChanged: (i) => setState(() => _hours = i),
                    ),
                  ),
                  // 分隔：两列时用冒号，三列时各列自带文字后缀，无需分隔符
                  if (!widget.showDays)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
                    ),
                  // 分钟
                  Expanded(
                    child: _buildWheel(
                      controller: _minuteCtrl,
                      itemCount: 60,
                      suffix: '分',
                      onChanged: (i) => setState(() => _minutes = i),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 36,
      onSelectedItemChanged: onChanged,
      children: List.generate(itemCount, (i) {
        return Center(
          child: Text(
            '{n} {suffix}'.trf({'n': i, 'suffix': suffix.tr}),
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface,
            ),
          ),
        );
      }),
    );
  }

  String _formatDisplay() {
    if (_totalMinutes == 0) return '未设置'.tr;
    final parts = <String>[];
    if (_days > 0) parts.add('{n} 天'.trf({'n': _days}));
    if (_hours > 0) parts.add('{n} 小时'.trf({'n': _hours}));
    if (_minutes > 0) parts.add('{n} 分'.trf({'n': _minutes}));
    return parts.join(' ');
  }
}

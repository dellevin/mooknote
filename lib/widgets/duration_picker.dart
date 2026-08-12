import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../widgets/app_overlay.dart';

/// 时长选择器（时:分两个滚轮的底部弹窗）
/// 返回总分钟数，取消返回 null
class DurationPicker {
  /// 显示时长选择器
  /// [initialMinutes] 初始总分钟数
  static Future<int?> show({
    required BuildContext context,
    int initialMinutes = 0,
    String title = '影视总时长',
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
      ),
    );
  }
}

class _DurationPickerSheet extends StatefulWidget {
  final int initialMinutes;
  final String title;

  const _DurationPickerSheet({
    required this.initialMinutes,
    required this.title,
  });

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  late int _hours;
  late int _minutes;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  static const _maxHours = 100; // 0-99

  @override
  void initState() {
    super.initState();
    _hours = widget.initialMinutes ~/ 60;
    _minutes = widget.initialMinutes % 60;
    _hourCtrl = FixedExtentScrollController(initialItem: _hours);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

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
                  child: Text('取消', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
                ),
                Expanded(
                  child: Center(
                    child: Text(widget.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _hours * 60 + _minutes),
                  child: Text('确定', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
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
                  // 小时
                  Expanded(
                    child: _buildWheel(
                      controller: _hourCtrl,
                      itemCount: _maxHours,
                      suffix: '时',
                      onChanged: (i) => setState(() => _hours = i),
                    ),
                  ),
                  // 分隔
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
            '$i $suffix',
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
    if (_hours == 0 && _minutes == 0) return '未设置';
    final parts = <String>[];
    if (_hours > 0) parts.add('$_hours 小时');
    if (_minutes > 0) parts.add('$_minutes 分');
    return parts.join(' ');
  }
}

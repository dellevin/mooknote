import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'app_overlay.dart';

/// 弹层外壳：键盘避让 + 80% 高度
Widget _sheetShell(BuildContext ctx, Widget child) {
  final keyboard = MediaQuery.of(ctx).viewInsets.bottom;
  return Padding(
    padding: EdgeInsets.only(bottom: keyboard),
    child: SizedBox(
      height: (MediaQuery.of(ctx).size.height - keyboard) * 0.8,
      child: child,
    ),
  );
}

/// 统一的 80% 高度底部编辑弹层：键盘避让 + 拖拽条 + 标题行 + 内容区
Future<T?> showEditSheet<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext ctx) contentBuilder,
  Widget Function(BuildContext ctx)? actionBuilder,
}) {
  return appModalBottomSheet<T>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return _sheetShell(
        ctx,
        Column(
          children: [
            // 拖拽条
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题行（右侧可选操作按钮）
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)),
                  ),
                  if (actionBuilder != null) actionBuilder(ctx),
                ],
              ),
            ),
            Expanded(child: contentBuilder(ctx)),
          ],
        ),
      );
    },
  );
}

/// 弹层标题行右侧的「完成/确定」按钮
Widget editSheetDoneButton(BuildContext ctx, String label, VoidCallback onPressed) {
  return TextButton(
    onPressed: onPressed,
    child: Text(label,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(ctx).colorScheme.primary)),
  );
}

/// 日期选择底部弹层（80% 高，内嵌日历，右上角确定返回所选日期）
Future<DateTime?> showDatePickerSheet({
  required BuildContext context,
  required String title,
  DateTime? initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? DateTime(1900);
  final last = lastDate ?? DateTime.now().add(const Duration(days: 365 * 5));
  var selected = initial ?? DateTime.now();
  if (selected.isBefore(first)) selected = first;
  if (selected.isAfter(last)) selected = last;
  return showEditSheet<DateTime>(
    context: context,
    title: title,
    actionBuilder: (ctx) =>
        editSheetDoneButton(ctx, '确定'.tr, () => Navigator.pop(ctx, selected)),
    contentBuilder: (ctx) => CalendarDatePicker(
      initialDate: selected,
      firstDate: first,
      lastDate: last,
      onDateChanged: (d) => selected = d,
    ),
  );
}

/// 文本编辑底部弹层（单行/多行输入），控制器随弹层生命周期创建与销毁
class TextEditSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String initialText;
  final String? hintText;

  /// 标题下方的说明文字（如添加网络图片）
  final String? description;
  final bool multiline;
  final TextInputType? keyboardType;

  const TextEditSheet({
    super.key,
    required this.title,
    this.actionLabel = '',
    this.initialText = '',
    this.hintText,
    this.description,
    this.multiline = false,
    this.keyboardType,
  });

  /// 以 80% 高度底部弹层显示，确认时返回输入文本，取消返回 null
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String actionLabel = '',
    String initialText = '',
    String? hintText,
    String? description,
    bool multiline = false,
    TextInputType? keyboardType,
  }) {
    return appModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _sheetShell(
        ctx,
        TextEditSheet(
          title: title,
          actionLabel: actionLabel,
          initialText: initialText,
          hintText: hintText,
          description: description,
          multiline: multiline,
          keyboardType: keyboardType,
        ),
      ),
    );
  }

  @override
  State<TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<TextEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decoration = InputDecoration(
      hintText: widget.hintText,
      hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      contentPadding: widget.multiline
          ? const EdgeInsets.all(14)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1)),
    );
    return Column(
      children: [
        // 拖拽条
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // 标题 + 操作按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _controller.text.trim()),
                child: Text(
                    widget.actionLabel.isEmpty ? '完成'.tr : widget.actionLabel,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.primary)),
              ),
            ],
          ),
        ),
        // 内容
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.description != null) ...[
                  Text(widget.description!,
                      style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 12),
                ],
                if (widget.multiline)
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                          fontSize: 15, color: colors.onSurface, height: 1.6),
                      decoration: decoration,
                    ),
                  )
                else
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: widget.keyboardType,
                    style: TextStyle(fontSize: 15, color: colors.onSurface),
                    decoration: decoration,
                    onSubmitted: (v) => Navigator.pop(context, v.trim()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

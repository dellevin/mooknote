import 'package:flutter/material.dart';

/// 右侧滑入文本输入弹窗（单行编辑用，如影视名称、书籍名称）
class TextInputPanel extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hint;
  final TextInputType keyboardType;

  const TextInputPanel({
    super.key,
    required this.title,
    this.initialValue = '',
    this.hint = '',
    this.keyboardType = TextInputType.text,
  });

  static Future<String?> show({
    required BuildContext context,
    required String title,
    String initialValue = '',
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
  }) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'text-input-panel',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextInputPanel(
              title: title,
              initialValue: initialValue,
              hint: hint,
              keyboardType: keyboardType,
            ),
          ),
        );
      },
    );
  }

  @override
  State<TextInputPanel> createState() => _TextInputPanelState();
}

class _TextInputPanelState extends State<TextInputPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screenWidth * 0.75,
        height: double.infinity,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const Spacer(),
                  TextButton(
                    onPressed: _submit,
                    child: Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
                  ),
                ],
              ),
            ),
            // 输入框
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: widget.keyboardType,
                style: TextStyle(fontSize: 15, color: colors.onSurface),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
                          onPressed: () => _controller.clear(),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

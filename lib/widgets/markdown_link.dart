import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../utils/markdown_utils.dart';
import 'app_overlay.dart';

class MarkdownLinkText extends StatelessWidget {
  final String data;
  final TextStyle style;
  final Color? linkColor;

  const MarkdownLinkText({
    super.key,
    required this.data,
    required this.style,
    this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = linkColor ?? Theme.of(context).colorScheme.primary;
    return MarkdownBody(
      data: data,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet(
        p: style,
        pPadding: EdgeInsets.zero,
        a: style.copyWith(
          color: color,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
        blockSpacing: 8,
        listBullet: style,
      ),
      onTapLink: (_, href, __) => openMarkdownLink(href),
    );
  }
}

class MarkdownLinkButton extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onInserted;

  const MarkdownLinkButton({
    super.key,
    required this.controller,
    this.onInserted,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '插入链接'.tr,
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.insert_link, size: 20),
      onPressed: () async {
        await showMarkdownLinkDialog(context, controller);
        onInserted?.call();
      },
    );
  }
}

Future<void> openMarkdownLink(String? href) async {
  if (href == null || href.trim().isEmpty) return;
  final uri = Uri.tryParse(normalizeMarkdownLinkUrl(href));
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> showMarkdownLinkDialog(
  BuildContext context,
  TextEditingController controller,
) async {
  final value = controller.value;
  final selection = value.selection;
  var selectedText = '';
  if (selection.isValid && !selection.isCollapsed) {
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    selectedText = value.text.substring(
      start < end ? start : end,
      start < end ? end : start,
    );
  }

  final result = await appDialog<_MarkdownLinkData>(
    context: context,
    builder: (_) => _MarkdownLinkDialog(initialLabel: selectedText),
  );
  if (result == null) return;
  controller.value = insertMarkdownLink(
    controller.value,
    label: result.label,
    url: result.url,
  );
}

class _MarkdownLinkData {
  final String label;
  final String url;

  const _MarkdownLinkData(this.label, this.url);
}

class _MarkdownLinkDialog extends StatefulWidget {
  final String initialLabel;

  const _MarkdownLinkDialog({required this.initialLabel});

  @override
  State<_MarkdownLinkDialog> createState() => _MarkdownLinkDialogState();
}

class _MarkdownLinkDialogState extends State<_MarkdownLinkDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel);
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _urlError = '请输入链接地址'.tr);
      return;
    }
    Navigator.pop(
      context,
      _MarkdownLinkData(_labelController.text.trim(), url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text('插入链接'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelController,
            autofocus: widget.initialLabel.isEmpty,
            decoration: InputDecoration(labelText: '链接文字'.tr),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            autofocus: widget.initialLabel.isNotEmpty,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: '链接地址'.tr,
              hintText: 'https://example.com',
              errorText: _urlError,
            ),
            onChanged: (_) {
              if (_urlError != null) setState(() => _urlError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'.tr),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('插入'.tr),
        ),
      ],
    );
  }
}

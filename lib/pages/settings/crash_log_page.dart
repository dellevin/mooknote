import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_strings.dart';
import '../../services/log_service.dart';
import '../../utils/toast_util.dart';

/// 崩溃/异常日志页（调试模式）：只显示带堆栈的错误，与普通运行日志分开
class CrashLogPage extends StatefulWidget {
  const CrashLogPage({super.key});

  @override
  State<CrashLogPage> createState() => _CrashLogPageState();
}

class _CrashLogPageState extends State<CrashLogPage> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 新的在前
    final errors = LogService.instance.errors.reversed.toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('崩溃日志'.tr),
        actions: [
          if (errors.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: '清空'.tr,
              onPressed: () {
                LogService.instance.clearErrors();
                setState(() {});
              },
            ),
        ],
      ),
      body: errors.isEmpty
          ? Center(
              child: Text('暂无崩溃记录'.tr,
                  style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.4))),
            )
          : ListView.separated(
              itemCount: errors.length,
              separatorBuilder: (_, __) => Divider(
                  height: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant),
              itemBuilder: (context, i) {
                final e = errors[i];
                final t = e.time;
                final timeStr =
                    '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                final firstLine = e.message.split('\n').first;
                return ExpansionTile(
                  dense: true,
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  leading: Icon(Icons.error_outline,
                      size: 18, color: colors.error),
                  title: Text(firstLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.error)),
                  subtitle: Text(timeStr,
                      style: TextStyle(
                          fontSize: 10,
                          color:
                              colors.onSurface.withValues(alpha: 0.4))),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        e.message,
                        style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            fontFamily: 'monospace',
                            color:
                                colors.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: e.format()));
                          ToastUtil.show(context, '已复制'.tr);
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: Text('复制'.tr,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

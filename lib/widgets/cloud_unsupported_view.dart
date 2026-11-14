import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

/// 云模式一期占位视图。
///
/// 统计 / 日历 / 碎阅 / 已阅 / 漫步 / 相遇 / 片单等聚合功能依赖本地全量影视库，
/// 云端纯实时模式下数据不在本地，暂未接通，统一展示该提示。
class CloudUnsupportedView extends StatelessWidget {
  /// 传 null 时不渲染 AppBar（用于自带顶部栏的页面）
  final String? title;

  const CloudUnsupportedView({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final body = Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded,
            size: 56, color: colors.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        Text(
          '云端数据模式下暂不支持该功能'.tr,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            '云端影视数据的聚合统计将在后续版本支持'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.6, color: colors.onSurface.withValues(alpha: 0.35)),
          ),
        ),
      ]),
    );

    if (title == null) {
      return Scaffold(backgroundColor: colors.surface, body: SafeArea(child: body));
    }
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(title!.tr)),
      body: body,
    );
  }
}

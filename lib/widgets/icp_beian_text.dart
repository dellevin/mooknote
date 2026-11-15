import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ICP/App 备案号：点击跳转工信部备案管理系统
class IcpBeianText extends StatelessWidget {
  const IcpBeianText({super.key});

  static const String beianNumber = '冀ICP备2025122609号-2A';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            await launchUrl(Uri.parse('https://beian.miit.gov.cn'),
                mode: LaunchMode.externalApplication);
          } catch (_) {}
        },
        child: Text(
          beianNumber,
          style: TextStyle(
            fontSize: 11,
            color: colors.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

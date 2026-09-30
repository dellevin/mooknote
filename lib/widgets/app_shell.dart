import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';
import 'custom_title_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isDesktop) return child;
    return Column(
      children: [
        const CustomTitleBar(),
        Expanded(child: child),
      ],
    );
  }
}

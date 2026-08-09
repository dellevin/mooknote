import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'status_bar_shell.dart';

/// 观影状态选择栏
class MovieStatusBar extends StatelessWidget {
  const MovieStatusBar({super.key});

  static const _tabs = [
    StatusBarTab(label: '已看', icon: Icons.check_circle_outline),
    StatusBarTab(label: '在看', icon: Icons.play_circle_outline),
    StatusBarTab(label: '想看', icon: Icons.bookmark_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return StatusBarShell(
          tabs: _tabs,
          currentIndex: provider.movieStatusIndex,
          onChanged: provider.setMovieStatusIndex,
          style: provider.movieStatusBarStyle,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'status_bar_shell.dart';

/// 游戏状态选择栏
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({super.key});

  static const _tabs = [
    StatusBarTab(label: '已通关', icon: Icons.emoji_events_outlined),
    StatusBarTab(label: '在玩', icon: Icons.sports_esports_outlined),
    StatusBarTab(label: '想玩', icon: Icons.bookmark_outlined),
    StatusBarTab(label: '弃游', icon: Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return StatusBarShell(
          tabs: _tabs,
          currentIndex: provider.gameStatusIndex,
          onChanged: provider.setGameStatusIndex,
          style: provider.gameStatusBarStyle,
        );
      },
    );
  }
}

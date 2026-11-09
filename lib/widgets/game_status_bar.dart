import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/status_labels.dart';
import 'status_bar_shell.dart';

/// 游戏状态选择栏
class GameStatusBar extends StatelessWidget {
  const GameStatusBar({super.key});

  static const _icons = [
    Icons.emoji_events_outlined,
    Icons.sports_esports_outlined,
    Icons.bookmark_outlined,
    Icons.cancel_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final keys = StatusLabels.orderedKeys('game');
        return StatusBarShell(
          tabs: [
            for (int i = 0; i < keys.length; i++)
              StatusBarTab(
                  label: StatusLabels.label('game', keys[i]), icon: _icons[i]),
          ],
          currentIndex: provider.gameStatusIndex,
          onChanged: provider.setGameStatusIndex,
          style: provider.gameStatusBarStyle,
        );
      },
    );
  }
}

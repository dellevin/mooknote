import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/status_labels.dart';
import 'status_bar_shell.dart';

/// 观影状态选择栏
class MovieStatusBar extends StatelessWidget {
  const MovieStatusBar({super.key});

  static const _icons = [
    Icons.check_circle_outline,
    Icons.play_circle_outline,
    Icons.bookmark_outline,
    Icons.cancel_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final keys = StatusLabels.orderedKeys('movie');
        return StatusBarShell(
          tabs: [
            for (int i = 0; i < keys.length; i++)
              StatusBarTab(
                  label: StatusLabels.label('movie', keys[i]), icon: _icons[i]),
          ],
          currentIndex: provider.movieStatusIndex,
          onChanged: provider.setMovieStatusIndex,
          style: provider.movieStatusBarStyle,
        );
      },
    );
  }
}

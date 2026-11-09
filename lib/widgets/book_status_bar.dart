import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/status_labels.dart';
import 'status_bar_shell.dart';

/// 阅读状态选择栏
class BookStatusBar extends StatelessWidget {
  const BookStatusBar({super.key});

  static const _icons = [
    Icons.check_circle_outline,
    Icons.menu_book_outlined,
    Icons.bookmark_outlined,
    Icons.cancel_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final keys = StatusLabels.orderedKeys('book');
        return StatusBarShell(
          tabs: [
            for (int i = 0; i < keys.length; i++)
              StatusBarTab(
                  label: StatusLabels.label('book', keys[i]), icon: _icons[i]),
          ],
          currentIndex: provider.bookStatusIndex,
          onChanged: provider.setBookStatusIndex,
          style: provider.bookStatusBarStyle,
        );
      },
    );
  }
}

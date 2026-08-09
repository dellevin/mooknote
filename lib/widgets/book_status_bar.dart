import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'status_bar_shell.dart';

/// 阅读状态选择栏
class BookStatusBar extends StatelessWidget {
  const BookStatusBar({super.key});

  static const _tabs = [
    StatusBarTab(label: '已读', icon: Icons.check_circle_outline),
    StatusBarTab(label: '在读', icon: Icons.menu_book_outlined),
    StatusBarTab(label: '想读', icon: Icons.bookmark_outlined),
    StatusBarTab(label: '弃读', icon: Icons.cancel_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return StatusBarShell(
          tabs: _tabs,
          currentIndex: provider.bookStatusIndex,
          onChanged: provider.setBookStatusIndex,
          style: provider.bookStatusBarStyle,
        );
      },
    );
  }
}

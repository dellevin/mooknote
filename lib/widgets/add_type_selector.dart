import 'package:flutter/material.dart';
import '../utils/user_prefs.dart';

/// 添加类型选择弹窗
Future<void> showAddTypeDialog(BuildContext context) async {
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => const _AddTypeDialog(),
  );
  if (result != null && context.mounted) {
    // 由调用方处理 startAddingType
  }
  return;
}

/// 返回选中的类型索引 (0=影视, 1=阅读, 2=笔记, 3=游戏)，取消返回 null
Future<int?> showAddTypeSelector(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => const _AddTypeDialog(),
  );
}

class _AddTypeDialog extends StatelessWidget {
  const _AddTypeDialog();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showMovie = UserPrefs().showMovieTab;
    final showBook = UserPrefs().showBookTab;
    final showNote = UserPrefs().showNoteTab;
    final showGame = UserPrefs().showGameTab;

    final types = <_AddTypeItem>[];
    if (showMovie) types.add(_AddTypeItem('影视', Icons.movie_outlined, 0));
    if (showBook) types.add(_AddTypeItem('阅读', Icons.menu_book_outlined, 1));
    if (showNote) types.add(_AddTypeItem('笔记', Icons.note_outlined, 2));
    if (showGame) types.add(_AddTypeItem('游戏', Icons.sports_esports_outlined, 3));

    return Dialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择添加类型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: types.map((t) => _buildTypeCard(context, t, colors)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, _AddTypeItem item, ColorScheme colors) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, item.typeIndex),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 24, color: colors.primary),
            ),
            const SizedBox(height: 10),
            Text(item.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _AddTypeItem {
  final String label;
  final IconData icon;
  final int typeIndex;
  _AddTypeItem(this.label, this.icon, this.typeIndex);
}

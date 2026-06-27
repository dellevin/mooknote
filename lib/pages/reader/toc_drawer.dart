import 'package:flutter/material.dart';
import 'epub_player.dart';

/// 目录抽屉 — 显示书籍章节目录，点击跳转
class TocDrawer extends StatelessWidget {
  final List<TocItem> toc;
  final GlobalKey<EpubPlayerState> epubPlayerKey;
  final VoidCallback? onClose;

  const TocDrawer({
    super.key,
    required this.toc,
    required this.epubPlayerKey,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.toc, size: 20, color: colors.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text('目录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose ?? () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: toc.isEmpty
                  ? Center(
                      child: Text('暂无目录', style: TextStyle(color: colors.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: toc.length,
                      itemBuilder: (context, index) {
                        final item = toc[index];
                        final indent = (item.level - 1) * 16.0;
                        return InkWell(
                          onTap: () {
                            epubPlayerKey.currentState?.goToHref(item.href);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: EdgeInsets.only(left: 20 + indent, right: 20, top: 12, bottom: 12),
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: item.level == 1 ? 14 : 13,
                                fontWeight: item.level == 1 ? FontWeight.w500 : FontWeight.normal,
                                color: colors.onSurface.withAlpha(204),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

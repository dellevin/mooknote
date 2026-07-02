import 'package:flutter/material.dart';

/// 标签侧边面板 - 从右侧滑入，用于选择和新建标签
class TagSidePanel extends StatefulWidget {
  final List<String> selectedTags;
  final List<String> allAvailableTags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagSidePanel({
    super.key,
    required this.selectedTags,
    required this.allAvailableTags,
    required this.onTagsChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> selectedTags,
    required List<String> allAvailableTags,
    required ValueChanged<List<String>> onTagsChanged,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'tag-panel',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerRight,
            child: TagSidePanel(
              selectedTags: selectedTags,
              allAvailableTags: allAvailableTags,
              onTagsChanged: onTagsChanged,
            ),
          ),
        );
      },
    );
  }

  @override
  State<TagSidePanel> createState() => _TagSidePanelState();
}

class _TagSidePanelState extends State<TagSidePanel> {
  late List<String> _selected;
  final _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedTags);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
    widget.onTagsChanged(_selected);
  }

  void _addNewTag() {
    final tag = _inputController.text.trim();
    if (tag.isEmpty) return;
    if (!_selected.contains(tag)) {
      setState(() => _selected.add(tag));
      widget.onTagsChanged(_selected);
    }
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screenWidth * 0.75,
        height: double.infinity,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text('标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onPrimary)),
                    ),
                  ),
                ],
              ),
            ),

            // 新建标签输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _inputController,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: '输入新标签，回车添加',
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary, width: 1),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add, size: 18, color: colors.primary),
                    onPressed: _addNewTag,
                  ),
                ),
                onSubmitted: (_) => _addNewTag(),
              ),
            ),

            // 已选标签
            if (_selected.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('已选标签', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: _selected.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: GestureDetector(
                          onTap: () => _toggleTag(tag),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tag, style: TextStyle(fontSize: 13, color: colors.onPrimary)),
                              const SizedBox(width: 4),
                              Icon(Icons.close, size: 14, color: colors.onPrimary),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // 全部标签
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('全部标签', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: widget.allAvailableTags.map((tag) {
                    final isSelected = _selected.contains(tag);
                    return GestureDetector(
                      onTap: () => _toggleTag(tag),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? colors.primary : colors.outline,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

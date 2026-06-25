import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/note_plus_models.dart';
import '../../providers/note_plus_provider.dart';
import 'note_plus_block_widget.dart';
import 'slash_command_menu.dart';

/// Note Plus 块编辑器
///
/// 管理 block 列表、焦点切换、键盘事件处理。
/// 使用 ReorderableListView 支持拖拽排序。
class NotePlusEditor extends StatefulWidget {
  const NotePlusEditor({super.key});

  @override
  State<NotePlusEditor> createState() => _NotePlusEditorState();
}

class _NotePlusEditorState extends State<NotePlusEditor> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  OverlayEntry? _slashMenuOverlay;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    _removeSlashMenu();
    super.dispose();
  }

  TextEditingController _getController(NoteBlock block) {
    return _controllers.putIfAbsent(block.id, () {
      final c = TextEditingController(text: block.text);
      c.addListener(() => _onControllerChanged(block));
      return c;
    });
  }

  FocusNode _getFocusNode(NoteBlock block, int index) {
    return _focusNodes.putIfAbsent(block.id, () {
      final fn = FocusNode(onKeyEvent: (node, event) => _handleKeyEvent(index, event));
      fn.addListener(() {
        if (fn.hasFocus) {
          context.read<NotePlusProvider>().setFocusedBlock(index);
        }
      });
      return fn;
    });
  }

  void _onControllerChanged(NoteBlock block) {
    final provider = context.read<NotePlusProvider>();
    final idx = provider.blocks.indexWhere((b) => b.id == block.id);
    if (idx < 0) return;

    final text = _controllers[block.id]!.text;

    // 更新 block 文本（静默，不 rebuild）
    provider.updateBlockSilent(
      idx,
      provider.blocks[idx].copyWith(text: text),
    );

    // 检测斜杠命令
    if (text == '/' || (text.startsWith('/') && text.length > 1)) {
      _showSlashMenu(idx, text);
    } else {
      _removeSlashMenu();
    }
  }

  void _onBlockTap(int index) {
    final provider = context.read<NotePlusProvider>();
    provider.setFocusedBlock(index);

    final block = provider.blocks[index];
    if (block.type == NoteBlockType.divider) return;

    final node = _getFocusNode(block, index);
    if (!node.hasFocus) {
      node.requestFocus();
    }
  }

  void _onToggleChecklist(int index) {
    context.read<NotePlusProvider>().toggleChecklist(index);
  }

  /// 处理键盘事件
  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final provider = context.read<NotePlusProvider>();
    final block = provider.blocks[index];
    final controller = _controllers[block.id];
    if (controller == null) return KeyEventResult.ignored;

    final sel = controller.selection;

    // Enter → 分割 block
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      final pos = sel.isValid ? sel.baseOffset : controller.text.length;
      provider.splitBlock(index, pos);

      // 聚焦新 block
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusBlockAtIndex(index + 1, atStart: true);
      });
      return KeyEventResult.handled;
    }

    // Backspace 在位置0 → 合并到前一个
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == 0 &&
        index > 0) {
      final cursorPos = provider.mergeWithPrevious(index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusBlockAtIndex(index - 1, atCursor: cursorPos);
      });
      return KeyEventResult.handled;
    }

    // ↑ 在位置0 → 聚焦上一个
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == 0 &&
        index > 0) {
      _focusBlockAtIndex(index - 1, atEnd: true);
      return KeyEventResult.handled;
    }

    // ↓ 在末位 → 聚焦下一个
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        sel.isValid &&
        sel.isCollapsed &&
        sel.baseOffset == controller.text.length &&
        index < provider.blocks.length - 1) {
      _focusBlockAtIndex(index + 1, atStart: true);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _focusBlockAtIndex(int index, {bool atStart = false, bool atEnd = false, int? atCursor}) {
    final provider = context.read<NotePlusProvider>();
    if (index < 0 || index >= provider.blocks.length) return;

    final block = provider.blocks[index];
    if (block.type == NoteBlockType.divider) return;

    provider.setFocusedBlock(index);
    final node = _getFocusNode(block, index);
    final controller = _getController(block);

    // 等 controller 同步后设置光标
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.hasFocus) node.requestFocus();
      int cursorPos;
      if (atCursor != null) {
        cursorPos = atCursor;
      } else if (atEnd) {
        cursorPos = controller.text.length;
      } else {
        cursorPos = 0;
      }
      controller.selection = TextSelection.collapsed(offset: cursorPos);
    });
  }

  // ========== Slash Menu ==========

  void _showSlashMenu(int blockIndex, String text) {
    _removeSlashMenu();

    final query = text.length > 1 ? text.substring(1) : '';

    _slashMenuOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 60,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: SlashCommandMenu(
            query: query,
            onSelect: (type) {
              _removeSlashMenu();
              final provider = context.read<NotePlusProvider>();
              // 清除 / 文本
              provider.updateBlockSilent(
                blockIndex,
                provider.blocks[blockIndex].copyWith(text: ''),
              );
              _controllers[provider.blocks[blockIndex].id]?.text = '';
              // 转换类型
              provider.convertBlockType(blockIndex, type);
            },
            onDismiss: _removeSlashMenu,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_slashMenuOverlay!);
  }

  void _removeSlashMenu() {
    _slashMenuOverlay?.remove();
    _slashMenuOverlay = null;
  }

  // ========== Build ==========

  @override
  Widget build(BuildContext context) {
    return Consumer<NotePlusProvider>(
      builder: (context, provider, _) {
        final blocks = provider.blocks;

        return ListView.builder(
          controller: _scrollController,
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            final block = blocks[index];
            final isFocused = provider.focusedBlockIndex == index;

            // 计算有序列表序号
            int numberedIndex = 1;
            if (block.type == NoteBlockType.numberedList) {
              for (int i = index - 1; i >= 0; i--) {
                if (blocks[i].type == NoteBlockType.numberedList) {
                  numberedIndex++;
                } else {
                  break;
                }
              }
            }

            // 同步 controller 文本
            final controller = isFocused ? _getController(block) : null;
            if (controller != null && controller.text != block.text) {
              // 用 addPostFrameCallback 避免 build 期间修改
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (controller.text != block.text) {
                  controller.text = block.text;
                }
              });
            }

            return Padding(
              key: ValueKey(block.id),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Block 内容
                    Expanded(
                      child: NotePlusBlockWidget(
                        block: block,
                        index: index,
                        numberedIndex: numberedIndex,
                        isFocused: isFocused,
                        controller: controller,
                        focusNode: isFocused ? _getFocusNode(block, index) : null,
                        onTap: () => _onBlockTap(index),
                        onToggleChecklist: block.type == NoteBlockType.checklist
                            ? () => _onToggleChecklist(index)
                            : null,
                      ),
                    ),
                  ],
                ),
              );
          },
        );
      },
    );
  }
}

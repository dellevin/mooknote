import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note_plus_models.dart';
import '../../providers/note_plus_provider.dart';

/// Note Plus 只读查看页
class NotePlusDetailPage extends StatelessWidget {
  final String documentId;

  const NotePlusDetailPage({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<NotePlusDocument?>(
      future: context.read<NotePlusProvider>().getDeletedDocuments().then(
          (_) => context.read<NotePlusProvider>().currentDocument?.id == documentId
              ? context.read<NotePlusProvider>().currentDocument
              : null),
      builder: (context, snapshot) {
        // 直接从 provider 取
        return Consumer<NotePlusProvider>(
          builder: (context, provider, _) {
            final doc = provider.currentDocument;
            if (doc == null || doc.id != documentId) {
              // 加载文档
              provider.loadDocumentById(documentId);
              return Scaffold(
                backgroundColor: colors.surface,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              backgroundColor: colors.surface,
              appBar: AppBar(
                title: Text(doc.title.isEmpty ? '无标题' : doc.title),
                backgroundColor: colors.surface,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pushNamed(context, '/note-plus-form',
                          arguments: doc.id);
                    },
                  ),
                ],
              ),
              body: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: doc.blocks.length,
                itemBuilder: (context, index) {
                  return _buildBlock(doc.blocks[index], index, doc.blocks, colors);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlock(NoteBlock block, int index, List<NoteBlock> allBlocks,
      ColorScheme colors) {
    if (block.type == NoteBlockType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(height: 1, color: colors.outlineVariant),
      );
    }

    final style = _getTextStyle(block, colors);
    final text = block.text.isEmpty ? '(空)' : block.text;

    return Padding(
      padding: _getBlockPadding(block),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrefix(block, index, allBlocks, colors),
          Expanded(
            child: block.type == NoteBlockType.codeBlock
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: block.text.isEmpty
                        ? Text('(空)', style: style.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.2)))
                        : _buildRichText(text, style, block, colors),
                  )
                : block.text.isEmpty
                    ? Text(text, style: style.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.2)))
                    : _buildRichText(text, style, block, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefix(NoteBlock block, int index, List<NoteBlock> allBlocks,
      ColorScheme colors) {
    switch (block.type) {
      case NoteBlockType.bulletList:
        return Padding(
          padding: const EdgeInsets.only(top: 8, right: 8),
          child: Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      case NoteBlockType.numberedList:
        int num = 1;
        for (int i = index - 1; i >= 0; i--) {
          if (allBlocks[i].type == NoteBlockType.numberedList) {
            num++;
          } else {
            break;
          }
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Text('$num.', style: TextStyle(
              fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
        );
      case NoteBlockType.checklist:
        return Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Icon(
            block.metadata['checked'] == true
                ? Icons.check_box
                : Icons.check_box_outline_blank,
            size: 20,
            color: block.metadata['checked'] == true
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.4),
          ),
        );
      case NoteBlockType.quote:
        return Container(
          width: 4,
          margin: const EdgeInsets.only(top: 6, bottom: 6, right: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRichText(String text, TextStyle style, NoteBlock block,
      ColorScheme colors) {
    if (block.formatting.isEmpty) return Text(text, style: style);

    final spans = <InlineSpan>[];
    final events = <_FmtEvent>[];
    for (final span in block.formatting) {
      if (span.start < text.length) {
        events.add(_FmtEvent(span.start, true, span.formats));
        events.add(_FmtEvent(
            span.end > text.length ? text.length : span.end, false, span.formats));
      }
    }
    events.sort((a, b) => a.pos.compareTo(b.pos));

    int lastPos = 0;
    final active = <InlineFormatType>{};
    for (final e in events) {
      if (e.pos > lastPos) {
        spans.add(TextSpan(
          text: text.substring(lastPos, e.pos),
          style: _applyFormats(style, active, colors),
        ));
      }
      if (e.isStart) {
        active.addAll(e.formats);
      } else {
        active.removeAll(e.formats);
      }
      lastPos = e.pos;
    }
    if (lastPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastPos),
        style: _applyFormats(style, active, colors),
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  TextStyle _applyFormats(TextStyle style, Set<InlineFormatType> formats,
      ColorScheme colors) {
    if (formats.isEmpty) return style;
    return style.copyWith(
      fontWeight: formats.contains(InlineFormatType.bold) ? FontWeight.w700 : null,
      fontStyle: formats.contains(InlineFormatType.italic) ? FontStyle.italic : null,
      decoration: _getDecoration(formats),
      fontFamily: formats.contains(InlineFormatType.inlineCode) ? 'monospace' : null,
      backgroundColor: formats.contains(InlineFormatType.inlineCode)
          ? colors.surfaceContainerHighest : null,
    );
  }

  TextDecoration? _getDecoration(Set<InlineFormatType> formats) {
    final list = <TextDecoration>[];
    if (formats.contains(InlineFormatType.underline)) list.add(TextDecoration.underline);
    if (formats.contains(InlineFormatType.strikethrough)) list.add(TextDecoration.lineThrough);
    return list.isEmpty ? null : TextDecoration.combine(list);
  }

  TextStyle _getTextStyle(NoteBlock block, ColorScheme colors) {
    // AppFlowy base: 18px, w300, height 1.3, letter-spacing 0.6
    final base = TextStyle(
      color: colors.onSurface,
      fontSize: 18, fontWeight: FontWeight.w300, height: 1.3, letterSpacing: 0.6,
    );
    switch (block.type) {
      case NoteBlockType.heading1:
        return base.copyWith(fontSize: 34, fontWeight: FontWeight.w300, height: 1.15,
            letterSpacing: 0, color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.heading2:
        return base.copyWith(fontSize: 24, fontWeight: FontWeight.w400, height: 1.15,
            letterSpacing: 0, color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.heading3:
        return base.copyWith(fontSize: 20, fontWeight: FontWeight.w500, height: 1.25,
            letterSpacing: 0, color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.quote:
        return base.copyWith(color: colors.onSurface.withValues(alpha: 0.6));
      case NoteBlockType.codeBlock:
        return base.copyWith(fontSize: 13, fontWeight: FontWeight.w400, fontFamily: 'monospace',
            height: 1.15, letterSpacing: 0, color: Colors.blue.shade900.withValues(alpha: 0.9));
      case NoteBlockType.checklist:
        return base.copyWith(
          decoration: block.metadata['checked'] == true ? TextDecoration.lineThrough : null,
          color: block.metadata['checked'] == true ? colors.onSurface.withValues(alpha: 0.4) : null,
        );
      default:
        return base;
    }
  }

  EdgeInsets _getBlockPadding(NoteBlock block) {
    switch (block.type) {
      case NoteBlockType.heading1:
        return const EdgeInsets.only(top: 16);
      case NoteBlockType.heading2:
        return const EdgeInsets.only(top: 8);
      case NoteBlockType.heading3:
        return const EdgeInsets.only(top: 8);
      case NoteBlockType.codeBlock:
        return const EdgeInsets.symmetric(vertical: 6);
      case NoteBlockType.quote:
        return const EdgeInsets.only(top: 6, bottom: 2);
      default:
        return const EdgeInsets.only(top: 10);
    }
  }
}

class _FmtEvent {
  final int pos;
  final bool isStart;
  final Set<InlineFormatType> formats;
  _FmtEvent(this.pos, this.isStart, this.formats);
}

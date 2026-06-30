import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../utils/epub/epub_stream_service.dart';
import 'book_session.dart';

class SearchSheet extends StatefulWidget {
  final BookSession bookSession;
  final EpubStreamService streamService;
  final void Function(int spineIndex, String keyword, double scrollRatio) onNavigate;

  const SearchSheet({
    super.key,
    required this.bookSession,
    required this.streamService,
    required this.onNavigate,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_SearchResult> _allResults = [];
  List<_SearchResult> _displayResults = [];
  bool _searching = false;
  bool _searched = false;
  bool _loadingMore = false;
  String _currentQuery = '';
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50 &&
        !_loadingMore &&
        _displayResults.length < _allResults.length) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      final nextBatch = _allResults
          .skip(_displayResults.length)
          .take(_pageSize)
          .toList();
      setState(() {
        _displayResults.addAll(nextBatch);
        _loadingMore = false;
      });
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    // 收起键盘
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searched = true;
      _currentQuery = query;
    });

    final results = <_SearchResult>[];
    final spine = widget.bookSession.spine;

    for (int i = 0; i < spine.length; i++) {
      final href = spine[i].href;
      try {
        final bytes = await widget.streamService.readFileFromEpub(
          targetFilePath: href,
        );
        if (bytes == null) continue;

        final text = _extractBodyText(bytes);
        if (text.isEmpty) continue;

        final lowerText = text.toLowerCase();
        final lowerQuery = query.toLowerCase();

        int startIndex = 0;
        while (true) {
          final idx = lowerText.indexOf(lowerQuery, startIndex);
          if (idx == -1) break;

          final start = (idx - 40).clamp(0, text.length);
          final end = (idx + query.length + 40).clamp(0, text.length);
          final contextStr = text.substring(start, end);

          results.add(_SearchResult(
            chapterIndex: i,
            chapterTitle: _getChapterTitle(i),
            context: contextStr,
            matchIndex: idx,
            scrollRatio: idx / text.length,
          ));

          startIndex = idx + query.length;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _allResults = results;
        _displayResults = results.take(_pageSize).toList();
        _searching = false;
      });
    }
  }

  String _extractBodyText(List<int> bytes) {
    try {
      final content = utf8.decode(bytes, allowMalformed: true);
      final doc = XmlDocument.parse(content);
      // 只提取 <body> 内容
      final body = doc.findAllElements('body').firstOrNull;
      if (body == null) return '';
      final buffer = StringBuffer();
      _extractTextFromBody(body, buffer);
      return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return '';
    }
  }

  void _extractTextFromBody(XmlNode node, StringBuffer buffer) {
    // 跳过 script、style、svg 等非内容标签
    if (node is XmlElement) {
      final name = node.name.local.toLowerCase();
      if (name == 'script' || name == 'style' || name == 'svg' ||
          name == 'head' || name == 'nav') {
        return;
      }
    }
    if (node is XmlText) {
      buffer.write(node.value);
    }
    for (final child in node.children) {
      _extractTextFromBody(child, buffer);
    }
  }

  String _getChapterTitle(int index) {
    final toc = widget.bookSession.toc;
    for (final entry in toc) {
      if (entry.spineIndex == index) return entry.label;
    }
    return '第${index + 1}章';
  }

  List<TextSpan> _buildHighlightedText(String text, String query, ColorScheme colors) {
    if (query.isEmpty) {
      return [TextSpan(text: text, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7)))];
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int lastEnd = 0;

    int idx = lowerText.indexOf(lowerQuery);
    while (idx != -1) {
      if (idx > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, idx),
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7)),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          fontSize: 13,
          color: colors.error,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = idx + query.length;
      idx = lowerText.indexOf(lowerQuery, lastEnd);
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7)),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 拖拽条
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    decoration: InputDecoration(
                      hintText: '搜索书籍内容...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: colors.onSurface.withValues(alpha: 0.35),
                      ),
                      prefixIcon: Icon(Icons.search,
                          size: 20, color: colors.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _performSearch(_controller.text),
                  child: Text('搜索',
                      style: TextStyle(
                          fontSize: 14,
                          color: colors.primary,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, thickness: 0.5, color: colors.outline),
          // 结果统计
          if (_searched && !_searching && _allResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('共找到 ${_allResults.length} 条结果',
                    style: TextStyle(fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            ),
          // 结果列表
          Expanded(
            child: _searching
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        const SizedBox(height: 12),
                        Text('搜索中...',
                            style: TextStyle(fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  )
                : !_searched
                    ? Center(
                        child: Text('输入关键词搜索书籍内容',
                            style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.35))))
                    : _allResults.isEmpty
                        ? Center(
                            child: Text('未找到相关内容',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface.withValues(alpha: 0.35))))
                        : ListView.separated(
                            controller: _scrollController,
                            padding: EdgeInsets.only(bottom: bottomPadding + 16),
                            itemCount: _displayResults.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                Divider(height: 0.5, indent: 16, endIndent: 16,
                                    color: colors.outline),
                            itemBuilder: (context, index) {
                              if (index >= _displayResults.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                );
                              }
                              final r = _displayResults[index];
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                title: Text(r.chapterTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.primary,
                                        fontWeight: FontWeight.w500)),
                                subtitle: RichText(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: _buildHighlightedText(
                                      '...${r.context}...', _currentQuery, colors),
                                  ),
                                ),
                                onTap: () => widget.onNavigate(
                                    r.chapterIndex, _currentQuery, r.scrollRatio),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final int chapterIndex;
  final String chapterTitle;
  final String context;
  final int matchIndex;
  final double scrollRatio; // 匹配位置在章节中的比例 (0.0~1.0)

  _SearchResult({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.context,
    required this.matchIndex,
    required this.scrollRatio,
  });
}

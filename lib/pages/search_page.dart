import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';

/// 搜索页面 - 统一搜索影视/书籍/笔记
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  bool _showMovies = true;
  bool _showBooks = true;
  bool _showNotes = true;

  List<_SearchResult> _results = [];
  bool _hasSearched = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _performSearch);
  }

  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    final provider = context.read<AppProvider>();
    final lowerKeyword = keyword.toLowerCase();
    final results = <_SearchResult>[];

    if (_showMovies) {
      for (final movie in provider.movies.where((m) => !m.isDeleted)) {
        if (movie.title.toLowerCase().contains(lowerKeyword) ||
            movie.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
            (movie.summary?.toLowerCase().contains(lowerKeyword) ?? false)) {
          results.add(_SearchResult(type: 'movie', data: movie));
        }
      }
    }

    if (_showBooks) {
      for (final book in provider.books.where((b) => !b.isDeleted)) {
        if (book.title.toLowerCase().contains(lowerKeyword) ||
            book.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
            (book.summary?.toLowerCase().contains(lowerKeyword) ?? false)) {
          results.add(_SearchResult(type: 'book', data: book));
        }
      }
    }

    if (_showNotes) {
      for (final note in provider.notes.where((n) => !n.isDeleted)) {
        if (note.content.toLowerCase().contains(lowerKeyword)) {
          results.add(_SearchResult(type: 'note', data: note));
        }
      }
    }

    setState(() {
      _results = results;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('搜索'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(
            child: _hasSearched
                ? _results.isEmpty ? _buildEmptyState() : _buildResultList()
                : _buildInitialState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: 15, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: '搜索标题、别名、内容...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.35), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.search, color: colors.onSurface, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _scheduleSearch();
                    _focusNode.requestFocus();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.outline,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.close, color: colors.onSurface.withValues(alpha: 0.6), size: 16),
                  ),
                )
              : null,
          filled: true,
          fillColor: colors.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) {
          _debounce?.cancel();
          _performSearch();
        },
        onChanged: (_) {
          _debounce?.cancel();
          setState(() {});
          _scheduleSearch();
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          _buildTypeChip('影视', Icons.movie_outlined, _showMovies, (v) {
            setState(() { _showMovies = v; _performSearch(); });
          }),
          const SizedBox(width: 8),
          _buildTypeChip('书籍', Icons.menu_book_outlined, _showBooks, (v) {
            setState(() { _showBooks = v; _performSearch(); });
          }),
          const SizedBox(width: 8),
          _buildTypeChip('笔记', Icons.note_outlined, _showNotes, (v) {
            setState(() { _showNotes = v; _performSearch(); });
          }),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, IconData icon, bool selected, ValueChanged<bool> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.search_rounded, size: 44, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text('输入关键词搜索', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('可同时筛选影视、书籍、笔记', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.search_off_rounded, size: 44, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 24),
          Text('未找到相关内容', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('换个关键词试试', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25))),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        switch (item.type) {
          case 'movie':
            return _buildMovieItem(item.data as Movie);
          case 'book':
            return _buildBookItem(item.data as Book);
          case 'note':
            return _buildNoteItem(item.data as Note);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ─── 影视结果项 ──────────────────────────────────────────────────────

  Widget _buildMovieItem(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildPosterThumb(movie.posterPath, Icons.movie_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _typeBadge('影视', const Color(0xFF4A90D9)),
                      const Spacer(),
                      _statusBadge(movie.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  if (movie.alternateTitles.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(movie.alternateTitles.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  // ─── 书籍结果项 ──────────────────────────────────────────────────────

  Widget _buildBookItem(Book book) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildPosterThumb(book.coverPath, Icons.menu_book_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _typeBadge('书籍', const Color(0xFF7E57C2)),
                      const Spacer(),
                      _bookStatusBadge(book.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(book.authors.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  // ─── 笔记结果项 ──────────────────────────────────────────────────────

  Widget _buildNoteItem(Note note) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: note))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _typeBadge('笔记', const Color(0xFF66BB6A)),
                const Spacer(),
                Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note.summary.trim().isEmpty ? '(无内容)' : note.summary.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.75), height: 1.6),
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: note.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 通用组件 ────────────────────────────────────────────────────────

  Widget _buildPosterThumb(String? path, IconData fallback) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null && path.isNotEmpty
          ? Image.file(File(path), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(fallback, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
          : Icon(fallback, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
    );
  }

  Widget _typeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statusBadge(String status) {
    final colors = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'watched' => ('已看', colors.primary, colors.onPrimary),
      'watching' => ('在看', colors.outlineVariant, colors.onSurface.withValues(alpha: 0.6)),
      'want_to_watch' => ('想看', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.4)),
      _ => ('', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.3)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _bookStatusBadge(String status) {
    final colors = Theme.of(context).colorScheme;
    final (label, bg, fg) = switch (status) {
      'read' => ('已读', colors.primary, colors.onPrimary),
      'reading' => ('在读', colors.outlineVariant, colors.onSurface.withValues(alpha: 0.6)),
      'want_to_read' => ('想读', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.4)),
      _ => ('', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.3)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SearchResult {
  final String type;
  final dynamic data;
  _SearchResult({required this.type, required this.data});
}

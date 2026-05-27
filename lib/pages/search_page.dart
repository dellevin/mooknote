import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';
import '../widgets/fade_in_local_image.dart';

/// 搜索页面
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
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
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    final provider = context.read<AppProvider>();
    final lowerKeyword = keyword.toLowerCase();
    final results = <_SearchResult>[];

    if (_showMovies) {
      for (final movie in provider.movies.where((m) => !m.isDeleted)) {
        if (movie.title.toLowerCase().contains(lowerKeyword) ||
            movie.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
            (movie.summary?.toLowerCase().contains(lowerKeyword) ?? false) ||
            movie.genres.any((g) => g.toLowerCase().contains(lowerKeyword))) {
          results.add(_SearchResult(type: 'movie', data: movie));
        }
      }
    }
    if (_showBooks) {
      for (final book in provider.books.where((b) => !b.isDeleted)) {
        if (book.title.toLowerCase().contains(lowerKeyword) ||
            book.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
            (book.summary?.toLowerCase().contains(lowerKeyword) ?? false) ||
            book.authors.any((a) => a.toLowerCase().contains(lowerKeyword))) {
          results.add(_SearchResult(type: 'book', data: book));
        }
      }
    }
    if (_showNotes) {
      for (final note in provider.notes.where((n) => !n.isDeleted)) {
        if (note.content.toLowerCase().contains(lowerKeyword) ||
            note.tags.any((t) => t.toLowerCase().contains(lowerKeyword))) {
          results.add(_SearchResult(type: 'note', data: note));
        }
      }
    }
    setState(() { _results = results; _hasSearched = true; });
  }

  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('搜索'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(children: [
        _buildSearchBar(),
        _buildFilterRow(),
        Expanded(
          child: _hasSearched
              ? _results.isEmpty ? _buildEmptyState() : _buildResultList()
              : _buildInitialState(),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: 15, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: '搜索标题、作者、标签...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 15),
          prefixIcon: Icon(Icons.search, color: colors.onSurface.withValues(alpha: 0.4), size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () { _searchController.clear(); setState(() {}); _scheduleSearch(); _focusNode.requestFocus(); },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.close, color: colors.onSurface.withValues(alpha: 0.5), size: 16),
                  ),
                )
              : null,
          filled: true, fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) { _debounce?.cancel(); _performSearch(); },
        onChanged: (_) { _debounce?.cancel(); setState(() {}); _scheduleSearch(); },
      ),
    );
  }

  Widget _buildFilterRow() {
    final colors = Theme.of(context).colorScheme;
    final keyword = _searchController.text.trim();
    final provider = context.read<AppProvider>();
    int movieCount = 0, bookCount = 0, noteCount = 0;
    if (keyword.isNotEmpty) {
      final kw = keyword.toLowerCase();
      movieCount = provider.movies.where((m) => !m.isDeleted && (m.title.toLowerCase().contains(kw) || m.alternateTitles.any((t) => t.toLowerCase().contains(kw)) || (m.summary?.toLowerCase().contains(kw) ?? false) || m.genres.any((g) => g.toLowerCase().contains(kw)))).length;
      bookCount = provider.books.where((b) => !b.isDeleted && (b.title.toLowerCase().contains(kw) || b.alternateTitles.any((t) => t.toLowerCase().contains(kw)) || (b.summary?.toLowerCase().contains(kw) ?? false) || b.authors.any((a) => a.toLowerCase().contains(kw)))).length;
      noteCount = provider.notes.where((n) => !n.isDeleted && (n.content.toLowerCase().contains(kw) || n.tags.any((t) => t.toLowerCase().contains(kw)))).length;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        _filterChip('影视', Icons.movie_outlined, _showMovies, movieCount, () { setState(() { _showMovies = !_showMovies; _performSearch(); }); }),
        const SizedBox(width: 8),
        _filterChip('书籍', Icons.menu_book_outlined, _showBooks, bookCount, () { setState(() { _showBooks = !_showBooks; _performSearch(); }); }),
        const SizedBox(width: 8),
        _filterChip('笔记', Icons.note_outlined, _showNotes, noteCount, () { setState(() { _showNotes = !_showNotes; _performSearch(); }); }),
      ]),
    );
  }

  Widget _filterChip(String label, IconData icon, bool selected, int count, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    final showCount = _searchController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.4))),
          if (showCount) ...[const SizedBox(width: 4), Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? colors.onPrimary.withValues(alpha: 0.7) : colors.onSurface.withValues(alpha: 0.25)))],
        ]),
      ),
    );
  }

  Widget _buildInitialState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.search_rounded, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 20),
        Text('输入关键词搜索', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.35))),
        const SizedBox(height: 4),
        Text('支持标题、作者、标签、类型', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.search_off_rounded, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 20),
        Text('未找到相关内容', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.35))),
        const SizedBox(height: 4),
        Text('换个关键词试试', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _buildResultList() {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text('找到 ${_results.length} 条结果',
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final item = _results[index];
            switch (item.type) {
              case 'movie': return _buildMovieItem(item.data as Movie);
              case 'book': return _buildBookItem(item.data as Book);
              case 'note': return _buildNoteItem(item.data as Note);
              default: return const SizedBox.shrink();
            }
          },
        ),
      ),
    ]);
  }

  Widget _buildMovieItem(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(movie.posterPath, Icons.movie_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge('影视'),
                const Spacer(),
                _statusBadge(movie.status, colors),
              ]),
              const SizedBox(height: 6),
              Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 4),
              Row(children: [
                if (movie.rating != null) ...[
                  Icon(Icons.star, size: 13, color: const Color(0xFFFFB800)),
                  const SizedBox(width: 2),
                  Text('${movie.rating}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFFB800))),
                  const SizedBox(width: 8),
                ],
                if (movie.genres.isNotEmpty)
                  Expanded(child: Text(movie.genres.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(book.coverPath, Icons.menu_book_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge('书籍'),
                const Spacer(),
                _statusBadge(book.status, colors),
              ]),
              const SizedBox(height: 6),
              Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 4),
              Row(children: [
                if (book.rating != null) ...[
                  Icon(Icons.star, size: 13, color: const Color(0xFFFFB800)),
                  const SizedBox(width: 2),
                  Text('${book.rating}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFFB800))),
                  const SizedBox(width: 8),
                ],
                if (book.authors.isNotEmpty)
                  Expanded(child: Text(book.authors.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final colors = Theme.of(context).colorScheme;
    final summary = note.summary.trim().isEmpty ? '(无内容)' : note.summary.trim();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: note))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _typeBadge('笔记'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.5)),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: note.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(4)),
                  child: Text(t, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                )).toList()),
              ],
            ]),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
          ),
        ]),
      ),
    );
  }

  Widget _posterThumb(String? path, IconData fallback) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 44, height: 58,
      decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: path != null && path.isNotEmpty
          ? FadeInLocalImage(path: path, fit: BoxFit.cover,
              errorWidget: Icon(fallback, size: 20, color: colors.onSurface.withValues(alpha: 0.25)))
          : Icon(fallback, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
    );
  }

  Widget _typeBadge(String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary)),
    );
  }

  Widget _statusBadge(String status, ColorScheme colors) {
    final (label, bg, fg) = switch (status) {
      'watched' || 'read' => ('已看' , colors.primary, colors.onPrimary),
      'watching' || 'reading' => ('在看', colors.outlineVariant, colors.onSurface.withValues(alpha: 0.6)),
      'want_to_watch' || 'want_to_read' => ('想看', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.4)),
      _ => ('', colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.3)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SearchResult {
  final String type;
  final dynamic data;
  _SearchResult({required this.type, required this.data});
}

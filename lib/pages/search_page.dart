import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';

/// 搜索页面 - 统一搜索影视/书籍/笔记，标签区分
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  // 类型筛选：默认全部选中
  bool _showMovies = true;
  bool _showBooks = true;
  bool _showNotes = true;

  String? _selectedTag;

  List<_SearchResult> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 自动聚焦，弹出键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty && _selectedTag == null) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final provider = context.read<AppProvider>();
    final lowerKeyword = keyword.toLowerCase();
    final results = <_SearchResult>[];

    // 影视
    if (_showMovies) {
      for (final movie in provider.movies.where((m) => !m.isDeleted)) {
        if (_matchMovie(movie, lowerKeyword)) {
          results.add(_SearchResult(type: 'movie', data: movie));
        }
      }
    }

    // 书籍
    if (_showBooks) {
      for (final book in provider.books.where((b) => !b.isDeleted)) {
        if (_matchBook(book, lowerKeyword)) {
          results.add(_SearchResult(type: 'book', data: book));
        }
      }
    }

    // 笔记
    if (_showNotes) {
      for (final note in provider.notes.where((n) => !n.isDeleted)) {
        if (_matchNote(note, lowerKeyword)) {
          results.add(_SearchResult(type: 'note', data: note));
        }
      }
    }

    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  bool _matchMovie(Movie movie, String lowerKeyword) {
    if (lowerKeyword.isEmpty) return true;
    return movie.title.toLowerCase().contains(lowerKeyword) ||
        movie.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
        (movie.summary?.toLowerCase().contains(lowerKeyword) ?? false);
  }

  bool _matchBook(Book book, String lowerKeyword) {
    if (lowerKeyword.isEmpty) return true;
    return book.title.toLowerCase().contains(lowerKeyword) ||
        book.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
        (book.summary?.toLowerCase().contains(lowerKeyword) ?? false);
  }

  bool _matchNote(Note note, String lowerKeyword) {
    if (_selectedTag != null && !note.tags.contains(_selectedTag)) return false;
    if (lowerKeyword.isEmpty) return _selectedTag != null;
    return note.content.toLowerCase().contains(lowerKeyword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('搜索'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索输入框
          _buildSearchBar(),

          // 类型筛选 & 标签筛选
          _buildFilterRow(),

          // 结果
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)))
                : _results.isEmpty && _searchController.text.isEmpty && _selectedTag == null
                    ? _buildInitialState()
                    : _results.isEmpty
                        ? _buildEmptyState()
                        : _buildResultList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: '搜索影视、书籍、笔记...',
          hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF666666), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF999999), size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) => _performSearch(),
        onChanged: (_) {
          _performSearch();
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // 收集所有笔记标签
        final allTags = <String>{};
        for (final note in provider.notes.where((n) => !n.isDeleted)) {
          allTags.addAll(note.tags);
        }
        final tags = allTags.toList()..sort();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 类型筛选行
              Row(
                children: [
                  const Text('类型', style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                  const SizedBox(width: 10),
                  _buildTypeChip('影视', _showMovies, (v) {
                    setState(() { _showMovies = v; _performSearch(); });
                  }),
                  const SizedBox(width: 8),
                  _buildTypeChip('书籍', _showBooks, (v) {
                    setState(() { _showBooks = v; _performSearch(); });
                  }),
                  const SizedBox(width: 8),
                  _buildTypeChip('笔记', _showNotes, (v) {
                    setState(() { _showNotes = v; _performSearch(); });
                  }),
                ],
              ),

              // 笔记标签筛选
              if (tags.isNotEmpty && _showNotes) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tags.length + (_selectedTag != null ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      // 第一个始终是"全部标签"清除按钮
                      if (_selectedTag != null && index == 0) {
                        return _buildTagChip('全部标签', true, () {
                          setState(() { _selectedTag = null; _performSearch(); });
                        });
                      }
                      final tagIndex = _selectedTag != null ? index - 1 : index;
                      final tag = tags[tagIndex];
                      final isSelected = _selectedTag == tag;
                      return _buildTagChip(tag, isSelected, () {
                        setState(() {
                          _selectedTag = isSelected ? null : tag;
                          _performSearch();
                        });
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF888888),
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              const Icon(Icons.close, size: 12, color: Colors.white70),
            if (selected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.search, size: 40, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(height: 20),
          const Text('输入关键词搜索影视、书籍、笔记', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(height: 4),
          const Text('可同时筛选多个类型', style: TextStyle(fontSize: 12, color: Color(0xFFCCCCCC))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.search_off, size: 40, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(height: 20),
          const Text('未找到相关内容', style: TextStyle(fontSize: 15, color: Color(0xFF999999))),
          const SizedBox(height: 8),
          const Text('尝试更换关键词或筛选条件', style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC))),
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

  Widget _buildItemWrapper({
    required Widget child,
    required String typeLabel,
    required IconData typeIcon,
    required Color typeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型标签
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 10, color: typeColor),
                      const SizedBox(width: 3),
                      Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMovieItem(Movie movie) {
    return _buildItemWrapper(
      typeLabel: '影视',
      typeIcon: Icons.movie_outlined,
      typeColor: const Color(0xFF4A90D9),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Row(
        children: [
          Container(
            width: 52, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: movie.posterPath != null && movie.posterPath!.isNotEmpty
                ? Image.file(File(movie.posterPath!), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 22, color: Color(0xFFCCCCCC)))
                : const Icon(Icons.movie, size: 22, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                if (movie.alternateTitles.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(movie.alternateTitles.take(2).join(' / '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
                const SizedBox(height: 6),
                _statusTag(movie.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    return _buildItemWrapper(
      typeLabel: '书籍',
      typeIcon: Icons.menu_book_outlined,
      typeColor: const Color(0xFF7E57C2),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: Row(
        children: [
          Container(
            width: 52, height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: book.coverPath != null && book.coverPath!.isNotEmpty
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 22, color: Color(0xFFCCCCCC)))
                : const Icon(Icons.book, size: 22, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                if (book.authors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(book.authors.take(2).join(' / '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
                const SizedBox(height: 6),
                _bookStatusTag(book.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    return _buildItemWrapper(
      typeLabel: '笔记',
      typeIcon: Icons.note_outlined,
      typeColor: const Color(0xFF66BB6A),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: note))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.summary.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.7),
          ),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: Text(tag, style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusTag(String status) {
    final (label, bg, fg) = switch (status) {
      'watched' => ('已看', const Color(0xFF1A1A1A), Colors.white),
      'watching' => ('在看', const Color(0xFFF0F0F0), const Color(0xFF666666)),
      'want_to_watch' => ('想看', const Color(0xFFF5F5F5), const Color(0xFF999999)),
      _ => ('未标记', const Color(0xFFF5F5F5), const Color(0xFFBBBBBB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _bookStatusTag(String status) {
    final (label, bg, fg) = switch (status) {
      'read' => ('已读', const Color(0xFF1A1A1A), Colors.white),
      'reading' => ('在读', const Color(0xFFF0F0F0), const Color(0xFF666666)),
      'want_to_read' => ('想读', const Color(0xFFF5F5F5), const Color(0xFF999999)),
      _ => ('未标记', const Color(0xFFF5F5F5), const Color(0xFFBBBBBB)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SearchResult {
  final String type; // movie, book, note
  final dynamic data;

  _SearchResult({required this.type, required this.data});
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';

/// 搜索页面
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  int _selectedType = 0; // 0: 影视, 1: 书籍, 2: 笔记
  List<dynamic> _results = [];
  bool _isSearching = false;
  String? _selectedTag; // 选中的标签

  final List<String> _typeLabels = ['影视', '书籍', '笔记'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final keyword = _searchController.text.trim();
    // 笔记搜索允许空关键词（用于标签筛选）
    if (keyword.isEmpty && _selectedType != 2 && _selectedTag == null) return;

    setState(() => _isSearching = true);

    try {
      List<dynamic> results;
      final provider = context.read<AppProvider>();

      switch (_selectedType) {
        case 0: // 影视
          results = provider.movies.where((movie) {
            return _matchMovie(movie, keyword);
          }).toList();
          break;
        case 1: // 书籍
          results = provider.books.where((book) {
            return _matchBook(book, keyword);
          }).toList();
          break;
        case 2: // 笔记
          results = provider.notes.where((note) {
            return _matchNote(note, keyword);
          }).toList();
          break;
        default:
          results = [];
      }

      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ToastUtil.show(context, '搜索失败: $e');
    }
  }

  bool _matchMovie(Movie movie, String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return movie.title.toLowerCase().contains(lowerKeyword) ||
        movie.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
        (movie.summary?.toLowerCase().contains(lowerKeyword) ?? false);
  }

  bool _matchBook(Book book, String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return book.title.toLowerCase().contains(lowerKeyword) ||
        book.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)) ||
        (book.summary?.toLowerCase().contains(lowerKeyword) ?? false);
  }

  bool _matchNote(Note note, String keyword) {
    // 如果有选中的标签，先按标签筛选
    if (_selectedTag != null) {
      if (!note.tags.contains(_selectedTag)) {
        return false;
      }
    }
    // 关键词为空时，只按标签筛选
    if (keyword.isEmpty) {
      return true;
    }
    // 按内容搜索
    return note.content.toLowerCase().contains(keyword.toLowerCase());
  }

  /// 构建标签筛选区域
  Widget _buildTagFilter() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final allTags = <String>{};
        for (final note in provider.notes.where((n) => !n.isDeleted)) {
          allTags.addAll(note.tags);
        }
        
        if (allTags.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final tags = allTags.toList()..sort();
        
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 16,
                      color: Color(0xFF999999),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '按标签筛选',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                children: tags.map((tag) => GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedTag == tag) {
                        _selectedTag = null;
                      } else {
                        _selectedTag = tag;
                      }
                      _performSearch();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selectedTag == tag 
                          ? const Color(0xFF1A1A1A) 
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedTag == tag 
                            ? const Color(0xFF1A1A1A) 
                            : const Color(0xFFE8E8E8),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedTag == tag ? FontWeight.w600 : FontWeight.w500,
                        color: _selectedTag == tag 
                            ? Colors.white 
                            : const Color(0xFF666666),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索类型选择
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
              ),
            ),
            child: Row(
              children: List.generate(_typeLabels.length, (index) {
                final isSelected = _selectedType == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = index;
                      _results = [];
                      _selectedTag = null;
                    });
                    _searchController.clear();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      _typeLabels[index],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF666666),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 搜索输入框
          Container(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: _getSearchHint(),
                hintStyle: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 14,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.search, color: Color(0xFF666666), size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF999999)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _results = []);
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // 笔记标签筛选（仅在笔记搜索时显示）
          if (_selectedType == 2) _buildTagFilter(),

          // 搜索结果
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? _buildEmptyState()
                    : _buildResultList(),
          ),
        ],
      ),
    );
  }

  String _getSearchHint() {
    switch (_selectedType) {
      case 0:
        return '搜索影视名称、别名、简介...';
      case 1:
        return '搜索书籍名称、别名、简介...';
      case 2:
        return '搜索笔记内容...';
      default:
        return '请输入搜索关键词';
    }
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isEmpty && _selectedTag == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search,
                size: 40,
                color: Color(0xFFCCCCCC),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '输入关键词开始搜索',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.search_off,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '未找到相关内容',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试更换关键词或标签',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFFBBBBBB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        if (item is Movie) {
          return _buildMovieItem(item);
        } else if (item is Book) {
          return _buildBookItem(item);
        } else if (item is Note) {
          return _buildNoteItem(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMovieItem(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailPage(movie: movie),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Row(
          children: [
            // 海报
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: movie.posterPath != null
                  ? Image.file(
                      File(movie.posterPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: Color(0xFFCCCCCC)),
                    )
                  : const Icon(Icons.movie, color: Color(0xFFCCCCCC)),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (movie.alternateTitles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      movie.alternateTitles.join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildStatusTag(movie.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailPage(book: book),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Row(
          children: [
            // 封面
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverPath != null
                  ? Image.file(
                      File(book.coverPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book, color: Color(0xFFCCCCCC)),
                    )
                  : const Icon(Icons.book, color: Color(0xFFCCCCCC)),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (book.alternateTitles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      book.alternateTitles.join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildBookStatusTag(book.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final isPlainText = note.contentType == 'plain_text';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteDetailPage(note: note),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：格式标记 + 时间
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                  ),
                  child: Text(
                    isPlainText ? 'TXT' : 'MD',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${note.createdAt.year}.${note.createdAt.month.toString().padLeft(2, '0')}.${note.createdAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
                const Spacer(),
                // 图片数量（如果有图片）
                if (note.images.isNotEmpty) ...[
                  const Icon(
                    Icons.image_outlined,
                    size: 14,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${note.images.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 内容
            Text(
              note.summary.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.6,
              ),
            ),
            // 标签
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: note.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    String label;
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'watched':
        label = '已看';
        bgColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        break;
      case 'watching':
        label = '在看';
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF666666);
        break;
      case 'want_to_watch':
        label = '想看';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        bgColor = const Color(0xFFEEEEEE);
        textColor = const Color(0xFFCCCCCC);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildBookStatusTag(String status) {
    String label;
    Color bgColor;
    Color textColor;
    switch (status) {
      case 'read':
        label = '已读';
        bgColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        break;
      case 'reading':
        label = '在读';
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF666666);
        break;
      case 'want_to_read':
        label = '想读';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        bgColor = const Color(0xFFEEEEEE);
        textColor = const Color(0xFFCCCCCC);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}



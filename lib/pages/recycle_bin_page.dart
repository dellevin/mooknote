import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';

/// 回收站页面
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends State<RecycleBinPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Movie> _deletedMovies = [];
  List<Book> _deletedBooks = [];
  List<Note> _deletedNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDeletedItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final movies = await provider.getDeletedMovies();
    final books = await provider.getDeletedBooks();
    final notes = await provider.getDeletedNotes();
    setState(() {
      _deletedMovies = movies;
      _deletedBooks = books;
      _deletedNotes = notes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('回收站'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF999999),
          indicatorColor: const Color(0xFF1A1A1A),
          tabs: [
            Tab(text: '影视 (${_deletedMovies.length})'),
            Tab(text: '书籍 (${_deletedBooks.length})'),
            Tab(text: '笔记 (${_deletedNotes.length})'),
          ],
        ),
        actions: [
          // 清空全部
          TextButton(
            onPressed: _showClearAllDialog,
            child: const Text(
              '清空',
              style: TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMovieList(),
                _buildBookList(),
                _buildNoteList(),
              ],
            ),
    );
  }

  /// 影视列表
  Widget _buildMovieList() {
    if (_deletedMovies.isEmpty) {
      return _buildEmptyState('暂无删除的影视');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedMovies.length,
      itemBuilder: (context, index) {
        final movie = _deletedMovies[index];
        return _buildDeletedItemCard(
          title: movie.title,
          subtitle: '删除于 ${_formatDate(movie.updatedAt)}',
          onRestore: () => _restoreMovie(movie),
          onDelete: () => _permanentDeleteMovie(movie),
        );
      },
    );
  }

  /// 书籍列表
  Widget _buildBookList() {
    if (_deletedBooks.isEmpty) {
      return _buildEmptyState('暂无删除的书籍');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedBooks.length,
      itemBuilder: (context, index) {
        final book = _deletedBooks[index];
        return _buildDeletedItemCard(
          title: book.title,
          subtitle: '删除于 ${_formatDate(book.updatedAt)}',
          onRestore: () => _restoreBook(book),
          onDelete: () => _permanentDeleteBook(book),
        );
      },
    );
  }

  /// 笔记列表
  Widget _buildNoteList() {
    if (_deletedNotes.isEmpty) {
      return _buildEmptyState('暂无删除的笔记');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedNotes.length,
      itemBuilder: (context, index) {
        final note = _deletedNotes[index];
        return _buildDeletedItemCard(
          title: note.summary,
          subtitle: '删除于 ${_formatDate(note.updatedAt)}',
          onRestore: () => _restoreNote(note),
          onDelete: () => _permanentDeleteNote(note),
        );
      },
    );
  }

  /// 构建已删除项卡片
  Widget _buildDeletedItemCard({
    required String title,
    required String subtitle,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 恢复按钮
              OutlinedButton(
                onPressed: onRestore,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1A1A1A),
                  side: const BorderSide(color: Color(0xFF1A1A1A)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('恢复'),
              ),
              const SizedBox(width: 12),
              // 彻底删除按钮
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('彻底删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_outline,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  /// 恢复影视
  Future<void> _restoreMovie(Movie movie) async {
    await context.read<AppProvider>().restoreMovie(movie.id);
    _loadDeletedItems();
    if (mounted) {
      ToastUtil.show(context, '影视已恢复');
    }
  }

  /// 彻底删除影视
  Future<void> _permanentDeleteMovie(Movie movie) async {
    final confirmed = await _showConfirmDialog('确定要彻底删除这部影视吗？此操作不可恢复。');
    if (confirmed) {
      await context.read<AppProvider>().permanentDeleteMovie(movie.id);
      _loadDeletedItems();
      if (mounted) {
        ToastUtil.show(context, '已彻底删除');
      }
    }
  }

  /// 恢复书籍
  Future<void> _restoreBook(Book book) async {
    await context.read<AppProvider>().restoreBook(book.id);
    _loadDeletedItems();
    if (mounted) {
      ToastUtil.show(context, '书籍已恢复');
    }
  }

  /// 彻底删除书籍
  Future<void> _permanentDeleteBook(Book book) async {
    final confirmed = await _showConfirmDialog('确定要彻底删除这本书籍吗？此操作不可恢复。');
    if (confirmed) {
      await context.read<AppProvider>().permanentDeleteBook(book.id);
      _loadDeletedItems();
      if (mounted) {
        ToastUtil.show(context, '已彻底删除');
      }
    }
  }

  /// 恢复笔记
  Future<void> _restoreNote(Note note) async {
    await context.read<AppProvider>().restoreNote(note.id);
    _loadDeletedItems();
    if (mounted) {
      ToastUtil.show(context, '笔记已恢复');
    }
  }

  /// 彻底删除笔记
  Future<void> _permanentDeleteNote(Note note) async {
    final confirmed = await _showConfirmDialog('确定要彻底删除这条笔记吗？此操作不可恢复。');
    if (confirmed) {
      await context.read<AppProvider>().permanentDeleteNote(note.id);
      _loadDeletedItems();
      if (mounted) {
        ToastUtil.show(context, '已彻底删除');
      }
    }
  }

  /// 显示确认对话框
  Future<bool> _showConfirmDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示清空全部对话框
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('清空回收站'),
        content: const Text('确定要清空回收站吗？所有项目将被彻底删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppProvider>().clearRecycleBin();
              _loadDeletedItems();
              if (mounted) {
                ToastUtil.show(context, '回收站已清空');
              }
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

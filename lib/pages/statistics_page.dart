import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 数据统计页面 - 多维度数据分析
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('数据统计'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final movies = provider.movies;
          final books = provider.books;
          final notes = provider.notes;

          return _buildOverviewTab(movies, books, notes);
        },
      ),
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab(List<Movie> movies, List<Book> books, List<Note> notes) {
    final totalMovies = movies.length;
    final totalBooks = books.length;
    final totalNotes = notes.length;
    
    final watchedMovies = movies.where((m) => m.status == 'watched').length;
    final watchingMovies = movies.where((m) => m.status == 'watching').length;
    final wantToWatchMovies = movies.where((m) => m.status == 'want_to_watch').length;
    
    final readBooks = books.where((b) => b.status == 'read').length;
    final readingBooks = books.where((b) => b.status == 'reading').length;
    final wantToReadBooks = books.where((b) => b.status == 'want_to_read').length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 总数据卡片
        _buildSectionTitle('数据总览'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard('影视', totalMovies, Icons.movie_outlined, const Color(0xFF1A1A1A))),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('书籍', totalBooks, Icons.menu_book_outlined, const Color(0xFF666666))),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('笔记', totalNotes, Icons.note_outlined, const Color(0xFF999999))),
          ],
        ),
        const SizedBox(height: 32),
        
        // 影视状态分布
        _buildSectionTitle('影视状态分布'),
        const SizedBox(height: 16),
        _buildStatusDistribution([
          _StatusData('已看', watchedMovies, const Color(0xFF1A1A1A)),
          _StatusData('在看', watchingMovies, const Color(0xFF666666)),
          _StatusData('想看', wantToWatchMovies, const Color(0xFF999999)),
        ]),
        const SizedBox(height: 32),
        
        // 书籍状态分布
        _buildSectionTitle('书籍状态分布'),
        const SizedBox(height: 16),
        _buildStatusDistribution([
          _StatusData('已读', readBooks, const Color(0xFF1A1A1A)),
          _StatusData('在读', readingBooks, const Color(0xFF666666)),
          _StatusData('想读', wantToReadBooks, const Color(0xFF999999)),
        ]),
        const SizedBox(height: 32),
        
        // 最近活动
        _buildSectionTitle('最近7天活动'),
        const SizedBox(height: 16),
        _buildRecentActivity(movies, books, notes),
      ],
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  /// 构建状态分布
  Widget _buildStatusDistribution(List<_StatusData> data) {
    final total = data.fold(0, (sum, item) => sum + item.count);
    
    return Column(
      children: data.map((item) {
        final percentage = total > 0 ? (item.count / total * 100).toStringAsFixed(1) : '0';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: item.color),
              ),
              const SizedBox(width: 12),
              Text(item.label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '${item.count} ($percentage%)',
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 构建最近活动
  Widget _buildRecentActivity(List<Movie> movies, List<Book> books, List<Note> notes) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final recentMovies = movies.where((m) => m.createdAt.isAfter(sevenDaysAgo)).length;
    final recentBooks = books.where((b) => b.createdAt.isAfter(sevenDaysAgo)).length;
    final recentNotes = notes.where((n) => n.createdAt.isAfter(sevenDaysAgo)).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          _buildActivityRow('新增影视', recentMovies, Icons.movie_outlined),
          const Divider(height: 24),
          _buildActivityRow('新增书籍', recentBooks, Icons.menu_book_outlined),
          const Divider(height: 24),
          _buildActivityRow('新增笔记', recentNotes, Icons.note_outlined),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String label, int count, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF666666)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          '$count 个',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}

/// 状态数据
class _StatusData {
  final String label;
  final int count;
  final Color color;
  
  _StatusData(this.label, this.count, this.color);
}



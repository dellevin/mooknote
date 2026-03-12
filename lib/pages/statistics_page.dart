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
  int _selectedTab = 0;

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

          return Column(
            children: [
              // 标签切换栏
              _buildTabBar(),
              // 内容区域
              Expanded(
                child: _selectedTab == 0
                    ? _buildOverviewTab(movies, books, notes)
                    : _buildTrendTab(movies, books, notes),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem('概览', 0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabItem('趋势', 1),
          ),
        ],
      ),
    );
  }

  /// 构建标签项
  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF666666),
          ),
        ),
      ),
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab(List<Movie> movies, List<Book> books, List<Note> notes) {
    final totalMovies = movies.where((m) => !m.isDeleted).length;
    final totalBooks = books.length;
    final totalNotes = notes.length;
    
    final watchedMovies = movies.where((m) => m.status == 'watched' && !m.isDeleted).length;
    final watchingMovies = movies.where((m) => m.status == 'watching' && !m.isDeleted).length;
    final wantToWatchMovies = movies.where((m) => m.status == 'want_to_watch' && !m.isDeleted).length;
    
    final readBooks = books.where((b) => b.status == 'read').length;
    final readingBooks = books.where((b) => b.status == 'reading').length;
    final wantToReadBooks = books.where((b) => b.status == 'want_to_read').length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 总数据卡片
        _buildSectionTitle('数据总览'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: _buildStatItem('影视', totalMovies, Icons.movie_outlined)),
              Expanded(child: _buildStatItem('书籍', totalBooks, Icons.menu_book_outlined)),
              Expanded(child: _buildStatItem('笔记', totalNotes, Icons.note_outlined)),
            ],
          ),
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

  /// 趋势标签页
  Widget _buildTrendTab(List<Movie> movies, List<Book> books, List<Note> notes) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    // 生成最近30天的日期列表
    final dates = List.generate(30, (index) {
      return now.subtract(Duration(days: 29 - index));
    });
    
    // 计算每天的新增数量
    final movieTrend = dates.map((date) {
      return movies.where((m) {
        final created = m.createdAt;
        return created.year == date.year && 
               created.month == date.month && 
               created.day == date.day &&
               !m.isDeleted;
      }).length;
    }).toList();
    
    final bookTrend = dates.map((date) {
      return books.where((b) {
        final created = b.createdAt;
        return created.year == date.year && 
               created.month == date.month && 
               created.day == date.day;
      }).length;
    }).toList();
    
    final noteTrend = dates.map((date) {
      return notes.where((n) {
        final created = n.createdAt;
        return created.year == date.year && 
               created.month == date.month && 
               created.day == date.day;
      }).length;
    }).toList();
    
    // 计算总数
    final totalMovies = movieTrend.reduce((a, b) => a + b);
    final totalBooks = bookTrend.reduce((a, b) => a + b);
    final totalNotes = noteTrend.reduce((a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 30天统计摘要
        _buildSectionTitle('近30天新增'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTrendSummary('影视', totalMovies)),
              Expanded(child: _buildTrendSummary('书籍', totalBooks)),
              Expanded(child: _buildTrendSummary('笔记', totalNotes)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // 趋势说明
        _buildSectionTitle('数据趋势'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildTrendRow('影视', movieTrend, const Color(0xFF1A1A1A)),
              const SizedBox(height: 16),
              _buildTrendRow('书籍', bookTrend, const Color(0xFF666666)),
              const SizedBox(height: 16),
              _buildTrendRow('笔记', noteTrend, const Color(0xFF999999)),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建趋势摘要项
  Widget _buildTrendSummary(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  /// 构建趋势行
  Widget _buildTrendRow(String label, List<int> data, Color color) {
    final maxValue = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1 : maxValue;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((value) {
              final height = value / safeMax * 40;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: height < 2 ? 2 : height,
                  decoration: BoxDecoration(
                    color: color.withOpacity(value == 0 ? 0.1 : 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// 构建统计项
  Widget _buildStatItem(String title, int count, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF666666)),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  /// 构建状态分布
  Widget _buildStatusDistribution(List<_StatusData> data) {
    final total = data.fold(0, (sum, item) => sum + item.count);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: data.map((item) {
          final percentage = total > 0 ? (item.count / total * 100).toStringAsFixed(1) : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Text(
                  '${item.count}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($percentage%)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建最近活动
  Widget _buildRecentActivity(List<Movie> movies, List<Book> books, List<Note> notes) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final recentMovies = movies.where((m) => m.createdAt.isAfter(sevenDaysAgo) && !m.isDeleted).length;
    final recentBooks = books.where((b) => b.createdAt.isAfter(sevenDaysAgo)).length;
    final recentNotes = notes.where((n) => n.createdAt.isAfter(sevenDaysAgo)).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildActivityRow('新增影视', recentMovies, Icons.movie_outlined),
          const Divider(height: 20, color: Color(0xFFE8E8E8)),
          _buildActivityRow('新增书籍', recentBooks, Icons.menu_book_outlined),
          const Divider(height: 20, color: Color(0xFFE8E8E8)),
          _buildActivityRow('新增笔记', recentNotes, Icons.note_outlined),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String label, int count, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF666666)),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '个',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
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



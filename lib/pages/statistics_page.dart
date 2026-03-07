import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 数据统计页面 - 多维度数据分析
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('数据统计'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '概览'),
              Tab(text: '日历'),
              Tab(text: '趋势'),
            ],
            labelColor: const Color(0xFF1A1A1A),
            unselectedLabelColor: const Color(0xFF999999),
            indicatorColor: const Color(0xFF1A1A1A),
          ),
        ),
        body: Consumer<AppProvider>(
          builder: (context, provider, child) {
            final movies = provider.movies;
            final books = provider.books;
            final notes = provider.notes;

            return TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(movies, books, notes),
                _buildCalendarTab(movies, books, notes),
                _buildTrendTab(movies, books, notes),
              ],
            );
          },
        ),
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

  /// 日历标签页
  Widget _buildCalendarTab(List<Movie> movies, List<Book> books, List<Note> notes) {
    // 合并所有数据按日期
    final Map<DateTime, _DailyData> dailyData = {};
    
    for (final movie in movies) {
      final date = DateTime(movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
      dailyData.putIfAbsent(date, () => _DailyData()).movies++;
    }
    
    for (final book in books) {
      final date = DateTime(book.createdAt.year, book.createdAt.month, book.createdAt.day);
      dailyData.putIfAbsent(date, () => _DailyData()).books++;
    }
    
    for (final note in notes) {
      final date = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
      dailyData.putIfAbsent(date, () => _DailyData()).notes++;
    }

    return Column(
      children: [
        // 月份选择器
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
              ),
              Text(
                '${_selectedMonth.year}年${_selectedMonth.month}月',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),
        
        // 热力图图例
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('少', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              const SizedBox(width: 8),
              ...List.generate(4, (index) {
                final opacity = 0.2 + (index * 0.2);
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A).withOpacity(opacity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 8),
              const Text('多', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // 日历热力图
        Expanded(
          child: _buildHeatMapCalendar(dailyData),
        ),
      ],
    );
  }

  /// 趋势标签页
  Widget _buildTrendTab(List<Movie> movies, List<Book> books, List<Note> notes) {
    // 近30天每日新增数据
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 29));
    
    final List<_DailyTrend> movieTrend = [];
    final List<_DailyTrend> bookTrend = [];
    final List<_DailyTrend> noteTrend = [];
    
    for (int i = 0; i < 30; i++) {
      final date = DateTime(thirtyDaysAgo.year, thirtyDaysAgo.month, thirtyDaysAgo.day + i);
      
      final movieCount = movies.where((m) {
        final mDate = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
        return mDate.isAtSameMomentAs(date);
      }).length;
      
      final bookCount = books.where((b) {
        final bDate = DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
        return bDate.isAtSameMomentAs(date);
      }).length;
      
      final noteCount = notes.where((n) {
        final nDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
        return nDate.isAtSameMomentAs(date);
      }).length;
      
      movieTrend.add(_DailyTrend(date, movieCount));
      bookTrend.add(_DailyTrend(date, bookCount));
      noteTrend.add(_DailyTrend(date, noteCount));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('近30天新增趋势'),
        const SizedBox(height: 8),
        const Text(
          '每日新增数据统计',
          style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 24),
        
        // 折线图
        SizedBox(
          height: 250,
          child: _buildLineChart(movieTrend, bookTrend, noteTrend),
        ),
        const SizedBox(height: 32),
        
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('影视', const Color(0xFFE53935)),
            const SizedBox(width: 24),
            _buildLegendItem('书籍', const Color(0xFF1E88E5)),
            const SizedBox(width: 24),
            _buildLegendItem('笔记', const Color(0xFF43A047)),
          ],
        ),
        const SizedBox(height: 32),
        
        // 近7天统计
        _buildSectionTitle('近7天新增统计'),
        const SizedBox(height: 16),
        _buildWeeklyStats(movieTrend.sublist(23), bookTrend.sublist(23), noteTrend.sublist(23)),
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

  /// 构建热力图日历
  Widget _buildHeatMapCalendar(Map<DateTime, _DailyData> dailyData) {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    
    // 计算最大数量用于颜色强度
    int maxCount = 0;
    for (final data in dailyData.values) {
      final count = data.total;
      if (count > maxCount) maxCount = count;
    }
    if (maxCount == 0) maxCount = 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // 星期标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['日', '一', '二', '三', '四', '五', '六']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // 日历网格
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 空白填充
              ...List.generate(firstWeekday, (_) => const SizedBox(width: 36, height: 36)),
              
              // 日期
              ...List.generate(daysInMonth, (index) {
                final day = index + 1;
                final date = DateTime(year, month, day);
                final data = dailyData[date];
                final count = data?.total ?? 0;
                
                // 计算颜色强度
                double opacity = 0.1;
                if (count > 0) {
                  opacity = 0.3 + (count / maxCount * 0.7);
                  opacity = opacity.clamp(0.3, 1.0);
                }
                
                return GestureDetector(
                  onTap: () {
                    if (count > 0) {
                      _showDayDetail(context, date, data!);
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: count > 0 
                          ? const Color(0xFF1A1A1A).withOpacity(opacity)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: count > 0 ? Colors.white : const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// 显示某天详情
  void _showDayDetail(BuildContext context, DateTime date, _DailyData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.year}年${date.month}月${date.day}日',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (data.movies > 0)
              _buildDetailRow(Icons.movie_outlined, '影视', data.movies),
            if (data.books > 0)
              _buildDetailRow(Icons.menu_book_outlined, '书籍', data.books),
            if (data.notes > 0)
              _buildDetailRow(Icons.note_outlined, '笔记', data.notes),
            const SizedBox(height: 16),
            Text(
              '总计: ${data.total} 项',
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF666666)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text('$count 个', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// 构建折线图
  Widget _buildLineChart(List<_DailyTrend> movieTrend, List<_DailyTrend> bookTrend, List<_DailyTrend> noteTrend) {
    final spotsMovie = movieTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.count.toDouble());
    }).toList();
    
    final spotsBook = bookTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.count.toDouble());
    }).toList();
    
    final spotsNote = noteTrend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.count.toDouble());
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5E5E5),
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < movieTrend.length) {
                  final date = movieTrend[value.toInt()].date;
                  return Text(
                    '${date.month}/${date.day}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // 影视折线 - 红色
          LineChartBarData(
            spots: spotsMovie,
            isCurved: true,
            color: const Color(0xFFE53935),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFE53935).withOpacity(0.1),
            ),
          ),
          // 书籍折线 - 蓝色
          LineChartBarData(
            spots: spotsBook,
            isCurved: true,
            color: const Color(0xFF1E88E5),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1E88E5).withOpacity(0.1),
            ),
          ),
          // 笔记折线 - 绿色
          LineChartBarData(
            spots: spotsNote,
            isCurved: true,
            color: const Color(0xFF43A047),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF43A047).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图例项
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(color: color),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
      ],
    );
  }

  /// 构建近7天统计
  Widget _buildWeeklyStats(List<_DailyTrend> movieTrend, List<_DailyTrend> bookTrend, List<_DailyTrend> noteTrend) {
    final totalMovies = movieTrend.fold(0, (sum, item) => sum + item.count);
    final totalBooks = bookTrend.fold(0, (sum, item) => sum + item.count);
    final totalNotes = noteTrend.fold(0, (sum, item) => sum + item.count);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          _buildWeeklyRow('影视新增', totalMovies, const Color(0xFFE53935)),
          const Divider(height: 24),
          _buildWeeklyRow('书籍新增', totalBooks, const Color(0xFF1E88E5)),
          const Divider(height: 24),
          _buildWeeklyRow('笔记新增', totalNotes, const Color(0xFF43A047)),
          const Divider(height: 24),
          _buildWeeklyRow('总计', totalMovies + totalBooks + totalNotes, const Color(0xFF1A1A1A), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildWeeklyRow(String label, int count, Color color, {bool isTotal = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          '$count 个',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
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

/// 每日数据
class _DailyData {
  int movies = 0;
  int books = 0;
  int notes = 0;
  
  int get total => movies + books + notes;
}

/// 每日趋势
class _DailyTrend {
  final DateTime date;
  final int count;
  
  _DailyTrend(this.date, this.count);
}

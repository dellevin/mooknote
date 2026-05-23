import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../models/data_models.dart';
import '../pages/stroll_page.dart';
import '../pages/markdown_reader/md_reader_tab_page.dart';
import '../pages/tag_management_page.dart';

/// 自定义左侧弹出菜单 - 极简主义设计
class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _version = '0.1.5';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 顶部用户信息（头像左，名称/座右铭右）
              _buildHeader(context),

              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

              // 2. 统计数据
              _buildStatsSection(context),

              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

              // 3. 热力图
              _buildCalendarSection(context),

              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

              // 4. 回顾信息
              _buildMemorySection(context),

              const Divider(
                  height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

              // 5. 功能模块：漫步 / Markdown 阅读
              _buildToolsSection(context),

              // 底部版本号
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'MookNote v$_version',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. 构建头部 - 头像左侧，名称/座右铭右侧
  Widget _buildHeader(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final userPrefs = UserPrefs();
        final nickname = userPrefs.nickname;
        final motto = userPrefs.motto;
        final avatarPath = userPrefs.avatarPath;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Row(
            children: [
              // 左侧：头像
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF5F5F5),
                  border:
                      Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarPath != null && avatarPath.isNotEmpty
                    ? Image.file(
                        File(avatarPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                      )
                    : _buildAvatarPlaceholder(),
              ),

              const SizedBox(width: 16),

              // 右侧：名称 + 座右铭
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nickname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      motto,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(Icons.person_outline, size: 28, color: Color(0xFFAAAAAA)),
    );
  }

  /// 2. 统计数据：观影xxx  阅读xxx  笔记xxx
  Widget _buildStatsSection(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              _buildStatItem('观影', movieCount),
              const SizedBox(width: 32),
              _buildStatItem('阅读', bookCount),
              const SizedBox(width: 32),
              _buildStatItem('笔记', noteCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }

  /// 5. 功能模块：漫步 / Markdown 阅读
  Widget _buildToolsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 漫步
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StrollPage()),
                );
              },
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.explore_outlined,
                        size: 18, color: Color(0xFF666666)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '漫步',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    Text(
                      '随机发现一条内容',
                      style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFFCCCCCC)),
                  ],
                ),
              ),
            ),

            // 分隔线
            const Divider(
                height: 0.5, thickness: 0.5, color: Color(0xFFEEEEEE)),

            // 标签管理
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TagManagementPage()),
                );
              },
              borderRadius: BorderRadius.zero,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.label_outline,
                        size: 18, color: Color(0xFF666666)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '标签管理',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    Text(
                      '管理标签',
                      style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFFCCCCCC)),
                  ],
                ),
              ),
            ),

            // 分隔线
            const Divider(
                height: 0.5, thickness: 0.5, color: Color(0xFFEEEEEE)),

            // Markdown 阅读
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MdReaderTabPage()),
                );
              },
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 18, color: Color(0xFF666666)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'MD阅读',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    Text(
                      '浏览本地 md 文件',
                      style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFFCCCCCC)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final Map<DateTime, int> dailyCounts = {};

        for (final movie in provider.movies.where((m) => !m.isDeleted)) {
          final date = DateTime(
              movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }
        for (final book in provider.books.where((b) => !b.isDeleted)) {
          final date = DateTime(
              book.createdAt.year, book.createdAt.month, book.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }
        for (final note in provider.notes.where((n) => !n.isDeleted)) {
          final date = DateTime(
              note.createdAt.year, note.createdAt.month, note.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }

        // 计算最大计数用于颜色映射
        int maxCount = 0;
        for (final c in dailyCounts.values) {
          if (c > maxCount) maxCount = c;
        }
        if (maxCount == 0) maxCount = 1;

        // 从上周日开始，往前推 N 周
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysSinceSunday = today.weekday % 7; // Sunday=0
        final lastSunday = today.subtract(Duration(days: daysSinceSunday));

        const totalWeeks = 20;
        const weekDays = 7;
        const cellSize = 13.0;
        const cellGap = 3.0;

        // 构建网格：行=星期几(0=日..6=六)，列=周(0=最旧..19=最新)
        final cells =
            List.generate(weekDays, (_) => List.generate(totalWeeks, (_) => 0));

        for (int week = 0; week < totalWeeks; week++) {
          for (int day = 0; day < weekDays; day++) {
            final date = lastSunday.subtract(
                Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
            cells[day][week] = dailyCounts[date] ?? 0;
          }
        }

        // 月份标签：找出每个月第一天所在的列
        final monthLabels = <int, String>{};
        for (int week = 0; week < totalWeeks; week++) {
          final date =
              lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7));
          final key = date.month;
          if (!monthLabels.containsKey(key) || date.day <= 7) {
            monthLabels[week] = '${date.month}月';
          }
        }

        // 只保留首、中间、尾三个月份标签
        final sortedWeeks = monthLabels.keys.toList()..sort();
        final keepWeeks = <int>{
          sortedWeeks.first,
          sortedWeeks[sortedWeeks.length ~/ 2],
          sortedWeeks.last,
        };

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Color(0xFF999999)),
                  SizedBox(width: 8),
                  Text(
                    '热力图',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 热力图主体
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 月份标签行
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: List.generate(totalWeeks, (week) {
                          final label = keepWeeks.contains(week)
                              ? monthLabels[week]
                              : null;
                          return SizedBox(
                            width: cellSize + cellGap,
                            child: label != null
                                ? Text(label,
                                    style: const TextStyle(
                                        fontSize: 9, color: Color(0xFFBBBBBB)))
                                : null,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // 日期网格行
                    ...List.generate(weekDays, (day) {
                      return Row(
                        children: List.generate(totalWeeks, (week) {
                          final count = cells[day][week];
                          final color = _heatmapColor(count, maxCount);
                          return Container(
                            width: cellSize,
                            height: cellSize,
                            margin: EdgeInsets.only(
                              right: week < totalWeeks - 1 ? cellGap : 0,
                              bottom: day < weekDays - 1 ? cellGap : 0,
                            ),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    }),
                  ],
                ),
              ),

              // 图例
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('少',
                      style: TextStyle(fontSize: 9, color: Color(0xFFBBBBBB))),
                  const SizedBox(width: 3),
                  _legendCell(const Color(0xFFF0F0F0)),
                  _legendCell(const Color(0xFFC8E6C9)),
                  _legendCell(const Color(0xFF66BB6A)),
                  _legendCell(const Color(0xFF2E7D32)),
                  _legendCell(const Color(0xFF1B5E20)),
                  const SizedBox(width: 3),
                  const Text('多',
                      style: TextStyle(fontSize: 9, color: Color(0xFFBBBBBB))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _heatmapColor(int count, int maxCount) {
    if (count == 0) return const Color(0xFFF0F0F0);
    final ratio = count / maxCount;
    if (ratio <= 0.25) return const Color(0xFFC8E6C9);
    if (ratio <= 0.50) return const Color(0xFF66BB6A);
    if (ratio <= 0.75) return const Color(0xFF2E7D32);
    return const Color(0xFF1B5E20);
  }

  Widget _legendCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  /// 4. 回顾信息
  Widget _buildMemorySection(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final memoryItem = _getRandomMemoryItem(provider);

        if (memoryItem == null) {
          return const SizedBox.shrink();
        }

        final memoryText = _buildMemoryText(memoryItem);
        final timeAgo = _getTimeAgoText(memoryItem.date);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  const Icon(Icons.history, size: 14, color: Color(0xFF999999)),
                  const SizedBox(width: 8),
                  const Text(
                    '回顾',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 内容卡片
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头图
                  if (memoryItem.imagePath != null &&
                      memoryItem.imagePath!.isNotEmpty)
                    Container(
                      width: 56,
                      height: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(memoryItem.imagePath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image, color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    )
                  else if (memoryItem.type != 'note')
                    Container(
                      width: 56,
                      height: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        memoryItem.type == 'movie'
                            ? Icons.movie
                            : Icons.menu_book,
                        color: const Color(0xFFCCCCCC),
                        size: 22,
                      ),
                    ),

                  // 文字
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timeAgo,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF999999)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          memoryText,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                              height: 1.5),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  _MemoryItem? _getRandomMemoryItem(AppProvider provider) {
    final now = DateTime.now();
    final candidates = <_MemoryItem>[];

    for (final movie in provider.movies.where((m) => !m.isDeleted)) {
      candidates.add(_MemoryItem(
        type: 'movie',
        title: movie.title,
        date: movie.createdAt,
        imagePath: movie.posterPath,
      ));
    }

    for (final book in provider.books.where((b) => !b.isDeleted)) {
      candidates.add(_MemoryItem(
        type: 'book',
        title: book.title,
        date: book.createdAt,
        imagePath: book.coverPath,
      ));
    }

    if (candidates.isEmpty) return null;

    final oneMonthAgo = now.subtract(const Duration(days: 30));
    final threeMonthsAgo = now.subtract(const Duration(days: 90));
    final sixMonthsAgo = now.subtract(const Duration(days: 180));
    final oneYearAgo = now.subtract(const Duration(days: 365));

    final memoryCandidates = candidates.where((item) {
      return _isInTimeRange(
          item.date, oneMonthAgo, threeMonthsAgo, sixMonthsAgo, oneYearAgo);
    }).toList();

    final random = Random();
    final selectedList =
        memoryCandidates.isNotEmpty ? memoryCandidates : candidates;
    return selectedList[random.nextInt(selectedList.length)];
  }

  bool _isInTimeRange(DateTime date, DateTime oneMonth, DateTime threeMonths,
      DateTime sixMonths, DateTime oneYear) {
    if (_isCloseTo(date, oneMonth)) return true;
    if (_isCloseTo(date, threeMonths, days: 14)) return true;
    if (_isCloseTo(date, sixMonths, days: 30)) return true;
    if (_isCloseTo(date, oneYear, days: 30)) return true;
    return false;
  }

  bool _isCloseTo(DateTime date, DateTime target, {int days = 7}) {
    final diff = date.difference(target).inDays.abs();
    return diff <= days;
  }

  String _buildMemoryText(_MemoryItem item) {
    return '《${item.title}》';
  }

  String _getTimeAgoText(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays >= 365) return '1年前';
    if (diff.inDays >= 180) return '6个月前';
    if (diff.inDays >= 90) return '3个月前';
    if (diff.inDays >= 30) return '1个月前';
    return '${diff.inDays}天前';
  }
}

class _MemoryItem {
  final String type;
  final String title;
  final DateTime date;
  final String? imagePath;

  _MemoryItem({
    required this.type,
    required this.title,
    required this.date,
    this.imagePath,
  });
}

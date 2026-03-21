import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/toast_util.dart';
import '../models/data_models.dart';

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

  /// 加载版本信息
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
        child: Column(
          children: [
            // 顶部用户信息区域
            _buildHeader(context),
            
            const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
            
            // 可滚动区域 - 包含回顾、日历和菜单
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 回顾功能区域
                    _buildMemorySection(context),
                    
                    const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                    
                    // 日历热力图区域
                    _buildCalendarSection(context),
                    
                    const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                    
                    // 底部留白，避免内容被遮挡
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // 底部版本信息 - 固定在底部
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'MookNote v$_version',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建回顾功能区域
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
                  const Icon(
                    Icons.history,
                    size: 16,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '回顾',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // 内容卡片（带头图）
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头图（影视/书籍显示，笔记不显示）
                  if (memoryItem.imagePath != null && memoryItem.imagePath!.isNotEmpty)
                    Container(
                      width: 60,
                      height: 80,
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
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image,
                            color: Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
                    )
                  else if (memoryItem.type != 'note')
                    Container(
                      width: 60,
                      height: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        memoryItem.type == 'movie' ? Icons.movie : Icons.menu_book,
                        color: const Color(0xFFCCCCCC),
                        size: 24,
                      ),
                    ),
                  
                  // 文字内容
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 时间标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // 内容文字
                        Text(
                          memoryText,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1A1A),
                            height: 1.5,
                          ),
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

  /// 获取随机回顾项
  _MemoryItem? _getRandomMemoryItem(AppProvider provider) {
    final now = DateTime.now();
    final candidates = <_MemoryItem>[];
    
    // 收集所有未删除的影视、书籍（去掉笔记）
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
    
    // 优先选择1个月、3个月、6个月、1年前的数据
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    final threeMonthsAgo = now.subtract(const Duration(days: 90));
    final sixMonthsAgo = now.subtract(const Duration(days: 180));
    final oneYearAgo = now.subtract(const Duration(days: 365));
    
    final memoryCandidates = candidates.where((item) {
      return _isInTimeRange(item.date, oneMonthAgo, threeMonthsAgo, sixMonthsAgo, oneYearAgo);
    }).toList();
    
    // 如果有符合时间范围的，从中随机选择；否则从所有数据中随机选择
    final random = Random();
    final selectedList = memoryCandidates.isNotEmpty ? memoryCandidates : candidates;
    return selectedList[random.nextInt(selectedList.length)];
  }

  /// 检查时间是否在范围内（1月、3月、6月、1年前）
  bool _isInTimeRange(DateTime date, DateTime oneMonth, DateTime threeMonths, 
      DateTime sixMonths, DateTime oneYear) {
    // 检查是否在1个月前左右（±7天）
    if (_isCloseTo(date, oneMonth)) return true;
    // 检查是否在3个月前左右（±14天）
    if (_isCloseTo(date, threeMonths, days: 14)) return true;
    // 检查是否在6个月前左右（±30天）
    if (_isCloseTo(date, sixMonths, days: 30)) return true;
    // 检查是否在1年前左右（±30天）
    if (_isCloseTo(date, oneYear, days: 30)) return true;
    return false;
  }

  /// 检查两个日期是否接近
  bool _isCloseTo(DateTime date, DateTime target, {int days = 7}) {
    final diff = date.difference(target).inDays.abs();
    return diff <= days;
  }

  /// 构建回顾文本
  String _buildMemoryText(_MemoryItem item) {
    // 只显示标题，不添加描述前缀
    return '《${item.title}》';
  }

  /// 获取时间描述文本
  String _getTimeAgoText(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays >= 365) {
      return '1年前';
    } else if (diff.inDays >= 180) {
      return '6个月前';
    } else if (diff.inDays >= 90) {
      return '3个月前';
    } else if (diff.inDays >= 30) {
      return '1个月前';
    } else {
      return '${diff.inDays}天前';
    }
  }

  /// 构建头部
  Widget _buildHeader(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // 统计数据
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;
        
        // 获取用户信息
        final userPrefs = UserPrefs();
        final nickname = userPrefs.nickname;
        final motto = userPrefs.motto;
        final avatarPath = userPrefs.avatarPath;
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户头像
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
                ),
                child: avatarPath != null && avatarPath.isNotEmpty
                    ? ClipOval(
                        child: Image.file(
                          File(avatarPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                        ),
                      )
                    : _buildAvatarPlaceholder(),
              ),
              
              const SizedBox(height: 16),
              
              // 用户名称
              Text(
                nickname,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // 座右铭
              Text(
                motto,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 简化统计
              Row(
                children: [
                  _buildStatItem('观影', movieCount),
                  const SizedBox(width: 24),
                  _buildStatItem('阅读', bookCount),
                  const SizedBox(width: 24),
                  _buildStatItem('笔记', noteCount),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(
        Icons.person_outline,
        size: 32,
        color: Color(0xFF999999),
      ),
    );
  }

  /// 统计项
  Widget _buildStatItem(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  /// 菜单项
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, size: 22, color: const Color(0xFF666666)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A1A),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: Color(0xFFCCCCCC),
      ),
      onTap: onTap,
    );
  }

  /// 显示提示
  void _showToast(BuildContext context, String message) {
    ToastUtil.show(context, message);
  }

  /// 构建日历热力图区域
  Widget _buildCalendarSection(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Consumer<AppProvider>(
          builder: (context, provider, child) {
            // 使用 StatefulBuilder 的状态来管理选中的月份
            final selectedMonth = _calendarSelectedMonth ?? DateTime.now();
            
            // 合并所有数据按日期
            final Map<DateTime, _DailyData> dailyData = {};
            
            for (final movie in provider.movies.where((m) => !m.isDeleted)) {
              final date = DateTime(movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
              dailyData.putIfAbsent(date, () => _DailyData()).movies++;
            }
            
            for (final book in provider.books.where((b) => !b.isDeleted)) {
              final date = DateTime(book.createdAt.year, book.createdAt.month, book.createdAt.day);
              dailyData.putIfAbsent(date, () => _DailyData()).books++;
            }
            
            for (final note in provider.notes.where((n) => !n.isDeleted)) {
              final date = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
              dailyData.putIfAbsent(date, () => _DailyData()).notes++;
            }

            // 计算最大数量用于颜色强度
            int maxCount = 0;
            for (final data in dailyData.values) {
              final count = data.total;
              if (count > maxCount) maxCount = count;
            }
            if (maxCount == 0) maxCount = 1;

            final year = selectedMonth.year;
            final month = selectedMonth.month;
            final daysInMonth = DateTime(year, month + 1, 0).day;
            final firstWeekday = DateTime(year, month, 1).weekday % 7;

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和月份切换
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Color(0xFF666666),
                      ),
                      const SizedBox(width: 8),
                      // 上个月按钮
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _calendarSelectedMonth = DateTime(year, month - 1);
                          });
                        },
                        child: const Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$year年$month月',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 下个月按钮
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _calendarSelectedMonth = DateTime(year, month + 1);
                          });
                        },
                        child: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
              
              // 星期标题 - 使用与日期相同的Wrap布局
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: const ['日', '一', '二', '三', '四', '五', '六']
                    .map((d) => SizedBox(
                          width: 32,
                          height: 20,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              
              // 日历网格
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  // 空白填充
                  ...List.generate(firstWeekday, (_) => const SizedBox(width: 32, height: 28)),
                  
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
                    
                    return Container(
                      width: 32,
                      height: 28,
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
                            fontSize: 10,
                            color: count > 0 ? Colors.white : const Color(0xFF666666),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              
              // 图例
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text('少', style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                  const SizedBox(width: 4),
                  ...List.generate(4, (index) {
                    final opacity = 0.2 + (index * 0.2);
                    return Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(opacity),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  const Text('多', style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                ],
              ),
            ],
          ),
        );
      });
    });
  }

  // 日历选中的月份状态（用于 StatefulBuilder）
  static DateTime? _calendarSelectedMonth;
}

/// 回顾项数据类
class _MemoryItem {
  final String type; // 'movie', 'book', 'note'
  final String title;
  final DateTime date;
  final String? imagePath; // 头图路径（影视/书籍有，笔记无）
  
  _MemoryItem({
    required this.type,
    required this.title,
    required this.date,
    this.imagePath,
  });
}

/// 每日数据
class _DailyData {
  int movies = 0;
  int books = 0;
  int notes = 0;
  
  int get total => movies + books + notes;
}

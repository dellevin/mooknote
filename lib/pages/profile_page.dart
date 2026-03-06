import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import 'recycle_bin_page.dart';
import 'backup_page.dart';
import 'statistics_page.dart';

/// 个人中心页面 - 极简主义设计
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final UserPrefs _userPrefs = UserPrefs();
  
  // 用户数据
  String _nickname = 'Mook';
  String _motto = '好运不会眷顾一无所有之人。';
  String? _avatarPath;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  /// 加载用户数据
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      await UserPrefs.init();
      setState(() {
        _nickname = _userPrefs.nickname;
        _motto = _userPrefs.motto;
        _avatarPath = _userPrefs.avatarPath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF1A1A1A),
        ),
      );
    }
    
    return Column(
      children: [
        // 标题栏
        AppBar(
          title: const Text('我的'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => _showSettings(context),
            ),
          ],
        ),
        
        // 内容
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部用户信息
                _buildUserHeader(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 数据统计
                _buildStatsSection(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 功能菜单
                _buildMenuSection(),
                
                const SizedBox(height: 48),
                
                // 版本信息
                const Center(
                  child: Text(
                    'MookNote v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 用户头部信息
  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // 头像
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
                shape: BoxShape.circle,
              ),
              child: _avatarPath != null && _avatarPath!.isNotEmpty
                  ? ClipOval(
                      child: Image.file(
                        File(_avatarPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                      ),
                    )
                  : _buildAvatarPlaceholder(),
            ),
          ),
          
          const SizedBox(width: 20),
          
          // 昵称和座右铭
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _editNickname(context),
                  child: Row(
                    children: [
                      Text(
                        _nickname,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Color(0xFF999999),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),
                
                GestureDetector(
                  onTap: () => _editMotto(context),
                  child: Text(
                    _motto,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(
      child: Icon(
        Icons.person_outline,
        size: 32,
        color: Color(0xFFCCCCCC),
      ),
    );
  }

  /// 数据统计区域
  Widget _buildStatsSection() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final movies = provider.movies;
        final books = provider.books;
        final notes = provider.notes;
        
        final movieCount = movies.where((m) => !m.isDeleted).length;
        final watchedCount = movies.where((m) => m.status == 'watched' && !m.isDeleted).length;
        final watchingCount = movies.where((m) => m.status == 'watching' && !m.isDeleted).length;
        final wantToWatchCount = movies.where((m) => m.status == 'want_to_watch' && !m.isDeleted).length;
        
        final bookCount = books.length;
        final readCount = books.where((b) => b.status == 'read').length;
        final readingCount = books.where((b) => b.status == 'reading').length;
        final wantToReadCount = books.where((b) => b.status == 'want_to_read').length;
        
        final noteCount = notes.length;
        
        final movieRatings = movies
            .where((m) => m.rating != null && !m.isDeleted)
            .map((m) => m.rating!);
        final avgMovieRating = movieRatings.isNotEmpty
            ? movieRatings.reduce((a, b) => a + b) / movieRatings.length
            : 0.0;
        
        final bookRatings = books
            .where((b) => b.rating != null)
            .map((b) => b.rating!);
        final avgBookRating = bookRatings.isNotEmpty
            ? bookRatings.reduce((a, b) => a + b) / bookRatings.length
            : 0.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildMainStat('观影', movieCount, '场'),
                    const SizedBox(width: 32),
                    _buildMainStat('阅读', bookCount, '本'),
                    const SizedBox(width: 32),
                    _buildMainStat('笔记', noteCount, '条'),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('观影详情'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildDetailStat('已看', watchedCount),
                        _buildDetailStat('在看', watchingCount),
                        _buildDetailStat('想看', wantToWatchCount),
                        _buildDetailStat('均分', avgMovieRating.toStringAsFixed(1)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle('阅读详情'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildDetailStat('已读', readCount),
                        _buildDetailStat('在读', readingCount),
                        _buildDetailStat('想读', wantToReadCount),
                        _buildDetailStat('均分', avgBookRating.toStringAsFixed(1)),
                      ],
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

  /// 主统计项
  Widget _buildMainStat(String label, int count, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 详细统计项
  Widget _buildDetailStat(String label, dynamic value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF999999),
        letterSpacing: 1,
      ),
    );
  }

  /// 功能菜单
  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.analytics_outlined,
          title: '数据统计',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StatisticsPage()),
            );
          },
        ),
        const Divider(height: 0.5, thickness: 0.5, indent: 56, color: Color(0xFFE5E5E5)),
        

        _buildMenuItem(
          icon: Icons.delete_outline,
          title: '回收站',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecycleBinPage()),
            );
          },
        ),
        const Divider(height: 0.5, thickness: 0.5, indent: 56, color: Color(0xFFE5E5E5)),
        
        _buildMenuItem(
          icon: Icons.backup_outlined,
          title: '数据备份',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BackupPage()),
            );
          },
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
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 选择头像
  Future<void> _pickAvatar() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'avatars', fileName);
        
        final avatarDir = Directory(path.join(appDir.path, 'avatars'));
        if (!await avatarDir.exists()) {
          await avatarDir.create(recursive: true);
        }
        
        await File(pickedFile.path).copy(savedPath);
        
        // 保存到本地存储
        await _userPrefs.setAvatarPath(savedPath);
        
        setState(() => _avatarPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        _showToast('选择头像失败: $e');
      }
    }
  }

  /// 编辑昵称
  void _editNickname(BuildContext context) {
    final controller = TextEditingController(text: _nickname);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '修改昵称',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入昵称',
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                await _userPrefs.setNickname(newNickname);
                setState(() => _nickname = newNickname);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 编辑座右铭
  void _editMotto(BuildContext context) {
    final controller = TextEditingController(text: _motto);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '修改座右铭',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '输入座右铭',
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E5E5)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              final newMotto = controller.text.trim();
              await _userPrefs.setMotto(newMotto);
              setState(() => _motto = newMotto);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示设置
  void _showSettings(BuildContext context) {
    _showToast('设置功能开发中');
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/toast_util.dart';

/// 自定义左侧弹出菜单 - 极简主义设计
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 顶部用户信息区域
          _buildHeader(context),
          
          const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
          
          // 菜单项列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [],
            ),
          ),
          
          // 底部版本信息
          Container(
            padding: const EdgeInsets.all(24),
            child: const Text(
              'MookNote v0.1.5',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
              ),
            ),
          ),
        ],
      ),
    );
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
}

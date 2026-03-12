import 'package:flutter/material.dart';
import 'webdav_sync_page.dart';

/// 云备份主页面 - 选择备份方式
class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('云备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WebDAV 备份选项
          _buildSyncOption(
            context,
            icon: Icons.storage_outlined,
            title: 'WebDAV 备份',
            subtitle: '通过 WebDAV 协议备份到个人云盘（如坚果云、Nextcloud 等）',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WebDAVSyncPage()),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // 服务器同步选项（暂未开放）
          _buildSyncOption(
            context,
            icon: Icons.cloud_outlined,
            title: '服务器同步',
            subtitle: '通过自建服务器同步数据（开发中）',
            enabled: false,
            onTap: () {
              // 暂未开放
            },
          ),
          
          const SizedBox(height: 32),
          
          // 说明文字
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '关于云备份',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• 云备份可以将您的数据备份到远程服务器\n'
                  '• 支持多台设备之间的数据恢复\n'
                  '• 建议定期进行云备份以确保数据安全\n'
                  '• 首次备份可能需要较长时间，请保持网络连接',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? const Color(0xFFE5E5E5) : const Color(0xFFEEEEEE),
          ),
          color: enabled ? Colors.white : const Color(0xFFF5F5F5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled 
                    ? const Color(0xFFF5F5F5) 
                    : const Color(0xFFEEEEEE),
              ),
              child: Icon(
                icon,
                color: enabled 
                    ? const Color(0xFF1A1A1A) 
                    : const Color(0xFF999999),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: enabled 
                          ? const Color(0xFF1A1A1A) 
                          : const Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled 
                          ? const Color(0xFF666666) 
                          : const Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled 
                  ? const Color(0xFF999999) 
                  : const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}

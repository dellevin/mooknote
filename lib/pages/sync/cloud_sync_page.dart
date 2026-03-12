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
        padding: const EdgeInsets.all(24),
        children: [
          // 备份方式标题
          _buildSectionTitle('选择备份方式'),
          const SizedBox(height: 16),
          
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
          _buildInfoSection(),
        ],
      ),
    );
  }

  /// 构建区块标题
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

  /// 构建信息说明区域
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '关于云备份',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('云备份可以将您的数据备份到远程服务器'),
          const SizedBox(height: 10),
          _buildInfoItem('支持多台设备之间的数据恢复'),
          const SizedBox(height: 10),
          _buildInfoItem('建议定期进行云备份以确保数据安全'),
          const SizedBox(height: 10),
          _buildInfoItem('首次备份可能需要较长时间，请保持网络连接'),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF999999),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFFAFAFA) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? const Color(0xFFE8E8E8) : const Color(0xFFEEEEEE),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled ? Colors.white : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: enabled ? const Color(0xFFE8E8E8) : const Color(0xFFEEEEEE),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                color: enabled 
                    ? const Color(0xFF666666) 
                    : const Color(0xFF999999),
                size: 22,
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
                      fontWeight: FontWeight.w600,
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
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: enabled 
                  ? const Color(0xFFCCCCCC) 
                  : const Color(0xFFE5E5E5),
            ),
          ],
        ),
      ),
    );
  }
}

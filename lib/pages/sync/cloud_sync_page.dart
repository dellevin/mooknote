import 'package:flutter/material.dart';
import 'webdav_sync_page.dart';
import 'server_sync_page.dart';

/// 云备份主页面 - 选择备份方式
class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(title: const Text('云备份')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('选择备份方式'),
          const SizedBox(height: 12),
          _buildOption(
            icon: Icons.storage_outlined,
            title: 'WebDAV 备份',
            subtitle: '通过 WebDAV 协议备份到个人云盘',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())),
          ),
          const SizedBox(height: 12),
          _buildOption(
            icon: Icons.sync_outlined,
            title: '服务端实时同步',
            subtitle: '自建服务端，多设备数据实时同步',
            enabled: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerSyncPage())),
          ),
          const SizedBox(height: 28),
          _buildInfo(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
    ]);
  }

  Widget _buildOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: enabled ? const Color(0xFF666666) : const Color(0xFFBBBBBB), size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: enabled ? const Color(0xFF1A1A1A) : const Color(0xFFBBBBBB))),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 12, color: enabled ? const Color(0xFF999999) : const Color(0xFFCCCCCC))),
          ])),
          Icon(Icons.chevron_right, color: enabled ? const Color(0xFFCCCCCC) : const Color(0xFFE5E5E5)),
        ]),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.info_outline, size: 18, color: Color(0xFF666666))),
          const SizedBox(width: 10),
          const Text('使用说明', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        ]),
        const SizedBox(height: 14),
        _infoItem('WebDAV 备份：将数据备份到支持 WebDAV 的云盘'),
        const SizedBox(height: 8),
        _infoItem('服务端实时同步：通过自建服务端实现多设备实时同步'),
        const SizedBox(height: 8),
        _infoItem('激活码由服务端管理员在管理后台生成'),
        const SizedBox(height: 8),
        _infoItem('建议定期备份 + 实时同步配合使用'),
      ]),
    );
  }

  Widget _infoItem(String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: const Color(0xFFBBBBBB), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.5))),
    ]);
  }
}

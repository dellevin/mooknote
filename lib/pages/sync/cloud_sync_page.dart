import 'package:flutter/material.dart';
import 'webdav_sync_page.dart';

/// 云备份主页面 - 选择备份方式
class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(title: const Text('云备份')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle(colors, '选择备份方式'),
          const SizedBox(height: 10),
          _buildOption(
            colors: colors,
            icon: Icons.storage_outlined,
            title: 'WebDAV 备份',
            subtitle: '通过 WebDAV 协议备份到个人云盘',
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())),
          ),
          const SizedBox(height: 12),
          _buildOption(
            colors: colors,
            icon: Icons.cloud_sync_outlined,
            title: '服务器云同步',
            subtitle: '自建云同步服务器，多端同步更改',
            onTap: () {},
            enabled: false,
          ),
          const SizedBox(height: 20),
          _buildInfo(colors),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ColorScheme colors, String title) {
    return Row(children: [
      Container(
          width: 3,
          height: 14,
          decoration:
              BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
    ]);
  }

  Widget _buildOption({
    required ColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled ? colors.surface : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon,
                  color: enabled
                      ? colors.onSurface.withValues(alpha: 0.6)
                      : colors.onSurface.withValues(alpha: 0.3),
                  size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? colors.onSurface : colors.onSurface.withValues(alpha: 0.3))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: enabled
                        ? colors.onSurface.withValues(alpha: 0.4)
                        : colors.onSurface.withValues(alpha: 0.25))),
          ])),
          Icon(Icons.chevron_right,
              color: enabled
                  ? colors.onSurface.withValues(alpha: 0.25)
                  : colors.outline),
        ]),
      ),
    );
  }

  Widget _buildInfo(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.info_outline,
                  size: 18, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 10),
          Text('使用说明',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
        ]),
        const SizedBox(height: 12),
        _infoItem(colors, 'WebDAV 备份：将数据备份到支持 WebDAV 的云盘'),
        const SizedBox(height: 8),
        _infoItem(colors, '建议定期备份到本地或云盘'),
      ]),
    );
  }

  Widget _infoItem(ColorScheme colors, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.3), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5))),
    ]);
  }
}

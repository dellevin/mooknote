import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_back_button.dart';
import 'cloud_account_page.dart';
import 'webdav_sync_page.dart';

/// 云备份主页面 - 选择备份方式
class CloudSyncPage extends StatelessWidget {
  const CloudSyncPage({super.key});

  /// 服务器云同步入口：首次进入弹数据上传说明（确认后不再提示）
  Future<void> _openCloudSync(BuildContext context) async {
    final prefs = UserPrefs();
    if (!prefs.cloudSyncConsented) {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Icon(Icons.cloud_sync_outlined,
                size: 22, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Text('服务器云同步说明'.tr,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ]),
          content: Text(
            '开启服务器云同步需注册账号，您的影视、阅读、游戏、笔记等全部数据将上传至云端服务器存储，用于多设备间数据同步，并支持未来微信小程序、Windows、macOS、iOS 端在线使用。确认开启即表示您已知晓并同意。'.tr,
            style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.75)),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr,
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('同意并继续'.tr),
            ),
          ],
        ),
      );
      if (agreed != true) return;
      await prefs.setCloudSyncConsented(true);
    }

    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudAccountPage()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('云备份'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle(colors, '选择备份方式'.tr),
          const SizedBox(height: 10),
          _buildOption(
            colors: colors,
            icon: Icons.storage_outlined,
            title: 'WebDAV 备份'.tr,
            subtitle: '通过 WebDAV 协议备份到个人云盘'.tr,
            onTap: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())),
          ),
          const SizedBox(height: 12),
          _buildOption(
            colors: colors,
            icon: Icons.cloud_sync_outlined,
            title: '服务器云同步'.tr,
            subtitle: '数据上云，同步更简单，操作更方便'.tr,
            onTap: () => _openCloudSync(context),
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
          Text('使用说明'.tr,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
        ]),
        const SizedBox(height: 12),
        _infoItem(colors, 'WebDAV 备份：将数据备份到支持 WebDAV 的云盘'.tr),
        const SizedBox(height: 8),
        _infoItem(colors, '建议定期备份到本地或云盘'.tr),
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

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_strings.dart';
import '../../services/system_settings_channel.dart';

/// 系统权限列表页：展示 App 所需权限及授权状态，点击跳转对应授权界面
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  final Map<String, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置返回时刷新状态
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final statuses = <String, PermissionStatus>{
      'storage': await Permission.manageExternalStorage.status,
      'photos': await Permission.photos.status,
      'videos': await Permission.videos.status,
      'audio': await Permission.audio.status,
    };
    if (mounted) setState(() => _statuses.addAll(statuses));
  }

  /// 点击某项权限：跳转到对应授权界面（已授权则直接打开系统设置）
  Future<void> _request(String key) async {
    // 存储走原生通道直达"所有文件访问"授权页（已授权也能拉起），失败再兜底
    if (key == 'storage') {
      if (!await SystemSettingsChannel.openAllFilesAccess()) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted && status.isPermanentlyDenied) {
          await openAppSettings();
        }
      }
      await _refresh();
      return;
    }
    // 已授权时普通权限 request() 会直接返回不弹界面，改为跳系统设置页
    if (_statuses[key]?.isGranted ?? false) {
      await openAppSettings();
      await _refresh();
      return;
    }
    switch (key) {
      case 'photos':
        final status = await Permission.photos.request();
        if (status.isPermanentlyDenied) await openAppSettings();
        break;
      case 'videos':
        final status = await Permission.videos.request();
        if (status.isPermanentlyDenied) await openAppSettings();
        break;
      case 'audio':
        final status = await Permission.audio.request();
        if (status.isPermanentlyDenied) await openAppSettings();
        break;
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <_PermissionItem>[
      _PermissionItem(
        key: 'storage',
        icon: Icons.folder_outlined,
        title: '存储（所有文件访问）'.tr,
        subtitle: '扫描字体、备份恢复、保存图片所需'.tr,
      ),
      _PermissionItem(
        key: 'photos',
        icon: Icons.image_outlined,
        title: '照片'.tr,
        subtitle: '从相册选择和保存图片'.tr,
      ),
      _PermissionItem(
        key: 'videos',
        icon: Icons.videocam_outlined,
        title: '视频'.tr,
        subtitle: '读取系统媒体库中的视频'.tr,
      ),
      _PermissionItem(
        key: 'audio',
        icon: Icons.music_note_outlined,
        title: '音频'.tr,
        subtitle: '读取系统媒体库中的音频'.tr,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('获取系统权限'.tr)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
            height: 0.5,
            indent: 24,
            endIndent: 24,
            color: colors.outlineVariant),
        itemBuilder: (context, i) {
          final item = items[i];
          final status = _statuses[item.key];
          final granted = status?.isGranted ?? false;
          return ListTile(
            leading: Icon(item.icon, size: 22, color: colors.primary),
            title: Text(item.title, style: const TextStyle(fontSize: 15)),
            subtitle: Text(item.subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5))),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: granted
                    ? Colors.green.withValues(alpha: 0.1)
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                granted ? '已授权'.tr : '未授权'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: granted
                      ? Colors.green
                      : colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            onTap: () => _request(item.key),
          );
        },
      ),
    );
  }
}

class _PermissionItem {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;

  const _PermissionItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

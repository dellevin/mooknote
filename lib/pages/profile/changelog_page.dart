import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_strings.dart';
import '../../services/changelog_service.dart';
import '../../widgets/app_overlay.dart';

/// 更新日志页面
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<ChangelogItem>? _items;
  bool _loading = true;
  bool _checking = false;
  static const _websiteUrl = 'https://mooknote.iletter.top/#/';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ChangelogService.fetchChangelog();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    try {
      final hasUpdate = await ChangelogService.hasUpdate();
      if (!mounted) return;
      final info = await PackageInfo.fromPlatform();
      final localVersion = 'v${info.version}';
      if (!mounted) return;
      if (hasUpdate) {
        final latest = _items != null && _items!.isNotEmpty
            ? _items!.first.version
            : '新版本'.tr;
        final latestVersion = await ChangelogService.fetchLatestVersion();
        _showUpdateDialog(
          version: latestVersion ?? latest,
          localVersion: localVersion,
        );
      } else {
        _showNoUpdateDialog(localVersion);
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  void _showNoUpdateDialog(String localVersion) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('检查更新'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('已是最新版本（当前 {v}）'.trf({'v': localVersion}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('好的'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showUpdateDialog({required String version, String? localVersion}) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('发现新版本'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (localVersion != null) ...[
              Text('当前版本：{v}'.trf({'v': localVersion}),
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
              const SizedBox(height: 6),
            ],
            Text('最新版本 {v} 已发布，是否下载更新？'.trf({'v': version}),
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('稍后再说'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await launchUrl(Uri.parse(_websiteUrl), mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('去官网下载'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('更新日志'.tr),
        actions: [
          _checking
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '检查更新'.tr,
                  onPressed: _checkUpdate,
                ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items == null || _items!.isEmpty
              ? Center(
                  child: Text('暂无更新日志'.tr,
                      style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildWebsiteCard(colors),
                    const SizedBox(height: 20),
                    ..._items!.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCard(item, colors),
                        )),
                  ],
                ),
    );
  }

  Widget _buildWebsiteCard(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Icon(Icons.language, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text('官方网站'.tr,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: GestureDetector(
              onTap: () async {
                try {
                  await launchUrl(Uri.parse(_websiteUrl), mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              child: Text(_websiteUrl,
                  style: TextStyle(fontSize: 13, color: colors.primary)),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: colors.outlineVariant),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: _websiteUrl));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('已复制到剪贴板'.tr),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text('复制链接'.tr,
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: colors.outlineVariant),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    try {
                      await launchUrl(Uri.parse(_websiteUrl), mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_browser, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text('浏览器打开'.tr,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(ChangelogItem item, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.version,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.date,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...item.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.75),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

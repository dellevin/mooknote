import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../services/sync/cache_cleaner.dart';
import '../../utils/toast_util.dart';

/// 缓存清理页：进入自动扫描分析 → 底部按钮清理 → 清理后重新分析
class CacheCleanerPage extends StatefulWidget {
  const CacheCleanerPage({super.key});

  @override
  State<CacheCleanerPage> createState() => _CacheCleanerPageState();
}

class _CacheCleanerPageState extends State<CacheCleanerPage> {
  CacheScanResult? _scan;
  bool _scanning = true;
  bool _cleaning = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _scanning = true);
    final result = await CacheCleaner.instance.analyze();
    if (!mounted) return;
    setState(() {
      _scan = result;
      _scanning = false;
    });
  }

  Future<void> _clean() async {
    if (_cleaning) return;
    setState(() => _cleaning = true);
    try {
      final result = await CacheCleaner.instance.clean();
      if (!mounted) return;
      if (result.total > 0) ToastUtil.show(context, result.description);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '清理失败: {e}'.trf({'e': e}));
    }
    if (!mounted) return;
    setState(() => _cleaning = false);
    // 清理完成后重新分析，刷新展示
    await _analyze();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scan = _scan;
    final cleanable = !_scanning && scan != null && scan.total > 0;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('缓存分析'.tr)),
      body: _scanning
          ? const Center(child: CircularProgressIndicator())
          : scan == null
              ? const SizedBox.shrink()
              : _buildBody(scan, colors),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: cleanable && !_cleaning ? _clean : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              disabledBackgroundColor: colors.surfaceContainerHighest,
              disabledForegroundColor: colors.onSurface.withValues(alpha: 0.35),
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _cleaning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    cleanable
                        ? '立即清理（{size}）'
                            .trf({'size': CacheScanResult.formatSize(scan.totalSize)})
                        : '没有需要清理的缓存'.tr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CacheScanResult scan, ColorScheme colors) {
    final items = [
      ('孤立图片'.tr, scan.images, scan.imagesSize, Icons.image_outlined),
      ('临时文件'.tr, scan.temp, scan.tempSize, Icons.folder_outlined),
      ('系统缓存'.tr, scan.systemCache, scan.systemCacheSize,
          Icons.web_asset_off_outlined),
      ('空文件夹'.tr, scan.emptyDirs, 0, Icons.folder_off_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHero(scan, colors),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0)
                  Divider(
                      height: 0.5,
                      indent: 44,
                      color: colors.outlineVariant.withValues(alpha: 0.3)),
                _buildItem(item.$1, item.$2, item.$3, item.$4, colors),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 顶部 Hero：总大小 + 总项数
  Widget _buildHero(CacheScanResult scan, ColorScheme colors) {
    final empty = scan.total == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: empty
              ? [
                  colors.surfaceContainerHighest.withValues(alpha: 0.6),
                  colors.surfaceContainerHighest.withValues(alpha: 0.3),
                ]
              : [
                  colors.primary.withValues(alpha: 0.14),
                  colors.primary.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: empty
                  ? colors.onSurface.withValues(alpha: 0.06)
                  : colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              empty ? Icons.check_circle_outline : Icons.cleaning_services_outlined,
              size: 28,
              color: empty
                  ? colors.onSurface.withValues(alpha: 0.3)
                  : colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            empty ? '0 B' : CacheScanResult.formatSize(scan.totalSize),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: empty
                  ? colors.onSurface.withValues(alpha: 0.35)
                  : colors.onSurface,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            empty
                ? '没有需要清理的缓存'.tr
                : '共发现 {n} 项可清理缓存'.trf({'n': scan.total}),
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
      String label, int count, int size, IconData icon, ColorScheme colors) {
    final hasItems = count > 0;
    final alpha = hasItems ? 1.0 : 0.45;
    return Opacity(
      opacity: alpha,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
            ),
            Text(
              size > 0
                  ? '{n}项  {size}'.trf(
                      {'n': count, 'size': CacheScanResult.formatSize(size)})
                  : '{n}项'.trf({'n': count}),
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

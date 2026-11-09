import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_strings.dart';
import '../../services/font_download_manager.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';

/// 字体选择页面
///
/// 用户选择字体目录，遍历目录下的字体文件，点击即可加载使用。
class FontPickerPage extends StatefulWidget {
  final String? initialFamily;
  const FontPickerPage({super.key, this.initialFamily});

  @override
  State<FontPickerPage> createState() => _FontPickerPageState();
}

class _FontPickerPageState extends State<FontPickerPage> {
  final FontDownloadManager _fontManager = FontDownloadManager();

  List<FontFileInfo> _fonts = [];
  String? _loadingPath;
  String? _selectedFamily;
  bool _isScanning = false;
  String? _currentDirPath;

  @override
  void initState() {
    super.initState();
    // 进入即高亮当前应用字体（initialFamily 通常为空，实际值存在 UserPrefs）
    _selectedFamily =
        (widget.initialFamily != null && widget.initialFamily!.isNotEmpty)
            ? widget.initialFamily
            : UserPrefs().fontFamily;
    // 恢复上次选择的目录
    final savedDir = UserPrefs().lastFontDir;
    if (savedDir != null && savedDir.isNotEmpty) {
      _currentDirPath = savedDir;
      _scanDirectory(savedDir);
    }
  }

  /// 请求存储权限（Android 11+ 需要 MANAGE_EXTERNAL_STORAGE）
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;

    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;

    status = await Permission.storage.status;
    if (status.isGranted) return true;

    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 显示权限提示弹窗
  void _showPermissionDialog() {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('需要存储权限'.tr,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          'Android 11+ 需要在系统设置中授予"所有文件访问权限"才能扫描字体文件。\n\n是否前往设置？'.tr,
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('前往设置'.tr, style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  /// 扫描目录字体
  Future<void> _scanDirectory(String dirPath) async {
    if (dirPath.isEmpty) return;

    setState(() => _isScanning = true);
    try {
      final fonts = await _fontManager.scanFontDirectory(dirPath);
      if (mounted) {
        setState(() {
          _fonts = fonts;
          _isScanning = false;
        });
        if (fonts.isEmpty) {
          ToastUtil.show(context, '未找到字体文件'.tr);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ToastUtil.show(context, '扫描失败: {e}'.trf({'e': e}));
      }
    }
  }

  /// 扫描当前目录字体
  Future<void> _rescanDirectory() async {
    if (_currentDirPath == null || _currentDirPath!.isEmpty) {
      ToastUtil.show(context, '请先选择字体目录'.tr);
      return;
    }
    await _scanDirectory(_currentDirPath!);
  }

  /// 点击选择目录按钮
  Future<void> _onSelectDirectory() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog();
      return;
    }

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null && result.isNotEmpty) {
        _currentDirPath = result;
        // 保存到 SharedPreferences
        await UserPrefs().setLastFontDir(result);
        await _scanDirectory(result);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择目录失败: {e}'.trf({'e': e}));
    }
  }

  /// 加载并应用字体
  Future<void> _loadFont(FontFileInfo font) async {
    if (_loadingPath != null) return; // 防止重复点击

    setState(() => _loadingPath = font.path);
    try {
      debugPrint('[字体] 选择字体文件: ${font.path}');
      final family = await _fontManager.loadFontFile(font.path);
      debugPrint('[字体] 注册结果: ${family ?? '失败'}');
      if (!mounted) return;
      if (family != null) {
        setState(() => _selectedFamily = family);
        ToastUtil.show(context, '已应用: {name}'.trf({'name': font.displayName}));
        Navigator.pop(context, family);
      } else {
        ToastUtil.show(context, _fontManager.lastError ?? '字体加载失败'.tr);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '加载失败: {e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() => _loadingPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('选择字体'.tr),
        actions: [
          // 默认字体按钮
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              '恢复默认'.tr,
              style: TextStyle(
                fontSize: 13,
                color: colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 选择目录按钮区
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '字体目录'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _rescanDirectory,
                      icon: Icon(Icons.refresh,
                          size: 16, color: colors.onPrimary),
                      label: Text('扫描'.tr,
                          style: const TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _onSelectDirectory,
                  onLongPress: _currentDirPath == null
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: _currentDirPath!));
                          ToastUtil.show(context, '已复制'.tr);
                        },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.folder_open_outlined,
                              size: 18, color: colors.primary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _currentDirPath ?? '点击选择字体目录'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: _currentDirPath != null
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: colors.onSurface.withValues(alpha: 0.3)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 字体列表
          Expanded(
            child: _isScanning
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : _fonts.isEmpty
                    ? _buildEmptyState(colors)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _fonts.length,
                        itemBuilder: (_, index) =>
                            _buildFontItem(_fonts[index], colors),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.font_download_outlined,
              size: 34,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到字体文件'.tr,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持 .ttf / .otf / .ttc 格式'.tr,
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontItem(FontFileInfo font, ColorScheme colors) {
    final isLoading = _loadingPath == font.path;
    final family = path.basenameWithoutExtension(font.fileName);
    final isSelected = family == _selectedFamily;
    // 已注册（当前应用或本次点过）的字体才能用自身字形做真实预览
    final loaded = _fontManager.isFamilyLoaded(family);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? colors.primary.withValues(alpha: 0.08)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1 : 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : () => _loadFont(font),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.primary),
                      )
                    : Text('Aa',
                        style: TextStyle(
                          fontFamily: loaded ? family : null,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.75),
                        )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      font.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: loaded ? family : null,
                        fontSize: 17,
                        height: 1.2,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      font.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(Icons.check_rounded, size: 20, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../utils/font_download_manager.dart';
import '../utils/toast_util.dart';

/// 字体选择页面
///
/// 用户输入或选择字体目录，遍历目录下的字体文件，点击即可加载使用。
class FontPickerPage extends StatefulWidget {
  final String? initialFamily;
  const FontPickerPage({super.key, this.initialFamily});

  @override
  State<FontPickerPage> createState() => _FontPickerPageState();
}

class _FontPickerPageState extends State<FontPickerPage> {
  final TextEditingController _pathController = TextEditingController();
  final FontDownloadManager _fontManager = FontDownloadManager();

  List<FontFileInfo> _fonts = [];
  String? _loadingPath;
  String? _selectedFamily;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _selectedFamily = widget.initialFamily;
    // 默认填入内置字体目录
    _pathController.text = '/sdcard/Documents/mooknote/fonts';
    _checkPermissionAndScan();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
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

  /// 检查权限并扫描
  Future<void> _checkPermissionAndScan() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }
    await _scanDirectory();
  }

  /// 显示权限提示弹窗
  void _showPermissionDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('需要存储权限',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          'Android 11+ 需要在系统设置中授予"所有文件访问权限"才能扫描字体文件。\n\n是否前往设置？',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('前往设置', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  /// 扫描目录字体
  Future<void> _scanDirectory() async {
    final dirPath = _pathController.text.trim();
    if (dirPath.isEmpty) {
      if (mounted) ToastUtil.show(context, '请输入目录路径');
      return;
    }

    setState(() => _isScanning = true);
    try {
      final fonts = await _fontManager.scanFontDirectory(dirPath);
      if (mounted) {
        setState(() {
          _fonts = fonts;
          _isScanning = false;
        });
        if (fonts.isEmpty) {
          ToastUtil.show(context, '未找到字体文件');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        ToastUtil.show(context, '扫描失败: $e');
      }
    }
  }

  /// 使用 file_picker 选择目录
  Future<void> _pickDirectory() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog();
      return;
    }
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null && result.isNotEmpty) {
        _pathController.text = result;
        await _scanDirectory();
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择目录失败: $e');
    }
  }

  /// 加载并应用字体
  Future<void> _loadFont(FontFileInfo font) async {
    if (_loadingPath != null) return; // 防止重复点击

    setState(() => _loadingPath = font.path);
    try {
      final family = await _fontManager.loadFontFile(font.path);
      if (family != null) {
        setState(() => _selectedFamily = family);
        if (mounted) {
          ToastUtil.show(context, '已应用: ${font.displayName}');
          Navigator.pop(context, family);
        }
      } else {
        if (mounted) ToastUtil.show(context, '字体加载失败');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '加载失败: $e');
    } finally {
      setState(() => _loadingPath = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('选择字体'),
        actions: [
          // 默认字体按钮
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              '恢复默认',
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
          // 路径输入区
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '字体目录',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        style: TextStyle(fontSize: 13, color: colors.onSurface),
                        decoration: InputDecoration(
                          hintText: '输入字体目录路径',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.3),
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.folder_open_outlined,
                              size: 18,
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                            onPressed: _pickDirectory,
                          ),
                        ),
                        onSubmitted: (_) => _scanDirectory(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _scanDirectory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('扫描', style: TextStyle(fontSize: 13)),
                    ),
                  ],
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
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _fonts.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 0.5,
                          indent: 20,
                          endIndent: 20,
                          color: colors.outlineVariant,
                        ),
                        itemBuilder: (_, index) => _buildFontItem(
                          _fonts[index],
                          colors,
                        ),
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
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: colors.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            '未找到字体文件',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '支持 .ttf / .otf / .ttc 格式',
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
    final isSelected = _selectedFamily != null &&
        path.basenameWithoutExtension(font.fileName) == _selectedFamily;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.1)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: colors.primary.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                ),
              )
            : Icon(
                Icons.font_download_outlined,
                size: 18,
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
      ),
      title: Text(
        font.displayName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: colors.onSurface,
        ),
      ),
      subtitle: Text(
        font.fileName,
        style: TextStyle(
          fontSize: 11,
          color: colors.onSurface.withValues(alpha: 0.35),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, size: 18, color: colors.primary)
          : null,
      onTap: isLoading ? null : () => _loadFont(font),
    );
  }
}

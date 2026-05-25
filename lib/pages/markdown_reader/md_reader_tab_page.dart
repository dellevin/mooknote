import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../utils/user_prefs.dart';
import 'md_viewer_page.dart';

/// Markdown 阅读器 - 文件浏览器
class MdReaderTabPage extends StatefulWidget {
  const MdReaderTabPage({super.key});

  @override
  State<MdReaderTabPage> createState() => _MdReaderTabPageState();
}

class _MdReaderTabPageState extends State<MdReaderTabPage> {
  String? _rootPath;
  String? _currentPath;
  List<_FileEntry> _entries = [];
  bool _isLoading = false;
  String? _error;

  bool _showEmptyDirs = true;
  bool _showImageOnlyDirs = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _init();
  }

  void _loadSettings() {
    final prefs = UserPrefs();
    _showEmptyDirs = prefs.showEmptyDirs;
    _showImageOnlyDirs = prefs.showImageOnlyDirs;
  }

  Future<void> _init() async {
    final saved = UserPrefs().lastMdFolder;
    if (saved != null && saved.isNotEmpty) {
      final dir = Directory(saved);
      if (await dir.exists()) {
        _rootPath = saved;
        _currentPath = saved;
        await _loadDirectory();
        return;
      }
    }
    if (mounted) setState(() {});
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

  Future<void> _pickDirectory() async {
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        _showPermissionDeniedDialog();
      }
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    UserPrefs().setLastMdFolder(result);
    _rootPath = result;
    _currentPath = result;
    _error = null;
    await _loadDirectory();
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('需要存储权限',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text(
            'Android 11+ 需要在系统设置中授予"所有文件访问权限"才能读取目录中的 Markdown 文件。\n\n是否前往设置？',
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
              child: Text('前往设置', style: TextStyle(color: colors.onSurface)),
            ),
          ],
        );
      },
    );
  }

  /// 递归检查目录（含子目录）是否包含 Markdown 文件
  bool _hasMarkdownFiles(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return false;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          final lower = p.basename(entity.path).toLowerCase();
          if (lower.endsWith('.md') ||
              lower.endsWith('.markdown') ||
              lower.endsWith('.mdown') ||
              lower.endsWith('.txt')) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// 递归检查目录是否只有图片文件（无 markdown、无非图片文件）
  bool _isImageOnlyDir(String dirPath) {
    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return false;
      const imageExts = [
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
        '.bmp',
        '.svg',
        '.ico',
        '.tiff',
        '.heic',
        '.webm'
      ];
      bool hasAnyFile = false;
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File) {
          hasAnyFile = true;
          final lower = p.basename(entity.path).toLowerCase();
          if (lower.endsWith('.md') ||
              lower.endsWith('.markdown') ||
              lower.endsWith('.mdown') ||
              lower.endsWith('.txt')) {
            return false;
          }
          if (!imageExts.any((ext) => lower.endsWith(ext))) {
            return false;
          }
        }
      }
      return hasAnyFile;
    } catch (_) {}
    return false;
  }

  /// 判断目录是否应该被过滤掉
  bool _shouldFilterDir(String dirPath) {
    if (!_showEmptyDirs && !_hasMarkdownFiles(dirPath)) return true;
    if (!_showImageOnlyDirs && _isImageOnlyDir(dirPath)) return true;
    return false;
  }

  Future<void> _loadDirectory() async {
    if (_currentPath == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _entries = [];
    });

    try {
      final dir = Directory(_currentPath!);
      final exists = await dir.exists();
      if (!exists) {
        if (mounted) {
          setState(() {
            _error = '目录不存在: $_currentPath';
            _isLoading = false;
          });
        }
        return;
      }

      final list = dir.listSync(recursive: false, followLinks: false);

      final entries = <_FileEntry>[];
      for (final entity in list) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (!_shouldFilterDir(entity.path)) {
            entries.add(_FileEntry(name: name, path: entity.path, isDir: true));
          }
        } else if (entity is File) {
          final lower = name.toLowerCase();
          if (lower.endsWith('.md') ||
              lower.endsWith('.markdown') ||
              lower.endsWith('.mdown') ||
              lower.endsWith('.txt')) {
            final stat = entity.statSync();
            entries.add(_FileEntry(
                name: name, path: entity.path, isDir: false, size: stat.size));
          }
        }
      }

      entries.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '读取失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _enterDirectory(String path) {
    _currentPath = path;
    _loadDirectory();
  }

  void _goBack() {
    if (_currentPath == null || _rootPath == null || _currentPath == _rootPath) return;
    final parent = Directory(_currentPath!).parent.path;
    if (parent == _currentPath!) return;
    if (!parent.startsWith(_rootPath!)) return;
    _currentPath = parent;
    _loadDirectory();
  }

  void _openFile(_FileEntry entry) {
    Navigator.push(context,
        MaterialPageRoute(
          builder: (context) => MdViewerPage(filePath: entry.path),
        ));
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('目录显示设置',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('显示空目录',
                      style: TextStyle(
                          fontSize: 14, color: colors.onSurface.withValues(alpha: 0.75))),
                  subtitle: Text('关闭后隐藏无 Markdown 文件的目录',
                      style:
                          TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                  value: _showEmptyDirs,
                  activeTrackColor: colors.primary,
                  onChanged: (val) {
                    setLocalState(() => _showEmptyDirs = val);
                    UserPrefs().setShowEmptyDirs(val);
                    setState(() {});
                    _loadDirectory();
                  },
                ),
                Divider(height: 0.5, color: colors.outlineVariant),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('显示纯图片目录',
                      style: TextStyle(
                          fontSize: 14, color: colors.onSurface.withValues(alpha: 0.75))),
                  subtitle: Text('关闭后隐藏只含图片、无 Markdown 的目录',
                      style:
                          TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                  value: _showImageOnlyDirs,
                  activeTrackColor: colors.primary,
                  onChanged: (val) {
                    setLocalState(() => _showImageOnlyDirs = val);
                    UserPrefs().setShowImageOnlyDirs(val);
                    setState(() {});
                    _loadDirectory();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _canGoBack =>
      _currentPath != null && _rootPath != null && _currentPath != _rootPath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          _currentPath != null ? p.basename(_currentPath!) : 'Markdown 阅读',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_currentPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: _pickDirectory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outline, width: 0.5),
                  ),
                  child: Text('更换目录',
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.tune, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
            onPressed: _showSettingsSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (_currentPath == null) {
      return _buildWelcome(colors);
    }

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_error != null) {
      return _buildError(colors);
    }

    return RefreshIndicator(
      onRefresh: _loadDirectory,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: _entries.isEmpty
          ? _buildEmpty(colors)
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: (_canGoBack ? 1 : 0) + _entries.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 0.5, thickness: 0.5, color: colors.outlineVariant),
              itemBuilder: (context, index) {
                if (_canGoBack && index == 0) {
                  return ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.arrow_upward,
                          size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
                    ),
                    title: Text('..',
                        style: TextStyle(
                            fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
                    onTap: _goBack,
                  );
                }
                final entry = _entries[_canGoBack ? index - 1 : index];
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: entry.isDir
                          ? const Color(0xFFF0F7FF)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      entry.isDir ? Icons.folder_outlined : Icons.description_outlined,
                      size: 18,
                      color: entry.isDir
                          ? const Color(0xFF4A90D9)
                          : colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  title: Text(entry.name,
                      style: TextStyle(fontSize: 14, color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: entry.isDir
                      ? null
                      : Text(_formatSize(entry.size),
                          style: TextStyle(
                              fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                  trailing: Icon(entry.isDir ? Icons.chevron_right : Icons.open_in_new_outlined,
                      size: 16, color: colors.onSurface.withValues(alpha: 0.25)),
                  onTap: () =>
                      entry.isDir ? _enterDirectory(entry.path) : _openFile(entry),
                );
              },
            ),
    );
  }

  Widget _buildWelcome(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.folder_open_outlined,
                  size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 24),
            Text('Markdown 阅读',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 8),
            Text('选择一个包含 .md 文件的文件夹',
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickDirectory,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('选择目录',
                    style: TextStyle(
                        fontSize: 15, color: colors.onPrimary, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: colors.outline),
          const SizedBox(height: 16),
          Text('此目录下没有 Markdown 文件',
              style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 4),
          Text(_currentPath ?? '',
              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.25))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _canGoBack ? _goBack : () => _pickDirectory(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: colors.onSurface.withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _canGoBack ? '返回上级目录' : '换一个目录',
                style: TextStyle(
                    fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: colors.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('路径: ${_currentPath ?? ""}',
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.25))),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _loadDirectory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('重试',
                        style: TextStyle(fontSize: 13, color: colors.onPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickDirectory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.onSurface.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('更换目录',
                        style: TextStyle(
                            fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _FileEntry {
  final String name;
  final String path;
  final bool isDir;
  final int? size;

  _FileEntry({required this.name, required this.path, required this.isDir, this.size});
}

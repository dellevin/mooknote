import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'md_viewer_page.dart';

/// Markdown 阅读器 Tab 页 - 文件浏览器
class MdReaderTabPage extends StatefulWidget {
  const MdReaderTabPage({super.key});

  @override
  State<MdReaderTabPage> createState() => _MdReaderTabPageState();
}

class _MdReaderTabPageState extends State<MdReaderTabPage> {
  static const String _basePath = '/storage/emulated/0/Documents/mooknote/markdown';
  String _currentPath = _basePath;
  List<FileSystemEntity> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  /// 加载当前目录内容
  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dir = Directory(_currentPath);
      if (!await dir.exists()) {
        setState(() {
          _error = '目录不存在\n请将 Markdown 文件放到：\n$_basePath';
          _items = [];
          _isLoading = false;
        });
        return;
      }

      final entities = await dir.list().toList();
      // 排序：文件夹在前，文件在后，按名称排序
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir != bIsDir) {
          return aIsDir ? -1 : 1;
        }
        return p.basename(a.path).toLowerCase().compareTo(
              p.basename(b.path).toLowerCase());
      });

      setState(() {
        _items = entities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '读取目录失败: $e';
        _items = [];
        _isLoading = false;
      });
    }
  }

  /// 进入子目录
  void _enterDirectory(String path) {
    setState(() {
      _currentPath = path;
    });
    _loadDirectory();
  }

  /// 返回上级目录
  void _goBack() {
    final parent = Directory(_currentPath).parent.path;
    if (parent == _currentPath) return;
    _enterDirectory(parent);
  }

  /// 打开 Markdown 文件
  void _openFile(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MdViewerPage(filePath: path),
      ),
    );
  }

  /// 判断是否可以返回上级
  bool get _canGoBack => _currentPath != _basePath;

  /// 获取当前显示路径（相对路径）
  String get _displayPath {
    if (_currentPath == _basePath) return 'markdown';
    return _currentPath.substring(_basePath.length + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 紧凑顶部栏
          _buildHeader(),
          // 内容区域
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  /// 构建紧凑顶部栏
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPadding, left: 12, right: 12, bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _goBack,
            )
          else
            const SizedBox(width: 8),
          // 路径标题
          Expanded(
            child: Text(
              _canGoBack ? _displayPath : '文件列表',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)));
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadDirectory,
      color: const Color(0xFF1A1A1A),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final isDirectory = item is Directory;
          final name = p.basename(item.path);
          final isMdFile = !isDirectory && name.toLowerCase().endsWith('.md');

          // 跳过非 md 文件和非目录项
          if (!isDirectory && !isMdFile) {
            return const SizedBox.shrink();
          }

          return _buildListItem(item, isDirectory, name);
        },
      ),
    );
  }

  Widget _buildListItem(FileSystemEntity item, bool isDirectory, String name) {
    return InkWell(
      onTap: () {
        if (isDirectory) {
          _enterDirectory(item.path);
        } else {
          _openFile(item.path);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDirectory ? const Color(0xFFF0F7FF) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isDirectory ? Icons.folder_outlined : Icons.description_outlined,
                color: isDirectory ? const Color(0xFF4A90D9) : const Color(0xFF666666),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isDirectory)
                    Text(
                      _formatFileSize(item),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                ],
              ),
            ),
            if (isDirectory)
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18)
            else
              const Icon(Icons.open_in_new_outlined, color: Color(0xFFCCCCCC), size: 16),
          ],
        ),
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(FileSystemEntity entity) {
    try {
      if (entity is File) {
        final stat = entity.statSync();
        final size = stat.size;
        if (size < 1024) return '$size B';
        if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
        return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    } catch (_) {}
    return '';
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: Color(0xFFE0E0E0),
          ),
          SizedBox(height: 20),
          Text(
            '暂无 Markdown 文件',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF999999),
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '请在 /Documents/mooknote/markdown 目录下放置 .md 文件',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFCCCCCC),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDirectory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
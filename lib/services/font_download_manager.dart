import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../utils/image_path_helper.dart';

/// 本地字体扫描与加载管理器
///
/// 扫描用户指定目录下的字体文件，通过 FontLoader 动态注册到 Flutter。
class FontDownloadManager {
  static final FontDownloadManager _instance = FontDownloadManager._internal();
  factory FontDownloadManager() => _instance;
  FontDownloadManager._internal();

  /// 已加载的字体 family 集合（避免重复注册）
  final Set<String> _loadedFonts = {};

  /// 支持的字体文件扩展名
  static const List<String> _fontExtensions = ['.ttf', '.otf', '.ttc'];

  /// 扫描指定目录下的字体文件
  Future<List<FontFileInfo>> scanFontDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      debugPrint('[FontScan] 目录不存在: $dirPath');
      return [];
    }

    final fonts = <FontFileInfo>[];
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (_fontExtensions.contains(ext)) {
            final fileName = path.basename(entity.path);
            fonts.add(FontFileInfo(
              path: entity.path,
              fileName: fileName,
              displayName: _formatFontName(fileName),
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('[FontScan] 扫描异常: $e');
    }
    // 按文件名排序
    fonts.sort((a, b) => a.fileName.compareTo(b.fileName));
    debugPrint('[FontScan] 扫描完成: $dirPath, 找到 ${fonts.length} 个字体文件');
    return fonts;
  }

  /// 从字体文件名生成显示名称
  String _formatFontName(String fileName) {
    // 移除扩展名
    var name = path.basenameWithoutExtension(fileName);
    // 替换常见分隔符为空格
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    // 首字母大写
    return name.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// 加载指定字体文件
  ///
  /// [filePath] 字体文件完整路径
  /// [family] 可选的字体 family 名称（默认使用文件名）
  ///
  /// 返回加载成功后的 family 名称
  Future<String?> loadFontFile(String filePath, {String? family}) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileName = path.basename(filePath);
    final familyName = family ?? path.basenameWithoutExtension(fileName);

    // 已加载过，直接返回
    if (_loadedFonts.contains(familyName)) {
      return familyName;
    }

    try {
      final bytes = await file.readAsBytes();
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFonts.add(familyName);
      debugPrint('[FontDownload] 字体加载成功: $familyName');
      return familyName;
    } catch (e) {
      debugPrint('[FontDownload] 字体加载失败: $familyName, error=$e');
      return null;
    }
  }

  /// 预加载已缓存的字体（应用启动时调用）
  Future<void> preloadCachedFont(String family) async {
    if (family.isEmpty) return;
    if (_loadedFonts.contains(family)) return;

    // 尝试从默认字体目录加载
    try {
      final fontDir = await _getFontDir();
      final file = File(path.join(fontDir.path, '$family.ttf'));
      if (await file.exists()) {
        await loadFontFile(file.path, family: family);
        return;
      }
      // 尝试其他扩展名
      for (final ext in ['.otf', '.ttc']) {
        final file2 = File(path.join(fontDir.path, '$family$ext'));
        if (await file2.exists()) {
          await loadFontFile(file2.path, family: family);
          return;
        }
      }
    } catch (e) {
      debugPrint('[FontDownload] 预加载失败: $family, error=$e');
    }
  }

  /// 获取字体缓存目录
  Future<Directory> _getFontDir() async {
    if (Platform.isAndroid) {
      final fontDir = Directory('/sdcard/Documents/mooknote/fonts');
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }
      return fontDir;
    }
    // iOS / 桌面端 fallback
    final appDirPath = await ImagePathHelper.getAppDir();
    final fontDir = Directory(path.join(appDirPath, 'fonts'));
    if (!await fontDir.exists()) {
      await fontDir.create(recursive: true);
    }
    return fontDir;
  }

  /// 清理所有下载的字体缓存
  Future<void> clearAllCache() async {
    try {
      final fontDir = await _getFontDir();
      if (await fontDir.exists()) {
        await for (final entity in fontDir.list()) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      _loadedFonts.clear();
      debugPrint('[FontDownload] 字体缓存已清理');
    } catch (e) {
      debugPrint('[FontDownload] 清理缓存失败: $e');
    }
  }
}

/// 字体文件信息
class FontFileInfo {
  final String path;
  final String fileName;
  final String displayName;

  FontFileInfo({
    required this.path,
    required this.fileName,
    required this.displayName,
  });
}

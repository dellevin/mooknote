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

  /// 上次加载失败的具体原因（供 UI 提示）
  String? lastError;

  /// 该 family 是否已注册到 Flutter（已注册的字体可直接用于字形预览）
  bool isFamilyLoaded(String family) => _loadedFonts.contains(family);

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
    lastError = null;
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[FontDownload] 字体文件不存在: $filePath');
      lastError = '字体文件不存在';
      return null;
    }

    final fileName = path.basename(filePath);
    final familyName = family ?? path.basenameWithoutExtension(fileName);

    // 已加载过，直接返回
    if (_loadedFonts.contains(familyName)) {
      return familyName;
    }

    try {
      final bytes = await file.readAsBytes();
      // FontLoader 对无效字体数据会静默"成功"（注册后 family 名下无字形，
      // 界面回退默认字体，表现为"切换了但不变"），必须先校验文件头
      final invalidReason = _invalidFontReason(bytes);
      if (invalidReason != null) {
        lastError = invalidReason;
        debugPrint('[FontDownload] 字体加载失败: $familyName, $invalidReason (${bytes.length} 字节, 来源: $filePath)');
        return null;
      }
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      _loadedFonts.add(familyName);
      debugPrint('[FontDownload] 字体加载成功: $familyName (${bytes.length} 字节, 来源: $filePath)');
      // 复制到缓存目录，否则重启后 preloadCachedFont 找不到文件
      await _persistFontFile(file, familyName);
      return familyName;
    } catch (e) {
      debugPrint('[FontDownload] 字体加载失败: $familyName, error=$e');
      lastError = '字体加载失败: $e';
      return null;
    }
  }

  /// 校验字体文件头魔数，返回失败原因（null = 有效）
  static String? _invalidFontReason(Uint8List bytes) {
    if (bytes.length < 4) return '文件损坏（不足 4 字节）';
    final sig = String.fromCharCodes(bytes.sublist(0, 4));
    if (sig == 'wOFF' || sig == 'wOF2') {
      return '这是 WOFF 网页字体，不是真正的 TTF/OTF，请更换字体文件';
    }
    final isTtf =
        bytes[0] == 0x00 && bytes[1] == 0x01 && bytes[2] == 0x00 && bytes[3] == 0x00;
    if (isTtf || sig == 'OTTO' || sig == 'ttcf' || sig == 'true') return null;
    return '无法识别的字体格式（文件头不是 TTF/OTF/TTC）';
  }

  /// 把字体文件复制到缓存目录（源文件已在缓存目录则跳过）
  Future<void> _persistFontFile(File source, String familyName) async {
    try {
      final fontDir = await _getFontDir();
      final ext = path.extension(source.path).toLowerCase();
      final dest = File(path.join(fontDir.path, '$familyName$ext'));
      if (source.path == dest.path) return;
      // /sdcard 与 /storage/emulated/0 是同一目录的不同写法，字符串比较拦不住，
      // 必须用 identical 判同一文件，否则"自己复制自己"会把字体文件截断
      if (await dest.exists() &&
          await FileSystemEntity.identical(source.path, dest.path)) {
        return;
      }
      await source.copy(dest.path);
      debugPrint('[FontDownload] 字体已缓存: ${dest.path}');
    } catch (e) {
      debugPrint('[FontDownload] 字体缓存失败: $e');
    }
  }

  /// 预加载已缓存的字体（应用启动时调用）
  /// 返回是否成功注册字体
  Future<bool> preloadCachedFont(String family) async {
    if (family.isEmpty) return false;
    if (_loadedFonts.contains(family)) return true;

    debugPrint('[FontDownload] 启动预加载: $family');
    // 尝试从默认字体目录加载
    try {
      final fontDir = await _getFontDir();
      for (final ext in ['.ttf', '.otf', '.ttc']) {
        final file = File(path.join(fontDir.path, '$family$ext'));
        if (await file.exists()) {
          final result = await loadFontFile(file.path, family: family);
          return result != null;
        }
      }
      debugPrint('[FontDownload] 预加载失败: 缓存目录未找到 $family (${fontDir.path})');
    } catch (e) {
      debugPrint('[FontDownload] 预加载异常: $family, error=$e');
    }
    return false;
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

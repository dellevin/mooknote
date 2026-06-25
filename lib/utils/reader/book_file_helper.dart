import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 阅读器文件路径管理
class BookFileHelper {
  static final BookFileHelper instance = BookFileHelper._init();
  BookFileHelper._init();

  String? _rootPath;

  Future<String> get _root async {
    if (_rootPath != null) return _rootPath!;
    final dir = await getApplicationDocumentsDirectory();
    _rootPath = p.join(dir.path, 'mooknote', 'book_file');
    await Directory(_rootPath!).create(recursive: true);
    return _rootPath!;
  }

  Future<String> get bookFileRoot async => _root;

  Future<String> get coverDir async {
    final root = await _root;
    final dir = p.join(root, 'cover');
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<String> bookDir(String bookId) async {
    final root = await _root;
    final dir = p.join(root, bookId);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  Future<String> bookFile(String bookId, String fileName) async {
    final dir = await bookDir(bookId);
    return p.join(dir, fileName);
  }

  String? relativePath(String absolutePath) {
    if (_rootPath == null) return null;
    if (absolutePath.startsWith(_rootPath!)) {
      return absolutePath.substring(_rootPath!.length + 1);
    }
    return null;
  }

  Future<String> absolutePath(String relativePath) async {
    final root = await _root;
    return p.join(root, relativePath);
  }

  Future<void> deleteBookFiles(String bookId) async {
    final dir = await bookDir(bookId);
    if (await Directory(dir).exists()) {
      await Directory(dir).delete(recursive: true);
    }
  }

  /// 同步初始化（必须在使用 resolveAbsolutePath 前调用一次 bookFileRoot）
  Future<void> ensureInitialized() async {
    await _root;
  }

  /// 根据相对路径解析绝对路径（调用前需确保已初始化）
  String resolveAbsolutePath(String relativePath) {
    if (_rootPath == null) return relativePath;
    return p.join(_rootPath!, relativePath);
  }
}

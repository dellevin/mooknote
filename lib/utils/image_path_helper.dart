import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 图片路径管理助手 - 按分类和ID组织图片存储
/// 
/// 存储结构：
/// images/movies/{movieId}/xxxx.jpg              - 影视海报
/// images/movies/{movieId}/posterimgs/xxxx.jpg   - 影视海报墙图片
/// images/books/{bookId}/xxxx.jpg                - 书籍封面
/// images/notes/{noteId}/xxxx.jpg                - 笔记图片
class ImagePathHelper {
  static final ImagePathHelper instance = ImagePathHelper._init();
  
  ImagePathHelper._init();
  
  String? _appDirPath;
  
  /// 获取应用文档目录
  Future<String> get _appDir async {
    if (_appDirPath != null) return _appDirPath!;
    final appDir = await getApplicationDocumentsDirectory();
    _appDirPath = appDir.path;
    return _appDirPath!;
  }
  
  /// 获取图片根目录
  Future<String> get imagesRoot async {
    final appDir = await _appDir;
    return p.join(appDir, 'images');
  }
  
  // ==================== 影视相关路径 ====================
  
  /// 获取影视图片目录
  /// 路径: images/movies/{movieId}/
  Future<String> getMovieImagesDir(String movieId) async {
    final root = await imagesRoot;
    return p.join(root, 'movies', movieId);
  }
  
  /// 获取影视海报路径
  /// 路径: images/movies/{movieId}/{fileName}
  Future<String> getMoviePosterPath(String movieId, String fileName) async {
    final dir = await getMovieImagesDir(movieId);
    return p.join(dir, fileName);
  }
  
  /// 获取影视海报墙目录
  /// 路径: images/movies/{movieId}/posterimgs/
  Future<String> getMoviePosterImgsDir(String movieId) async {
    final dir = await getMovieImagesDir(movieId);
    return p.join(dir, 'posterimgs');
  }
  
  /// 获取影视海报墙图片路径
  /// 路径: images/movies/{movieId}/posterimgs/{fileName}
  Future<String> getMoviePosterImgPath(String movieId, String fileName) async {
    final dir = await getMoviePosterImgsDir(movieId);
    return p.join(dir, fileName);
  }
  
  // ==================== 书籍相关路径 ====================
  
  /// 获取书籍图片目录
  /// 路径: images/books/{bookId}/
  Future<String> getBookImagesDir(String bookId) async {
    final root = await imagesRoot;
    return p.join(root, 'books', bookId);
  }
  
  /// 获取书籍封面路径
  /// 路径: images/books/{bookId}/{fileName}
  Future<String> getBookCoverPath(String bookId, String fileName) async {
    final dir = await getBookImagesDir(bookId);
    return p.join(dir, fileName);
  }
  
  // ==================== 笔记相关路径 ====================
  
  /// 获取笔记图片目录
  /// 路径: images/notes/{noteId}/
  Future<String> getNoteImagesDir(String noteId) async {
    final root = await imagesRoot;
    return p.join(root, 'notes', noteId);
  }
  
  /// 获取笔记图片路径
  /// 路径: images/notes/{noteId}/{fileName}
  Future<String> getNoteImagePath(String noteId, String fileName) async {
    final dir = await getNoteImagesDir(noteId);
    return p.join(dir, fileName);
  }
  
  // ==================== 目录操作 ====================
  
  /// 确保目录存在
  Future<void> ensureDirExists(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
  
  /// 删除影视图片目录（包括海报和海报墙）
  /// 删除路径: images/movies/{movieId}/
  Future<void> deleteMovieImages(String movieId) async {
    final dirPath = await getMovieImagesDir(movieId);
    await _deleteDirectory(dirPath);
  }
  
  /// 删除书籍图片目录
  /// 删除路径: images/books/{bookId}/
  Future<void> deleteBookImages(String bookId) async {
    final dirPath = await getBookImagesDir(bookId);
    await _deleteDirectory(dirPath);
  }
  
  /// 删除笔记图片目录
  /// 删除路径: images/notes/{noteId}/
  Future<void> deleteNoteImages(String noteId) async {
    final dirPath = await getNoteImagesDir(noteId);
    await _deleteDirectory(dirPath);
  }
  
  /// 删除目录及其内容
  Future<void> _deleteDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
  
  /// 移动文件到新位置
  Future<String> moveFile(String sourcePath, String targetDir, String fileName) async {
    await ensureDirExists(targetDir);
    final targetPath = p.join(targetDir, fileName);
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.rename(targetPath);
    }
    return targetPath;
  }
  
  /// 复制文件到新位置
  Future<String> copyFile(String sourcePath, String targetDir, String fileName) async {
    await ensureDirExists(targetDir);
    final targetPath = p.join(targetDir, fileName);
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
    }
    return targetPath;
  }
  
  /// 删除单个文件
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

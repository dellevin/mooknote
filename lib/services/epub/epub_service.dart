import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'epub_parser.dart';
import '../../data/epub/reader_dao.dart';
import '../../data/epub/reader_models.dart';
import '../../utils/image_path_helper.dart';

/// EPUB 服务层 - 管理导入、解压、删除
class EpubService {
  final ReaderDao _dao = ReaderDao();
  final EpubParser _parser = EpubParser();
  static const _uuid = Uuid();

  /// 导入 EPUB 文件
  /// 返回 {'bookId': ..., 'title': ...} 或 null（解析失败）
  Future<Map<String, dynamic>?> importBook(String sourcePath) async {
    final bookId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final fileName = p.basename(sourcePath);

    // 复制 EPUB 到永久存储（FilePicker 临时文件会被清理）
    final appDirPath = await ImagePathHelper.getAppDir();
    final bookDir = Directory(p.join(appDirPath, 'epub_books', bookId));
    if (!await bookDir.exists()) await bookDir.create(recursive: true);
    final permanentPath = p.join(bookDir.path, 'book.epub');
    await File(sourcePath).copy(permanentPath);

    // 从永久副本解析
    final info = await _parser.parseFromFile(
      permanentPath,
      fileName: fileName,
    );
    if (info == null) return null;

    // 解压到临时目录
    final extractDir = await getExtractDir(bookId);
    await _extractEpub(permanentPath, extractDir);

    // 提取封面
    String? coverPath;
    if (info.coverHref != null) {
      coverPath = await _extractCover(info, extractDir, bookId);
    }

    // 写入数据库（file_path 存永久路径）
    await _dao.insertReaderBook({
      'id': bookId,
      'title': info.title,
      'author': info.author,
      'cover_path': coverPath,
      'file_path': permanentPath,
      'file_name': fileName,
      'file_extension': 'epub',
      'last_read_cfi': '',
      'reading_percentage': 0.0,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
    });

    return {'bookId': bookId, 'title': info.title};
  }

  /// 解压 EPUB 到目标目录
  Future<void> _extractEpub(String sourcePath, String targetDir) async {
    final dir = Directory(targetDir);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final bytes = await File(sourcePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = p.join(targetDir, file.name);
      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  /// 提取封面图片
  Future<String?> _extractCover(
      EpubBookInfo info, String extractDir, String bookId) async {
    try {
      final opfDir = info.opfRootPath.contains('/')
          ? info.opfRootPath.substring(0, info.opfRootPath.lastIndexOf('/'))
          : '';
      final coverRelPath = opfDir.isEmpty
          ? info.coverHref!
          : '$opfDir/${info.coverHref!}';
      final coverFile = File(p.join(extractDir, coverRelPath));
      if (!await coverFile.exists()) return null;

      // 保存到 epub_books/{bookId}/ 目录下
      final appDirPath = await ImagePathHelper.getAppDir();
      final coverDir = p.join(appDirPath, 'epub_books', bookId);
      await Directory(coverDir).create(recursive: true);
      final ext = p.extension(coverFile.path).toLowerCase();
      final destPath = p.join(coverDir, 'cover$ext');
      await coverFile.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// 获取解压目录
  Future<String> getExtractDir(String bookId) async {
    final tempDir = await getTemporaryDirectory();
    return p.join(tempDir.path, 'epub', bookId);
  }

  /// 确保已解压（如果临时目录被清理则重新解压）
  /// 返回解压目录路径，失败返回 null
  Future<String?> ensureExtracted(String bookId, String filePath) async {
    final extractDir = await getExtractDir(bookId);
    final dir = Directory(extractDir);

    if (await dir.exists()) {
      final files = dir.listSync();
      if (files.isNotEmpty) return extractDir;
    }

    // 重新解压
    if (!await File(filePath).exists()) return null;
    await _extractEpub(filePath, extractDir);
    return extractDir;
  }

  /// 删除书籍
  Future<void> deleteBook(String bookId) async {
    // 清理解压目录
    try {
      final extractDir = await getExtractDir(bookId);
      final dir = Directory(extractDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}

    // 清理 epub_books/{bookId}/ 目录（epub + 封面）
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final bookDir = Directory(p.join(appDirPath, 'epub_books', bookId));
      if (await bookDir.exists()) await bookDir.delete(recursive: true);
    } catch (_) {}

    // 软删除数据库记录
    await _dao.deleteReaderBook(bookId);
  }
}

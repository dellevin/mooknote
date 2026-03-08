import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

/// 数据备份服务 - 支持导出和导入数据（包含图片）
class BackupService {
  static final BackupService instance = BackupService._init();
  
  BackupService._init();
  
  /// 导出所有数据和图片为 ZIP 文件，并选择保存路径
  Future<ExportResult> exportDataWithImages() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 导出所有表的数据
      final movies = await db.query('movies');
      final books = await db.query('books');
      final notes = await db.query('notes');
      final movieReviews = await db.query('movie_reviews');
      final moviePosters = await db.query('movie_posters');
      
      // 收集所有图片路径
      final imagePaths = <String>{};
      
      // 收集影视海报
      for (final movie in movies) {
        final posterPath = movie['poster_path'] as String?;
        if (posterPath != null && posterPath.isNotEmpty) {
          imagePaths.add(posterPath);
        }
      }
      
      // 收集书籍封面
      for (final book in books) {
        final coverPath = book['cover_path'] as String?;
        if (coverPath != null && coverPath.isNotEmpty) {
          imagePaths.add(coverPath);
        }
      }
      
      // 收集海报墙图片
      for (final poster in moviePosters) {
        final posterPath = poster['poster_path'] as String?;
        if (posterPath != null && posterPath.isNotEmpty) {
          imagePaths.add(posterPath);
        }
      }
      
      // 收集笔记图片
      for (final note in notes) {
        final imagesJson = note['images'] as String?;
        if (imagesJson != null && imagesJson.isNotEmpty) {
          try {
            final images = jsonDecode(imagesJson) as List<dynamic>;
            for (final imagePath in images) {
              if (imagePath is String && imagePath.isNotEmpty) {
                imagePaths.add(imagePath);
              }
            }
          } catch (e) {
            // 解析失败，跳过
          }
        }
      }
      
      // 构建备份数据
      final backupData = {
        'version': 2,
        'exportTime': DateTime.now().toIso8601String(),
        'appName': 'MookNote',
        'hasImages': true,
        'data': {
          'movies': movies,
          'books': books,
          'notes': notes,
          'movie_reviews': movieReviews,
          'movie_posters': moviePosters,
        },
      };
      
      // 创建 ZIP 文件
      final archive = Archive();
      
      // 添加 JSON 数据
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      
      // 添加图片文件，保持目录结构
      int imageCount = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final imagesRoot = path.join(appDir.path, 'images');
      
      for (final imagePath in imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          // 计算相对路径（如 movies/1/poster.jpg）
          String relativePath;
          if (imagePath.startsWith(imagesRoot)) {
            relativePath = imagePath.substring(imagesRoot.length + 1); // +1 去掉开头的 /
          } else {
            relativePath = path.basename(imagePath);
          }
          // 使用相对路径存储图片，保持目录结构
          archive.addFile(ArchiveFile('images/$relativePath', bytes.length, bytes));
          imageCount++;
        }
      }
      
      // 压缩 ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        return ExportResult.error('压缩备份文件失败');
      }
      
      // 保存到临时目录
      final tempDir = await getTemporaryDirectory();
      final fileName = 'mooknote_backup_${_formatDateTime(DateTime.now())}.zip';
      final tempFilePath = path.join(tempDir.path, fileName);
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(zipBytes);
      
      // 在移动端使用分享功能，让用户选择保存位置
      // 在桌面端可以尝试使用 saveFile
      String? finalPath;
      
      try {
        // 尝试使用系统保存对话框（桌面端支持）
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: Uint8List.fromList(zipBytes),  // 在移动端需要提供 bytes
        );
        
        if (outputPath == null) {
          // 用户取消，返回临时文件路径
          finalPath = tempFilePath;
        } else {
          finalPath = outputPath;
          // 如果保存路径不是临时文件路径，需要复制过去
          if (finalPath != tempFilePath) {
            final outputFile = File(finalPath);
            await outputFile.writeAsBytes(zipBytes);
          }
        }
      } catch (e) {
        // 如果 saveFile 失败，使用临时文件路径
        finalPath = tempFilePath;
      }
      
      return ExportResult.success(
        filePath: finalPath,
        movieCount: movies.length,
        bookCount: books.length,
        noteCount: notes.length,
        imageCount: imageCount,
      );
    } catch (e) {
      return ExportResult.error('导出失败: $e');
    }
  }
  
  /// 分享备份文件
  Future<void> shareBackup(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles(
      [file],
      subject: 'MookNote 数据备份',
      text: '这是我的 MookNote 数据备份文件',
    );
  }
  
  /// 导出数据用于自动备份（返回字节数据而不是保存到文件）
  Future<AutoBackupExportResult> exportDataForAutoBackup() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // 导出所有表的数据
      final movies = await db.query('movies');
      final books = await db.query('books');
      final notes = await db.query('notes');
      final movieReviews = await db.query('movie_reviews');
      final moviePosters = await db.query('movie_posters');
      
      // 收集所有图片路径
      final imagePaths = <String>{};
      
      // 收集影视海报
      for (final movie in movies) {
        final posterPath = movie['poster_path'] as String?;
        if (posterPath != null && posterPath.isNotEmpty) {
          imagePaths.add(posterPath);
        }
      }
      
      // 收集书籍封面
      for (final book in books) {
        final coverPath = book['cover_path'] as String?;
        if (coverPath != null && coverPath.isNotEmpty) {
          imagePaths.add(coverPath);
        }
      }
      
      // 收集海报墙图片
      for (final poster in moviePosters) {
        final posterPath = poster['poster_path'] as String?;
        if (posterPath != null && posterPath.isNotEmpty) {
          imagePaths.add(posterPath);
        }
      }
      
      // 收集笔记图片
      for (final note in notes) {
        final imagesJson = note['images'] as String?;
        if (imagesJson != null && imagesJson.isNotEmpty) {
          try {
            final images = jsonDecode(imagesJson) as List<dynamic>;
            for (final imagePath in images) {
              if (imagePath is String && imagePath.isNotEmpty) {
                imagePaths.add(imagePath);
              }
            }
          } catch (e) {
            // 解析失败，跳过
          }
        }
      }
      
      // 构建备份数据
      final backupData = {
        'version': 2,
        'exportTime': DateTime.now().toIso8601String(),
        'appName': 'MookNote',
        'hasImages': true,
        'data': {
          'movies': movies,
          'books': books,
          'notes': notes,
          'movie_reviews': movieReviews,
          'movie_posters': moviePosters,
        },
      };
      
      // 创建 ZIP 文件
      final archive = Archive();
      
      // 添加 JSON 数据
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      
      // 添加图片文件，保持目录结构
      int imageCount = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final imagesRoot = path.join(appDir.path, 'images');
      
      for (final imagePath in imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          // 计算相对路径（如 movies/1/poster.jpg）
          String relativePath;
          if (imagePath.startsWith(imagesRoot)) {
            relativePath = imagePath.substring(imagesRoot.length + 1);
          } else {
            relativePath = path.basename(imagePath);
          }
          // 使用相对路径存储图片，保持目录结构
          archive.addFile(ArchiveFile('images/$relativePath', bytes.length, bytes));
          imageCount++;
        }
      }
      
      // 压缩 ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        return AutoBackupExportResult.error('压缩备份文件失败');
      }
      
      return AutoBackupExportResult.success(
        zipBytes: Uint8List.fromList(zipBytes),
        movieCount: movies.length,
        bookCount: books.length,
        noteCount: notes.length,
        imageCount: imageCount,
      );
    } catch (e) {
      return AutoBackupExportResult.error('导出失败: $e');
    }
  }
  
  /// 选择并导入备份文件（支持 ZIP 格式）
  Future<ImportResult> importData() async {
    try {
      // 选择文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );
      
      if (result == null || result.files.isEmpty) {
        return ImportResult.cancelled();
      }
      
      final filePath = result.files.first.path;
      if (filePath == null) {
        return ImportResult.error('无法读取文件路径');
      }
      
      final file = File(filePath);
      final extension = path.extension(filePath).toLowerCase();
      
      Map<String, dynamic> backupData;
      int imageCount = 0;
      // 记录图片文件名到新路径的映射
      final imagePathMap = <String, String>{};
      
      if (extension == '.zip') {
        // 处理 ZIP 文件
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        
        // 查找 data.json
        final dataFile = archive.findFile('data.json');
        if (dataFile == null) {
          return ImportResult.error('备份文件中没有找到数据文件');
        }
        
        final jsonString = utf8.decode(dataFile.content as List<int>);
        backupData = jsonDecode(jsonString) as Map<String, dynamic>;
        
        // 解压图片到应用目录，保持目录结构
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        
        for (final archiveFile in archive) {
          if (archiveFile.name.startsWith('images/')) {
            // 获取相对路径（如 movies/1/poster.jpg）
            final relativePath = archiveFile.name.substring(7); // 去掉 'images/' 前缀
            final outputFile = File(path.join(imagesDir.path, relativePath));
            
            // 确保父目录存在
            final parentDir = outputFile.parent;
            if (!await parentDir.exists()) {
              await parentDir.create(recursive: true);
            }
            
            await outputFile.writeAsBytes(archiveFile.content as List<int>);
            
            // 记录文件名到新路径的映射（用于更新数据库中的路径）
            final fileName = path.basename(archiveFile.name);
            imagePathMap[fileName] = outputFile.path;
            imageCount++;
          }
        }
      } else {
        // 处理旧版 JSON 文件
        final jsonString = await file.readAsString();
        backupData = jsonDecode(jsonString) as Map<String, dynamic>;
      }
      
      // 验证备份格式
      if (!backupData.containsKey('data')) {
        return ImportResult.error('无效的备份文件格式');
      }
      
      // 导入数据
      final data = backupData['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;
      
      // 开始事务
      await db.transaction((txn) async {
        // 清空现有数据
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        
        // 导入影视数据（更新图片路径）
        if (data.containsKey('movies')) {
          final movies = data['movies'] as List<dynamic>;
          for (final movie in movies) {
            final movieMap = _convertToDbMap(movie);
            final updatedMap = _updateImagePath(movieMap, 'poster_path', imagePathMap);
            await txn.insert('movies', updatedMap);
          }
        }
        
        // 导入书籍数据（更新图片路径）
        if (data.containsKey('books')) {
          final books = data['books'] as List<dynamic>;
          for (final book in books) {
            final bookMap = _convertToDbMap(book);
            final updatedMap = _updateImagePath(bookMap, 'cover_path', imagePathMap);
            await txn.insert('books', updatedMap);
          }
        }
        
        // 导入笔记数据（更新图片路径）
        if (data.containsKey('notes')) {
          final notes = data['notes'] as List<dynamic>;
          for (final note in notes) {
            final noteMap = _convertToDbMap(note);
            final updatedMap = _updateNoteImagesPath(noteMap, imagePathMap);
            await txn.insert('notes', updatedMap);
          }
        }
        
        // 导入影评数据
        if (data.containsKey('movie_reviews')) {
          final reviews = data['movie_reviews'] as List<dynamic>;
          for (final review in reviews) {
            await txn.insert('movie_reviews', _convertToDbMap(review));
          }
        }
        
        // 导入海报墙数据（更新图片路径）
        if (data.containsKey('movie_posters')) {
          final posters = data['movie_posters'] as List<dynamic>;
          for (final poster in posters) {
            final posterMap = _convertToDbMap(poster);
            final updatedMap = _updateImagePath(posterMap, 'poster_path', imagePathMap);
            await txn.insert('movie_posters', updatedMap);
          }
        }
      });
      
      // 统计导入数量
      final stats = <String, int>{};
      if (data.containsKey('movies')) {
        stats['影视'] = (data['movies'] as List).length;
      }
      if (data.containsKey('books')) {
        stats['书籍'] = (data['books'] as List).length;
      }
      if (data.containsKey('notes')) {
        stats['笔记'] = (data['notes'] as List).length;
      }
      if (data.containsKey('movie_reviews')) {
        stats['影评'] = (data['movie_reviews'] as List).length;
      }
      if (data.containsKey('movie_posters')) {
        stats['海报'] = (data['movie_posters'] as List).length;
      }
      if (imageCount > 0) {
        stats['图片'] = imageCount;
      }
      
      return ImportResult.success(stats);
    } catch (e) {
      return ImportResult.error('导入失败: $e');
    }
  }
  
  /// 将动态类型转换为数据库可用的 Map
  Map<String, dynamic> _convertToDbMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item.map((key, value) {
        // 处理布尔值
        if (value is bool) {
          return MapEntry(key, value ? 1 : 0);
        }
        return MapEntry(key, value);
      });
    }
    return {};
  }
  
  /// 更新图片路径为新的路径
  /// 支持新的存储结构：images/movies/{id}/、images/books/{id}/、images/notes/{id}/
  Map<String, dynamic> _updateImagePath(
    Map<String, dynamic> item,
    String pathField,
    Map<String, String> imagePathMap,
  ) {
    final newItem = Map<String, dynamic>.from(item);
    final oldPath = item[pathField] as String?;
    
    if (oldPath != null && oldPath.isNotEmpty) {
      final fileName = path.basename(oldPath);
      // 如果图片在映射中，更新路径
      if (imagePathMap.containsKey(fileName)) {
        newItem[pathField] = imagePathMap[fileName];
      } else {
        // 尝试从旧版备份中恢复（旧版只保存了文件名）
        // 检查是否有匹配的文件名（不区分目录结构）
        for (final entry in imagePathMap.entries) {
          if (path.basename(entry.key) == fileName) {
            newItem[pathField] = entry.value;
            break;
          }
        }
      }
    }
    
    return newItem;
  }
  
  /// 更新笔记图片路径为新的路径
  /// 支持新的存储结构：images/notes/{id}/
  Map<String, dynamic> _updateNoteImagesPath(
    Map<String, dynamic> item,
    Map<String, String> imagePathMap,
  ) {
    final newItem = Map<String, dynamic>.from(item);
    final imagesJson = item['images'] as String?;
    
    if (imagesJson != null && imagesJson.isNotEmpty) {
      try {
        final images = jsonDecode(imagesJson) as List<dynamic>;
        final updatedImages = <String>[];
        
        for (final imagePath in images) {
          if (imagePath is String && imagePath.isNotEmpty) {
            final fileName = path.basename(imagePath);
            // 如果图片在映射中，更新路径
            if (imagePathMap.containsKey(fileName)) {
              updatedImages.add(imagePathMap[fileName]!);
            } else {
              // 尝试从旧版备份中恢复（旧版只保存了文件名）
              bool found = false;
              for (final entry in imagePathMap.entries) {
                if (path.basename(entry.key) == fileName) {
                  updatedImages.add(entry.value);
                  found = true;
                  break;
                }
              }
              if (!found) {
                updatedImages.add(imagePath);
              }
            }
          }
        }
        
        newItem['images'] = jsonEncode(updatedImages);
      } catch (e) {
        // 解析失败，保持原样
      }
    }
    
    return newItem;
  }
  
  /// 格式化日期时间用于文件名
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}_${_pad(dateTime.hour)}${_pad(dateTime.minute)}${_pad(dateTime.second)}';
  }
  
  String _pad(int number) {
    return number.toString().padLeft(2, '0');
  }
}

/// 自动备份导出结果
class AutoBackupExportResult {
  final bool success;
  final String? errorMessage;
  final Uint8List? zipBytes;
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;
  
  AutoBackupExportResult._({
    required this.success,
    this.errorMessage,
    this.zipBytes,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
  });
  
  factory AutoBackupExportResult.success({
    required Uint8List zipBytes,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
  }) {
    return AutoBackupExportResult._(
      success: true,
      zipBytes: zipBytes,
      movieCount: movieCount,
      bookCount: bookCount,
      noteCount: noteCount,
      imageCount: imageCount,
    );
  }
  
  factory AutoBackupExportResult.error(String message) {
    return AutoBackupExportResult._(success: false, errorMessage: message);
  }
}

/// 导出结果
class ExportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? filePath;
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;
  
  ExportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.filePath,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
  });
  
  factory ExportResult.success({
    required String filePath,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
  }) {
    return ExportResult._(
      success: true,
      filePath: filePath,
      movieCount: movieCount,
      bookCount: bookCount,
      noteCount: noteCount,
      imageCount: imageCount,
    );
  }
  
  factory ExportResult.cancelled() {
    return ExportResult._(success: false, cancelled: true);
  }
  
  factory ExportResult.error(String message) {
    return ExportResult._(success: false, errorMessage: message);
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final Map<String, int>? stats;
  
  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.stats,
  });
  
  factory ImportResult.success(Map<String, int> stats) {
    return ImportResult._(success: true, stats: stats);
  }
  
  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }
  
  factory ImportResult.error(String message) {
    return ImportResult._(success: false, errorMessage: message);
  }
  
  /// 获取统计信息文本
  String get statsText {
    if (stats == null || stats!.isEmpty) {
      return '没有导入任何数据';
    }
    return stats!.entries.map((e) => '${e.key}: ${e.value}').join('，');
  }
}

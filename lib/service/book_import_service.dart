import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/reader_book.dart';
import '../providers/app_provider.dart';
import '../utils/reader/book_file_helper.dart';

/// 书籍导入服务
class BookImportService {
  static const allowedExtensions = ['epub', 'txt'];

  static Future<ReaderBook?> pickAndImportBook(
    BuildContext context,
    AppProvider provider,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final platformFile = result.files.first;
    final sourcePath = platformFile.path;
    if (sourcePath == null) return null;

    final file = File(sourcePath);
    if (!await file.exists()) return null;

    final extension = p.extension(file.path).replaceAll('.', '').toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('不支持的格式：$extension')),
        );
      }
      return null;
    }

    final title = p.basenameWithoutExtension(platformFile.name);
    final helper = BookFileHelper.instance;
    final id = const Uuid().v4();

    // 清理文件名，去除特殊字符
    final safeName = platformFile.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final destPath = await helper.bookFile(id, safeName);

    // 复制文件
    await file.copy(destPath);

    final now = DateTime.now();
    final readerBook = ReaderBook(
      id: id,
      title: title,
      fileName: platformFile.name,
      filePath: '$id/$safeName', // 相对路径
      fileExtension: extension,
      createdAt: now,
      updatedAt: now,
    );

    await provider.addReaderBook(readerBook);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$title」导入成功')),
      );
    }

    return readerBook;
  }
}

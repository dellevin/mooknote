import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_strings.dart';
import '../models/data_models.dart';

/// 数据导出为 Excel 文件
class ExcelExporter {
  /// 导出影视数据，返回生成的文件
  static Future<File> exportMovies(List<Movie> movies) async {
    final excel = Excel.createExcel();
    final sheet = excel['影视'.tr];

    sheet.appendRow(_row([
      '名称'.tr, '类别'.tr, '状态'.tr, '评分'.tr, '导演'.tr, '编剧'.tr, '主演'.tr,
      '类型'.tr, '别名'.tr, '上映时间'.tr, '观看日期'.tr, '观看次数'.tr, '时长(分钟)'.tr,
      '简介'.tr, '创建时间'.tr, '更新时间'.tr,
    ]));

    final statusMap = {'watched': '已看'.tr, 'watching': '在看'.tr, 'want_to_watch': '想看'.tr};
    final categoryMap = {
      'movie': '电影'.tr, 'tv': '电视剧'.tr, 'anime': '动漫'.tr,
      'variety': '综艺'.tr, 'documentary': '纪录片'.tr, 'short': '短片'.tr, 'other': '其他'.tr,
    };

    for (final m in movies) {
      sheet.appendRow(_row([
        m.title,
        categoryMap[m.category] ?? m.category,
        statusMap[m.status] ?? m.status,
        m.rating?.toString() ?? '',
        m.directors.join('、'),
        m.writers.join('、'),
        m.actors.join('、'),
        m.genres.join('、'),
        m.alternateTitles.join('、'),
        _fmtDate(m.releaseDate),
        _fmtDate(m.watchDate),
        m.watchCount.toString(),
        m.duration.toString(),
        m.summary ?? '',
        _fmtDateTime(m.createdAt),
        _fmtDateTime(m.updatedAt),
      ]));
    }

    return _save(excel, '影视'.tr);
  }

  /// 导出阅读数据
  static Future<File> exportBooks(List<Book> books) async {
    final excel = Excel.createExcel();
    final sheet = excel['阅读'.tr];

    sheet.appendRow(_row([
      '名称'.tr, '状态'.tr, '评分'.tr, '作者'.tr, '译者'.tr, '别名'.tr, '出版社'.tr,
      '类型'.tr, 'ISBN', '出版时间'.tr, '开始阅读'.tr, '读完时间'.tr, '阅读次数'.tr,
      '简介'.tr, '创建时间'.tr, '更新时间'.tr,
    ]));

    final statusMap = {'read': '已读'.tr, 'reading': '在读'.tr, 'want_to_read': '想读'.tr};

    for (final b in books) {
      sheet.appendRow(_row([
        b.title,
        statusMap[b.status] ?? b.status,
        b.rating?.toString() ?? '',
        b.authors.join('、'),
        b.translators.join('、'),
        b.alternateTitles.join('、'),
        b.publisher ?? '',
        b.genres.join('、'),
        b.isbn ?? '',
        _fmtDate(b.publishDate),
        _fmtDate(b.startDate),
        _fmtDate(b.finishDate),
        b.readCount.toString(),
        b.summary ?? '',
        _fmtDateTime(b.createdAt),
        _fmtDateTime(b.updatedAt),
      ]));
    }

    return _save(excel, '阅读'.tr);
  }

  /// 导出游戏数据
  static Future<File> exportGames(List<Game> games) async {
    final excel = Excel.createExcel();
    final sheet = excel['游戏'.tr];

    sheet.appendRow(_row([
      '名称'.tr, '状态'.tr, '评分'.tr, '分类'.tr, '平台'.tr, '版本'.tr, '类型'.tr,
      '游玩时长(小时)'.tr, '游玩时长(分钟)'.tr, '游玩次数'.tr, '开发者'.tr,
      '发售时间'.tr, '购买平台'.tr, '购买日期'.tr, '购买价格'.tr, '简介'.tr,
      '创建时间'.tr, '更新时间'.tr,
    ]));

    final statusMap = {
      'completed': '已通关'.tr, 'playing': '在玩'.tr,
      'want_to_play': '想玩'.tr, 'abandoned': '弃游'.tr,
    };
    final categoryMap = {'digital': '数字版'.tr, 'cartridge': '卡带'.tr, 'disc': '光盘'.tr};

    for (final g in games) {
      sheet.appendRow(_row([
        g.title,
        statusMap[g.status] ?? g.status,
        g.rating?.toString() ?? '',
        categoryMap[g.category] ?? g.category,
        g.platforms.join('、'),
        g.versions.join('、'),
        g.genres.join('、'),
        g.playTimeHours.toString(),
        g.playTimeMinutes.toString(),
        g.playCount.toString(),
        g.developer.join('、'),
        _fmtDate(g.releaseDate),
        g.purchasePlatforms.join('、'),
        _fmtDate(g.purchaseDate),
        g.purchasePrice ?? '',
        g.summary ?? '',
        _fmtDateTime(g.createdAt),
        _fmtDateTime(g.updatedAt),
      ]));
    }

    return _save(excel, '游戏'.tr);
  }

  /// 导出笔记数据
  static Future<File> exportNotes(List<Note> notes) async {
    final excel = Excel.createExcel();
    final sheet = excel['笔记'.tr];

    sheet.appendRow(_row([
      '标题'.tr, '内容'.tr, '内容类型'.tr, '标签'.tr, '图片数'.tr, '是否置顶'.tr,
      '创建时间'.tr, '更新时间'.tr,
    ]));

    for (final n in notes) {
      sheet.appendRow(_row([
        n.title,
        n.content,
        n.contentType,
        n.tags.join('、'),
        n.images.length.toString(),
        n.isPinned ? '是'.tr : '否'.tr,
        _fmtDateTime(n.createdAt),
        _fmtDateTime(n.updatedAt),
      ]));
    }

    return _save(excel, '笔记'.tr);
  }

  static List<CellValue?> _row(List<String> values) {
    return values.map((v) => TextCellValue(v)).toList();
  }

  static Future<File> _save(Excel excel, String name) async {
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    final fileName = '${name}_${'导出'.tr}_${_timestamp()}.xlsx';
    String filePath;
    if (Platform.isAndroid) {
      final exportDir = Directory('/sdcard/Download/mooknote/export');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      filePath = p.join(exportDir.path, fileName);
    } else {
      final tempDir = await getTemporaryDirectory();
      filePath = p.join(tempDir.path, fileName);
    }
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
    return file;
  }

  static String _fmtDate(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _fmtDateTime(DateTime d) {
    return '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _timestamp() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
  }
}

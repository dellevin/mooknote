import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/data_models.dart';

/// 数据导出为 Excel 文件
class ExcelExporter {
  /// 导出影视数据，返回生成的文件
  static Future<File> exportMovies(List<Movie> movies) async {
    final excel = Excel.createExcel();
    final sheet = excel['影视'];

    sheet.appendRow(_row([
      '名称', '类别', '状态', '评分', '导演', '编剧', '主演',
      '类型', '别名', '上映时间', '观看日期', '观看次数', '时长(分钟)',
      '简介', '创建时间', '更新时间',
    ]));

    final statusMap = {'watched': '已看', 'watching': '在看', 'want_to_watch': '想看'};
    final categoryMap = {
      'movie': '电影', 'tv': '电视剧', 'anime': '动漫',
      'variety': '综艺', 'documentary': '纪录片', 'short': '短片', 'other': '其他',
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

    return _save(excel, '影视');
  }

  /// 导出阅读数据
  static Future<File> exportBooks(List<Book> books) async {
    final excel = Excel.createExcel();
    final sheet = excel['阅读'];

    sheet.appendRow(_row([
      '名称', '状态', '评分', '作者', '译者', '别名', '出版社',
      '类型', 'ISBN', '出版时间', '开始阅读', '读完时间', '阅读次数',
      '简介', '创建时间', '更新时间',
    ]));

    final statusMap = {'read': '已读', 'reading': '在读', 'want_to_read': '想读'};

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

    return _save(excel, '阅读');
  }

  /// 导出游戏数据
  static Future<File> exportGames(List<Game> games) async {
    final excel = Excel.createExcel();
    final sheet = excel['游戏'];

    sheet.appendRow(_row([
      '名称', '状态', '评分', '分类', '平台', '版本', '类型',
      '游玩时长(小时)', '游玩时长(分钟)', '游玩次数', '开发者',
      '发售时间', '购买平台', '购买日期', '购买价格', '简介',
      '创建时间', '更新时间',
    ]));

    final statusMap = {
      'completed': '已通关', 'playing': '在玩',
      'want_to_play': '想玩', 'abandoned': '弃游',
    };
    final categoryMap = {'digital': '数字版', 'cartridge': '卡带', 'disc': '光盘'};

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

    return _save(excel, '游戏');
  }

  /// 导出笔记数据
  static Future<File> exportNotes(List<Note> notes) async {
    final excel = Excel.createExcel();
    final sheet = excel['笔记'];

    sheet.appendRow(_row([
      '标题', '内容', '内容类型', '标签', '图片数', '是否置顶',
      '创建时间', '更新时间',
    ]));

    for (final n in notes) {
      sheet.appendRow(_row([
        n.title,
        n.content,
        n.contentType,
        n.tags.join('、'),
        n.images.length.toString(),
        n.isPinned ? '是' : '否',
        _fmtDateTime(n.createdAt),
        _fmtDateTime(n.updatedAt),
      ]));
    }

    return _save(excel, '笔记');
  }

  static List<CellValue?> _row(List<String> values) {
    return values.map((v) => TextCellValue(v)).toList();
  }

  static Future<File> _save(Excel excel, String name) async {
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    final fileName = '${name}_导出_${_timestamp()}.xlsx';
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

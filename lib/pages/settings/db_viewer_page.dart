import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/database_helper.dart';
import '../../l10n/app_strings.dart';
import '../../utils/toast_util.dart';

/// 数据库查看器（调试模式）：浏览表结构/行数/数据，执行 SELECT 查询
class DbViewerPage extends StatefulWidget {
  const DbViewerPage({super.key});

  @override
  State<DbViewerPage> createState() => _DbViewerPageState();
}

class _DbViewerPageState extends State<DbViewerPage> {
  List<({String name, int rows})> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%' ORDER BY name");
    final result = <({String name, int rows})>[];
    for (final t in tables) {
      final name = t['name'] as String;
      final c = await db
          .rawQuery('SELECT COUNT(*) AS c FROM "$name"');
      result.add((name: name, rows: (c.first['c'] as num?)?.toInt() ?? 0));
    }
    if (!mounted) return;
    setState(() {
      _tables = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('数据库查看器'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // SELECT 查询入口
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DbQueryPage())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.terminal,
                              size: 16, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('执行 SELECT 查询（只读）'.tr,
                                style: TextStyle(
                                    fontSize: 13, color: colors.primary)),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: colors.primary.withValues(alpha: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _tables.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: colors.outlineVariant),
                    itemBuilder: (context, i) {
                      final t = _tables[i];
                      return ListTile(
                        dense: true,
                        visualDensity:
                            const VisualDensity(vertical: -4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        minVerticalPadding: 0,
                        title: Text(t.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace')),
                        trailing: Text('${t.rows}',
                            style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: colors.onSurface
                                    .withValues(alpha: 0.45))),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    DbTablePage(table: t.name))),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// 单表数据浏览：展示前 200 行
class DbTablePage extends StatefulWidget {
  final String table;
  const DbTablePage({super.key, required this.table});

  @override
  State<DbTablePage> createState() => _DbTablePageState();
}

class _DbTablePageState extends State<DbTablePage> {
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper.instance.database;
    // 带 rowid 便于编辑定位
    final rows = await db.rawQuery(
        'SELECT rowid AS _rowid, * FROM "${widget.table}" LIMIT 200');
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  /// 编辑一行：按 rowid UPDATE 回数据库
  Future<void> _editRow(Map<String, Object?> row) async {
    final colors = Theme.of(context).colorScheme;
    final rowid = row['_rowid'] as int?;
    if (rowid == null) return;
    // 排除 rowid 伪列
    final fields =
        row.entries.where((e) => e.key != '_rowid').toList();
    final controllers = {
      for (final e in fields) e.key: TextEditingController(
          text: e.value?.toString() ?? ''),
    };
    // 记录原始类型（null 按 string 处理）
    final types = {for (final e in fields) e.key: e.value.runtimeType};

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('${'编辑行'.tr} (rowid=$rowid)',
            style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: controllers[e.key],
                    maxLines: null,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText:
                          '${e.key} (${_typeName(types[e.key])})',
                      labelStyle: const TextStyle(fontSize: 11),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('保存'.tr)),
        ],
      ),
    );
    if (saved != true) return;

    // 按原始类型回写
    final sets = <String>[];
    final args = <Object?>[];
    for (final e in fields) {
      sets.add('"${e.key}" = ?');
      final text = controllers[e.key]!.text;
      final t = types[e.key];
      if (t == int) {
        args.add(int.tryParse(text) ?? 0);
      } else if (t == double) {
        args.add(double.tryParse(text) ?? 0.0);
      } else {
        // null/bool/其它按 string；空文本且原为 null 保持 null
        args.add(e.value == null && text.isEmpty ? null : text);
      }
    }
    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawUpdate(
          'UPDATE "${widget.table}" SET ${sets.join(', ')} WHERE rowid = ?',
          [...args, rowid]);
      if (mounted) {
        ToastUtil.show(context, '已保存'.tr);
        _load();
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '${'保存失败'.tr}: $e');
    }
  }

  static String _typeName(Type? t) {
    if (t == int) return 'int';
    if (t == double) return 'double';
    if (t == String) return 'text';
    return 'null→text';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(widget.table,
            style: const TextStyle(fontSize: 15, fontFamily: 'monospace')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text('空表'.tr,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4))))
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      indent: 16,
                      endIndent: 16,
                      color: colors.outlineVariant),
                  itemBuilder: (context, i) => _RowTile(
                        row: _rows[i],
                        colors: colors,
                        onEdit: () => _editRow(_rows[i]),
                      ),
                ),
    );
  }
}

/// 一行数据：单行摘要（前几个字段），展开看全部字段
class _RowTile extends StatelessWidget {
  final Map<String, Object?> row;
  final ColorScheme colors;

  /// 非 null 时在展开区显示编辑按钮（仅带 _rowid 的表查询可编辑）
  final VoidCallback? onEdit;

  const _RowTile({required this.row, required this.colors, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final entries = row.entries.where((e) => e.key != '_rowid').toList();
    return Theme(
      // 去掉 ExpansionTile 默认的大内边距/分割线
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.only(left: 12, right: 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Text(
          entries.map((e) => _short(e.value)).join(' │ '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                entries
                    .map((e) => '${e.key}: ${e.value ?? 'NULL'}')
                    .join('\n'),
                style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: colors.onSurface.withValues(alpha: 0.75)),
              ),
            ),
          ),
          if (onEdit != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: Text('编辑'.tr, style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  String _short(Object? v) {
    if (v == null) return 'NULL';
    final s = v.toString().replaceAll('\n', ' ');
    return s.length > 14 ? '${s.substring(0, 14)}…' : s;
  }
}

/// SELECT 查询页（只读，拒绝非 SELECT 语句）
class DbQueryPage extends StatefulWidget {
  const DbQueryPage({super.key});

  @override
  State<DbQueryPage> createState() => _DbQueryPageState();
}

class _DbQueryPageState extends State<DbQueryPage> {
  final _controller = TextEditingController(text: 'SELECT * FROM movies LIMIT 20');
  List<Map<String, Object?>>? _rows;
  String? _error;
  bool _running = false;

  Future<void> _run() async {
    final sql = _controller.text.trim();
    if (sql.isEmpty) return;
    // 只允许 SELECT / PRAGMA / WITH（只读）
    final head = sql.split(RegExp(r'\s+')).first.toUpperCase();
    if (head != 'SELECT' && head != 'PRAGMA' && head != 'WITH') {
      setState(() {
        _error = '只允许只读查询（SELECT / PRAGMA / WITH）';
        _rows = null;
      });
      return;
    }
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(sql);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _running = false;
      });
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _rows = null;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('SELECT 查询'.tr)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 3,
                    style: const TextStyle(
                        fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow, size: 20),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(_error!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.redAccent)),
              ),
            ),
          if (_rows != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${'共'.tr} ${_rows!.length} ${'行'.tr}',
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            ),
          Expanded(
            child: _rows == null
                ? const SizedBox.shrink()
                : ListView.separated(
                    itemCount: _rows!.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: colors.outlineVariant),
                    itemBuilder: (context, i) =>
                        _RowTile(row: _rows![i], colors: colors),
                  ),
          ),
        ],
      ),
    );
  }
}

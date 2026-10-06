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

  /// 批量选择模式
  bool _selectMode = false;
  final Set<int> _selected = {};

  /// 表格模式展开的行（rowid）
  final Set<int> _expanded = {};

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

  /// 删除一行：按 rowid DELETE，带确认弹窗
  Future<void> _deleteRow(Map<String, Object?> row) async {
    final colors = Theme.of(context).colorScheme;
    final rowid = row['_rowid'] as int?;
    if (rowid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('${'删除行'.tr} (rowid=$rowid)',
            style: const TextStyle(fontSize: 14)),
        content: Text('该操作将会给数据库带来不可逆的操作，您最好确认完整了解该操作带来的后果之后进行删除'.tr,
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('删除'.tr)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.rawDelete(
          'DELETE FROM "${widget.table}" WHERE rowid = ?', [rowid]);
      if (mounted) {
        ToastUtil.show(context, '已删除'.tr);
        _load();
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '${'删除失败'.tr}: $e');
    }
  }

  /// 批量删除选中行：按 rowid IN (...) DELETE，带确认弹窗
  Future<void> _deleteSelected() async {
    final colors = Theme.of(context).colorScheme;
    if (_selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('${'批量删除'.tr} (${_selected.length} ${'行'.tr})',
            style: const TextStyle(fontSize: 14)),
        content: Text('该操作将会给数据库带来不可逆的操作，您最好确认完整了解该操作带来的后果之后进行删除'.tr,
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('删除'.tr)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final ids = _selected.toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.rawDelete(
          'DELETE FROM "${widget.table}" WHERE rowid IN ($placeholders)',
          ids);
      if (mounted) {
        ToastUtil.show(context, '已删除'.tr);
        setState(() {
          _selectMode = false;
          _selected.clear();
        });
        _load();
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '${'删除失败'.tr}: $e');
    }
  }

  void _toggleSelect(int rowid) {
    setState(() {
      if (_selected.contains(rowid)) {
        _selected.remove(rowid);
      } else {
        _selected.add(rowid);
      }
    });
  }

  void _toggleSelectAll() {
    final allIds = _rows
        .map((r) => r['_rowid'] as int?)
        .whereType<int>()
        .toSet();
    setState(() {
      if (_selected.length == allIds.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(allIds);
      }
    });
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
        title: _selectMode
            ? Text('已选 ${_selected.length} 行'.tr,
                style: const TextStyle(fontSize: 15))
            : Text(widget.table,
                style: const TextStyle(fontSize: 15, fontFamily: 'monospace')),
        actions: _selectMode
            ? [
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text('全选'.tr, style: const TextStyle(fontSize: 13)),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  tooltip: '批量删除'.tr,
                  onPressed: _selected.isEmpty ? null : _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '退出批量删除'.tr,
                  onPressed: () => setState(() {
                    _selectMode = false;
                    _selected.clear();
                  }),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.checklist, size: 20),
                  tooltip: '批量删除'.tr,
                  onPressed: _rows.isEmpty
                      ? null
                      : () => setState(() => _selectMode = true),
                ),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Text('空表'.tr,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4))))
              : (_selectMode ? _buildSelectList(colors) : _buildTable(colors)),
    );
  }

  /// 批量删除模式：复选框行列表
  Widget _buildSelectList(ColorScheme colors) {
    return ListView.separated(
      itemCount: _rows.length,
      separatorBuilder: (_, __) => Divider(
          height: 0.5,
          indent: 16,
          endIndent: 16,
          color: colors.outlineVariant),
      itemBuilder: (context, i) {
        final row = _rows[i];
        final rowid = row['_rowid'] as int?;
        final checked = rowid != null && _selected.contains(rowid);
        return InkWell(
          onTap: rowid == null ? null : () => _toggleSelect(rowid),
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 12),
            child: Row(
              children: [
                Checkbox(
                  value: checked,
                  visualDensity: VisualDensity.compact,
                  onChanged:
                      rowid == null ? null : (_) => _toggleSelect(rowid),
                ),
                Expanded(
                  child: Text(
                    _rowSummary(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static const double _cellW = 110;

  /// 表格模式：列等宽、横向滚动、点行展开
  Widget _buildTable(ColorScheme colors) {
    return LayoutBuilder(
      builder: (context, cons) {
        final columns =
            _rows.first.keys.where((k) => k != '_rowid').toList();
        final tableW = columns.length * _cellW;
        final width = tableW > cons.maxWidth ? tableW : cons.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: ListView(
              children: [
                _buildTableHeader(colors, columns),
                for (var i = 0; i < _rows.length; i++) ...[
                  _buildTableRow(colors, columns, _rows[i], cons.maxWidth),
                  Divider(
                      height: 0.5,
                      color: colors.outlineVariant.withValues(alpha: 0.5)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(ColorScheme colors, List<String> columns) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        border: Border(
            bottom:
                BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          for (final c in columns)
            SizedBox(
              width: _cellW,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  c,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: colors.onSurface.withValues(alpha: 0.5)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ColorScheme colors, List<String> columns,
      Map<String, Object?> row, double viewportW) {
    final rowid = row['_rowid'] as int?;
    final expanded = rowid != null && _expanded.contains(rowid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: rowid == null
              ? null
              : () => setState(() {
                    if (expanded) {
                      _expanded.remove(rowid);
                    } else {
                      _expanded.add(rowid);
                    }
                  }),
          child: Row(
            children: [
              for (final c in columns)
                SizedBox(
                  width: _cellW,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: Text(
                      row[c]?.toString() ?? 'NULL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: row[c] == null
                              ? colors.onSurface.withValues(alpha: 0.3)
                              : colors.onSurface.withValues(alpha: 0.8)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (expanded) _buildRowDetail(colors, row, viewportW),
      ],
    );
  }

  /// 展开区：全部字段 + 编辑/删除
  Widget _buildRowDetail(
      ColorScheme colors, Map<String, Object?> row, double viewportW) {
    final entries = row.entries.where((e) => e.key != '_rowid').toList();
    return Container(
      width: viewportW - 16,
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            entries.map((e) => '${e.key}: ${e.value ?? 'NULL'}').join('\n'),
            style: TextStyle(
                fontSize: 10,
                height: 1.5,
                fontFamily: 'monospace',
                color: colors.onSurface.withValues(alpha: 0.75)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () => _editRow(row),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label:
                      Text('编辑'.tr, style: const TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => _deleteRow(row),
                  icon: Icon(Icons.delete_outline,
                      size: 14, color: colors.error),
                  label: Text('删除'.tr,
                      style: TextStyle(fontSize: 12, color: colors.error)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单元格摘要（截断显示）
String _shortCell(Object? v) {
  if (v == null) return 'NULL';
  final s = v.toString().replaceAll('\n', ' ');
  return s.length > 14 ? '${s.substring(0, 14)}…' : s;
}

/// 一行数据的单行摘要
String _rowSummary(Map<String, Object?> row) => row.entries
    .where((e) => e.key != '_rowid')
    .map((e) => _shortCell(e.value))
    .join(' │ ');

/// 一行数据：单行摘要（前几个字段），展开看全部字段（查询结果只读）
class _RowTile extends StatelessWidget {
  final Map<String, Object?> row;
  final ColorScheme colors;

  const _RowTile({required this.row, required this.colors});

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
          _rowSummary(row),
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
        ],
      ),
    );
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
    // 只允许 SELECT 语句
    final head = sql.split(RegExp(r'\s+')).first.toUpperCase();
    if (head != 'SELECT') {
      setState(() {
        _error = '只允许 SELECT 查询';
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

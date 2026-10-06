import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../services/log_service.dart';
import '../../utils/platform_utils.dart';
import '../../utils/toast_util.dart';

/// 调试日志页：查看运行日志，支持按时间段筛选、导出保存、清空
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  Timer? _refreshTimer;
  DateTime? _startTime;
  DateTime? _endTime;
  /// 选中的模块（null = 全部）
  Set<String>? _selectedModules;

  @override
  void initState() {
    super.initState();
    // 定时刷新（日志可能在 build 期间产生，不适合用通知驱动）
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 筛选后的日志，新的在前
  List<LogEntry> get _filtered {
    return LogService.instance.entries.reversed.where((e) {
      if (_startTime != null && e.time.isBefore(_startTime!)) return false;
      if (_endTime != null && e.time.isAfter(_endTime!)) return false;
      if (_selectedModules != null && !_selectedModules!.contains(e.module)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 当前日志中出现过的所有模块（含无前缀 ''）
  Set<String> get _allModules {
    return LogService.instance.entries.map((e) => e.module).toSet();
  }

  String _fmtTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  String _fmtFilterTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final initial = (isStart ? _startTime : _endTime) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      final picked =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startTime = picked;
      } else {
        // 结束时间包含该分钟整
        _endTime = picked.add(const Duration(minutes: 1));
      }
    });
  }

  Future<void> _saveLogs() async {
    // 导出按时间正序
    final logs = _filtered.reversed.toList();
    if (logs.isEmpty) {
      ToastUtil.show(context, '没有可保存的日志'.tr);
      return;
    }
    final content = logs.map((e) => e.format()).join('\n');
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final fileName = 'mooknote_log_$stamp.txt';
    try {
      if (PlatformUtils.isDesktop) {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: '保存日志'.tr,
          fileName: fileName,
        );
        if (path == null) return;
        await File(path).writeAsString(content);
        if (mounted) ToastUtil.show(context, '日志已保存'.tr);
      } else {
        final dir = Directory('/sdcard/Download/mooknote');
        await dir.create(recursive: true);
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(content);
        if (mounted) {
          ToastUtil.show(context, '已保存到 {path}'.trf({'path': file.path}));
        }
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '保存失败: $e'.tr);
    }
  }

  Future<void> _clearLogs() async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('清空日志'.tr),
        content: Text('确定要清空全部运行日志吗？'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('清空'.tr, style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      LogService.instance.clear();
      setState(() {});
    }
  }

  /// 弹出模块多选对话框
  Future<void> _pickModules() async {
    final all = _allModules;
    final modules = all.toList()..sort();
    var selected =
        _selectedModules == null ? Set.of(all) : Set.of(_selectedModules!);
    final colors = Theme.of(context).colorScheme;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Expanded(
                child: Text('筛选模块'.tr,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setDlgState(() => selected = Set.of(all)),
                child: Text('全选'.tr, style: const TextStyle(fontSize: 13)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => setDlgState(() => selected = {}),
                child: Text('全不选'.tr, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 320,
            child: ListView(
              children: [
                for (final m in modules)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(m.isEmpty ? '(无前缀)'.tr : m,
                        style: const TextStyle(fontSize: 13)),
                    value: selected.contains(m),
                    onChanged: (v) => setDlgState(() {
                      if (v == true) {
                        selected.add(m);
                      } else {
                        selected.remove(m);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('取消'.tr),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: Text('确定'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedModules = result.length == all.length ? null : result;
      });
    }
  }

  Widget _buildChip({
    required IconData icon,
    required String text,
    required bool active,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: active
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final logs = _filtered;
    final hasFilter = _startTime != null ||
        _endTime != null ||
        _selectedModules != null;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('运行日志'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新'.tr,
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt, size: 20),
            tooltip: '保存日志'.tr,
            onPressed: _saveLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: '清空日志'.tr,
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选栏
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                _buildChip(
                  icon: Icons.schedule,
                  text: _startTime != null
                      ? '${'开始'.tr} ${_fmtFilterTime(_startTime!)}'
                      : '${'开始'.tr} ${'不限'.tr}',
                  active: _startTime != null,
                  onTap: () => _pickTime(true),
                ),
                const SizedBox(width: 8),
                _buildChip(
                  icon: Icons.schedule,
                  text: _endTime != null
                      ? '${'结束'.tr} ${_fmtFilterTime(_endTime!)}'
                      : '${'结束'.tr} ${'不限'.tr}',
                  active: _endTime != null,
                  onTap: () => _pickTime(false),
                ),
                const SizedBox(width: 8),
                _buildChip(
                  icon: Icons.label_outline,
                  text: _selectedModules == null
                      ? '${'模块'.tr} ${'全部'.tr}'
                      : '${'模块'.tr} ${_selectedModules!.length}${'项'.tr}',
                  active: _selectedModules != null,
                  onTap: _pickModules,
                ),
                if (hasFilter)
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.4)),
                    tooltip: '清除筛选'.tr,
                    onPressed: () => setState(() {
                      _startTime = null;
                      _endTime = null;
                      _selectedModules = null;
                    }),
                  ),
                const Spacer(),
                Text(
                  '{n} 条'.trf({'n': logs.length}),
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, color: colors.outlineVariant),
          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      hasFilter ? '没有匹配的日志'.tr : '暂无日志'.tr,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.35)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 0.5,
                        indent: 16,
                        color: colors.outlineVariant.withValues(alpha: 0.5)),
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final isErr = entry.isError;
                      return InkWell(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: entry.format()));
                          ToastUtil.show(context, '已复制'.tr);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _fmtTime(entry.time),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: colors.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: isErr
                                        ? colors.error
                                        : colors.onSurface
                                            .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

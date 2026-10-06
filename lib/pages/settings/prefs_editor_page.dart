import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_strings.dart';
import '../../utils/toast_util.dart';

/// 偏好设置编辑器（调试模式）：查看/编辑/删除 SharedPreferences 数据
class PrefsEditorPage extends StatefulWidget {
  const PrefsEditorPage({super.key});

  @override
  State<PrefsEditorPage> createState() => _PrefsEditorPageState();
}

/// 键名说明：精确匹配优先，其次前缀匹配，都没有返回 null
String? _describeKey(String key) {
  const exact = <String, String>{
    'firstUseDate': '首次使用日期（徽章"首次使用"依据）',
    'nickname': '我的页昵称',
    'motto': '我的页座右铭',
    'avatarPath': '头像图片路径',
    'themeMode': '主题模式：0=跟随系统 1=浅色 2=深色',
    'colorSchemeIndex': '配色方案序号，-1=莫奈取色',
    'fontFamily': '全局字体族，空=默认',
    'languageMode': '语言：0=跟随系统 1=中文 2=英文',
    'showExactReleaseDate': '卡片是否显示精确上映/发布日期',
    'isFirstLaunch': '是否首次启动（引导页标记）',
    'detailPageStyle': '详情页样式：0=标准 1=毛玻璃 2=浅色极简 3=豆瓣',
    'hideBottomNavOnScroll': '滚动时隐藏底部导航栏',
    'debugMode': '调试模式（记录运行日志）',
    'exportWithImages': 'Excel 导出是否附带图片（走服务器生成）',
    'homeModuleSwitchMode': '首页模块切换方式',
    'defaultMainTabIndex': '启动默认主标签，-1=不指定',
    'showDesktopHomeTab': '桌面端是否显示"首页"标签',
    'noteLayoutStyle': '笔记列表布局样式',
    'noteSortMode': '笔记排序方式',
    'calendarDateMode': '日历按哪种日期归组（上映/记录）',
    'statsTimeRange': '统计页时间范围',
    'profileModuleIndex': '我的页"我的模块"当前选中索引',
    'movieWallMode': '影视海报墙模式',
    'bookshelfMode': '书架模式',
    'gameWallMode': '游戏墙模式',
    'appIconName': '当前应用图标资源名',
    'deviceId': '设备哈希（上报统计/徽章解锁用，匿名）',
    'lastActiveDate': '最近活跃日期（连续使用天数计算用）',
    'streakDays': '连续使用天数',
    'badgeDefsCache': '徽章定义 JSON 缓存（离线展示用）',
    'badgeUnlocked': '已解锁徽章 JSON：{slug: 解锁时间}',
    'badgePendingCelebrate': '待庆祝的新解锁徽章 slug 队列',
    'badgeFloat': '我的页浮动徽章位置 JSON：{slug: {x, y}}',
    'searchHistory': '搜索历史',
    'enhancedSearchEnabled': '增强搜索开关',
    'lastSearchOnline': '上次搜索是否为在线搜索',
    'movieSearchToken': '影视搜索 API token',
    'bookSearchToken': '读书搜索 API token',
    'lastSearchTab': '搜索页上次选中标签',
    'playbackUnlockTime': '播放功能解锁时间',
    'dismissedVersion': '已忽略更新的版本号',
    'dismissedUpdateUntil': '更新弹窗 snooze 截止时间戳（毫秒）',
    'lastFontDir': '上次字体下载目录',
    'localAutoBackupEnabled': '本地自动备份开关',
    'localAutoBackupIntervalHours': '本地自动备份间隔（小时）',
    'lastLocalAutoBackupTime': '上次本地自动备份时间',
    'webdav_backup_mode': 'WebDAV 备份模式：full=整包 inc=增量',
    'webdavIncAutoSyncEnabled': 'WebDAV 增量自动同步开关',
    'webdavIncAutoSyncIntervalMinutes': 'WebDAV 增量自动同步间隔（分钟）',
    'webdav_config': 'WebDAV 服务器配置 JSON（地址/账号/密码）',
    'webdav_last_sync': 'WebDAV 上次同步时间',
    'sync_client_id': '增量同步客户端 ID（标识本设备）',
    'isDarkMode': '旧版深色模式开关（已迁移到 themeMode，可删）',
  };
  if (exact.containsKey(key)) return exact[key];

  const prefixes = <String, String>{
    'detailModules_': '详情页模块排序配置（按类型后缀区分 movie/book/game/note）',
    'coverOffset_': '封面图手动调整的偏移量（按条目 ID 后缀区分）',
    'showSidebar': '桌面侧边栏模块显示开关',
    'showMovieTab': '主标签"影视"显示开关',
    'showBookTab': '主标签"阅读"显示开关',
    'showNoteTab': '主标签"笔记"显示开关',
    'showGameTab': '主标签"游戏"显示开关',
    'movieSortMode': '影视排序方式',
    'bookSortMode': '阅读排序方式',
    'gameSortMode': '游戏排序方式',
    'movieLayoutStyle': '影视列表布局样式',
    'bookLayoutStyle': '阅读列表布局样式',
    'gameLayoutStyle': '游戏列表布局样式',
    'reviewedLayoutStyle': '已评价页布局样式',
    'playlistLayoutStyle': '片单页布局样式',
    'movieStatusBarStyle': '影视状态栏样式',
    'bookStatusBarStyle': '阅读状态栏样式',
    'gameStatusBarStyle': '游戏状态栏样式',
    'movieDisplayMode': '影视显示模式',
    'movieGridCount': '影视网格列数',
    'bookGridCount': '阅读网格列数',
    'gameGridCount': '游戏网格列数',
    'showMovieCardDate': '影视卡片是否显示日期',
    'showBookCardDate': '阅读卡片是否显示日期',
    'showGameCardDate': '游戏卡片是否显示日期',
  };
  for (final e in prefixes.entries) {
    if (key.startsWith(e.key)) return e.value;
  }
  // 插件内部键（flutter. 前缀是插件约定）
  if (key.startsWith('flutter.')) {
    return '第三方插件内部数据（非应用自身设置，勿随意修改）';
  }
  return '暂无说明：可能是旧版本遗留数据或其它未知功能写入的键';
}

class _PrefsEditorPageState extends State<PrefsEditorPage> {
  SharedPreferences? _prefs;
  List<String> _keys = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _keys = prefs.getKeys().toList()..sort();
    });
  }

  String _valueOf(String key) {
    final v = _prefs!.get(key);
    if (v is List<String>) return jsonEncode(v);
    return v.toString();
  }

  String _typeOf(String key) {
    final v = _prefs!.get(key);
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is List<String>) return 'stringList';
    return 'string';
  }

  Future<void> _edit(String key) async {
    final prefs = _prefs!;
    final type = _typeOf(key);
    final colors = Theme.of(context).colorScheme;

    if (type == 'bool') {
      final current = prefs.getBool(key) ?? false;
      await prefs.setBool(key, !current);
      setState(() {});
      return;
    }

    final controller =
        TextEditingController(text: _valueOf(key));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(key, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: controller,
          maxLines: null,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: type,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'.tr),
          ),
          TextButton(
            onPressed: () async {
              final text = controller.text;
              try {
                switch (type) {
                  case 'int':
                    await prefs.setInt(key, int.parse(text));
                    break;
                  case 'double':
                    await prefs.setDouble(key, double.parse(text));
                    break;
                  case 'stringList':
                    final list = (jsonDecode(text) as List)
                        .map((e) => e.toString())
                        .toList();
                    await prefs.setStringList(key, list);
                    break;
                  default:
                    await prefs.setString(key, text);
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('${'格式错误'.tr}: $e')));
                }
              }
            },
            child: Text('保存'.tr),
          ),
        ],
      ),
    );
    if (saved == true) {
      setState(() {});
      if (mounted) ToastUtil.show(context, '已保存'.tr);
    }
  }

  Future<void> _delete(String key) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('删除键'.tr),
        content: Text(key, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('删除'.tr)),
        ],
      ),
    );
    if (ok == true) {
      await _prefs!.remove(key);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final keys = _filter.isEmpty
        ? _keys
        : _keys
            .where((k) => k.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('偏好设置编辑器'.tr),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索键名'.tr,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
        ),
      ),
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, __) => Divider(
                  height: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: colors.outlineVariant),
              itemBuilder: (context, i) {
                final key = keys[i];
                final type = _typeOf(key);
                final value = _valueOf(key);
                final desc = _describeKey(key);
                return ListTile(
                  dense: true,
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(key,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (desc != null)
                        GestureDetector(
                          onTap: () {
                            final colors = Theme.of(context).colorScheme;
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: colors.surface,
                                title: Text(key,
                                    style: const TextStyle(fontSize: 14)),
                                content: Text(desc,
                                    style: const TextStyle(fontSize: 13)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text('知道了'.tr)),
                                ],
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.error_outline,
                                size: 14,
                                color: colors.onSurface
                                    .withValues(alpha: 0.35)),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colors.onSurface.withValues(alpha: 0.5)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(type,
                            style: TextStyle(
                                fontSize: 10, color: colors.primary)),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18,
                            color: colors.onSurface.withValues(alpha: 0.4)),
                        onPressed: () => _delete(key),
                      ),
                    ],
                  ),
                  onTap: () => _edit(key),
                );
              },
            ),
    );
  }
}

/// 英文翻译 - 通用组件/工具/服务域
const Map<String, String> enWidgets = {
  // ── add_sheet / add_type_selector ──
  '新增记录': 'New Entry',
  '选择添加类型': 'Select Type to Add',
  '添加观影': 'Add Movie',
  '记录你看过的电影': 'Track movies you have watched',
  '添加阅读': 'Add Reading',
  '记录你读过的书': 'Track books you have read',
  '记录你的想法和笔记': 'Capture your thoughts and notes',
  '记录你玩过的游戏': 'Track games you have played',

  // ── alternate_titles_dialog ──
  '暂无别名': 'No alternate titles yet',

  // ── duration_picker ──
  '时': 'h',
  '分': 'm',
  '{n} 小时': '{n} h',
  '{n} 分': '{n} m',

  // ── detail_placeholder ──
  '选择一条记录查看详情': 'Select an entry to view details',

  // ── genre_selector_page ──
  '搜索或{hint}': 'Search or {hint}',
  '搜索或输入': 'Search or type',
  '可选 ({n})': 'Available ({n})',
  '匹配结果 ({n})': 'Matches ({n})',
  '暂无可选': 'Nothing available',
  '无匹配结果，回车添加': 'No matches, press Enter to add',

  // ── tag_side_panel ──
  '输入新标签，回车添加': 'Enter a new tag, press Enter to add',
  '已选标签': 'Selected Tags',
  '全部标签': 'All Tags',

  // ── work_selector_page ──
  '搜索作品标题或人物名称': 'Search by work title or person name',
  '配音角色': 'Voice Role',
  '饰演角色': 'Character Role',
  '如：米老鼠': 'e.g. Mickey Mouse',
  '如：关羽': 'e.g. Guan Yu',
  '暂无可选作品': 'No works available',
  '无匹配结果': 'No matches',
  '参演': 'Appears in',
  '设置角色': 'Set Character',
  '饰 {name}': 'as {name}',

  // ── custom_drawer ──
  '探索': 'Explore',
  '工具': 'Tools',
  '连续 {n} 天': '{n}-day streak',
  '{n}月': '{n}',
  '少': 'Less',
  '多': 'More',
  ' · {n}条': ' · {n}',
  '{n}万': '{n} w',
  '{n}月前': '{n} mo ago',

  // ── vditor_editor ──
  '使用 Markdown 格式书写...': 'Write in Markdown...',
  '编辑器加载中...': 'Loading editor...',

  // ── image_saver ──
  '原文件不存在': 'Source file not found',
  '下载图片': 'Download Image',
  '存储权限被拒绝': 'Storage permission denied',
  '已保存到 {path}': 'Saved to {path}',
  '保存失败：{e}': 'Save failed: {e}',

  // ── excel_exporter ──
  '内容': 'Content',
  '内容类型': 'Content Type',
  '否': 'No',
  '图片数': 'Images',
  '时长(分钟)': 'Duration (min)',
  '是': 'Yes',
  '是否置顶': 'Pinned',
  '短片': 'Short',
  '读完时间': 'Date Finished',
  '游玩时长(分钟)': 'Play Time (min)',
  '游玩时长(小时)': 'Play Time (h)',

  // ── backup_service ──
  '保存备份文件': 'Save Backup File',
  '备份文件中没有找到数据文件': 'Data file not found in backup',
  '恢复失败: {e}': 'Restore failed: {e}',
  '无效的备份文件格式': 'Invalid backup file format',
  '无法读取文件路径': 'Unable to read file path',
  '没有导入任何数据': 'No data imported',
  'MookNote 数据备份': 'MookNote Data Backup',
  '这是我的 MookNote 数据备份文件': 'This is my MookNote data backup file',
  '需要存储权限才能导出备份文件，请在设置中授予"所有文件访问权限"':
      'Storage permission required to export. Please grant "All files access" in Settings',
  '需要存储权限才能自动备份': 'Storage permission required for auto-backup',
  '批注': 'Annotations',
  '片单': 'Playlists',

  // ── webdav_service ──
  '上传备份文件失败': 'Failed to upload backup file',
  '上传失败: {e}': 'Upload failed: {e}',
  '下载备份文件失败': 'Failed to download backup file',
  '创建目录失败: {code}': 'Failed to create directory: {code}',
  '同步完成': 'Sync complete',
  '同步未完成，未传输任何数据': 'Sync incomplete: no data transferred',
  '同步正在进行中，请稍后再试': 'Sync already in progress, please try again later',
  '服务器上没有备份文件，请先从其他设备上传': 'No backup file on server. Please upload from another device first',
  '服务器返回错误: {code}': 'Server error: {code}',
  '未配置 WebDAV': 'WebDAV not configured',
  '父目录不存在，请检查路径': 'Parent directory does not exist, please check the path',
  '认证失败，请检查用户名和密码': 'Authentication failed, please check username and password',
  '连接成功': 'Connected',
  '连接成功，已创建目录': 'Connected, directory created',
  '连接成功，目录已存在': 'Connected, directory already exists',
  '恢复备份失败': 'Failed to restore backup',

  // ── cache_cleaner ──
  '已清理 {images} 个孤立图片，{epubs} 个孤立电子书，{temp} 个临时文件，{emptyDirs} 个空文件夹':
      'Cleaned {images} orphaned images, {epubs} orphaned books, {temp} temp files, {emptyDirs} empty folders',

  // ── app_router ──
  '未找到页面：{name}': 'Page not found: {name}',

  // ── main.dart update dialog ──
  '最新版本：{v}': 'Latest version: {v}',
  '更新内容': "What's New",
  '24小时内不显示': "Don't show for 24 hours",
  '链接失效': 'Link is unavailable',

  // ── app_theme color scheme names ──
  '经典': 'Classic',
  '靛蓝': 'Indigo',
  '薄荷': 'Mint',
  '琥珀': 'Amber',
  '玫瑰': 'Rose',
  '紫罗兰': 'Violet',
  '米黄': 'Cream',

  // ── desktop_home weekday labels ──
  '一': 'Mon',
  '二': 'Tue',
  '三': 'Wed',
  '四': 'Thu',
  '五': 'Fri',
  '六': 'Sat',
  '日': 'Sun',

  // ── 补齐：状态/通用 ──
  '放弃': 'Abandoned',
  '游戏评论': 'Game Review',
  '暂无{type}': 'No {type} yet',
  '没有找到"{q}"相关标签': 'No tags found for "{q}"',
  '移动到「{name}」': 'Move to "{name}"',
  '收藏纪念\nCOLLECTIBLE': 'COLLECTIBLE',
  '下载失败: HTTP {code}': 'Download failed: HTTP {code}',
  '无法获取海报边界': 'Unable to capture image bounds',
  '无法生成图片数据': 'Unable to generate image data',
};

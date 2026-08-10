import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../data/gallery/gallery_dao.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import 'gallery_viewer_page.dart';

/// 类别显示名映射
const _categoryLabels = {
  'movie_poster': '影视海报',
  'movie_posters': '海报墙',
  'book_cover': '书籍封面',
  'note_image': '笔记图片',
  'game_cover': '游戏封面',
  'game_screenshot': '游戏截图',
  'person_photo': '人物照片',
  'movie_character': '影视角色',
  'book_character': '书籍角色',
  'game_character': '游戏角色',
};

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final GalleryDao _dao = GalleryDao();
  List<GalleryItem> _allItems = [];
  bool _loading = true;
  String? _error;
  String? _selectedCategory; // null = 全部
  bool _descending = true; // 按时间倒序

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final items = await _dao.getAllImages();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败：$e';
        _loading = false;
      });
    }
  }

  List<GalleryItem> get _filteredItems {
    var items = _allItems;
    if (_selectedCategory != null) {
      items = items.where((i) => i.category == _selectedCategory).toList();
    }
    if (!_descending) {
      items = items.reversed.toList();
    }
    return items;
  }

  List<String> get _availableCategories {
    final set = _allItems.map((i) => i.category).toSet();
    // 按预定义顺序排列
    return _categoryLabels.keys.where((k) => set.contains(k)).toList();
  }

  void _openPreview(int index) {
    final items = _filteredItems;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryViewerPage(items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图库'),
        actions: [
          if (!_loading && _allItems.isNotEmpty)
            IconButton(
              icon: Icon(_descending ? Icons.arrow_downward : Icons.arrow_upward, size: 20),
              tooltip: _descending ? '当前：最新在前' : '当前：最早在前',
              onPressed: () => setState(() => _descending = !_descending),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: colors.error)),
                  ),
                )
              : _allItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text('还没有保存过图片', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5))),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        // 类别筛选条
                        if (_availableCategories.length > 1)
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 44,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                children: [
                                  _buildChip(null, '全部', colors),
                                  ..._availableCategories.map((c) => _buildChip(c, _categoryLabels[c] ?? c, colors)),
                                ],
                              ),
                            ),
                          ),
                        // 瀑布流网格
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          sliver: SliverMasonryGrid.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              return _buildCard(item, index, colors);
                            },
                          ),
                        ),
                        // 底部计数
                        SliverToBoxAdapter(
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '共 ${_filteredItems.length} 张图片',
                                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildCard(GalleryItem item, int index, ColorScheme colors) {
    final categoryLabel = _categoryLabels[item.category] ?? item.category;
    final title = item.entityTitle.isNotEmpty ? item.entityTitle : '未命名';

    return GestureDetector(
      onTap: () => _openPreview(index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片
          AspectRatio(
            aspectRatio: _aspectRatioFor(item.category),
            child: FadeInLocalImage(
              path: item.path,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 类别标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              categoryLabel,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 4),
          // 标题
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
          // 角色图片显示父作品
          if (item.parentTitle != null && item.parentTitle!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              item.parentTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.45)),
            ),
          ],
        ],
      ),
    );
  }

  /// 不同类别用不同宽高比，让瀑布流有错落感
  double _aspectRatioFor(String category) {
    switch (category) {
      case 'movie_poster':
      case 'book_cover':
      case 'game_cover':
        return 2 / 3; // 竖版海报/封面
      case 'movie_posters':
        return 2 / 3;
      case 'person_photo':
      case 'movie_character':
      case 'book_character':
      case 'game_character':
        return 3 / 4; // 人物照
      case 'game_screenshot':
        return 16 / 9; // 横版截图
      case 'note_image':
        return 1 / 1; // 笔记图片方形
      default:
        return 3 / 4;
    }
  }

  Widget _buildChip(String? category, String label, ColorScheme colors) {
    final selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _selectedCategory = selected ? null : category),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

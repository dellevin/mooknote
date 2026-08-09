import 'package:flutter/material.dart';
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
                  : Column(
                      children: [
                        // 类别筛选条
                        if (_availableCategories.length > 1)
                          SizedBox(
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
                        // 网格
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(4),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              return GestureDetector(
                                onTap: () => _openPreview(index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: FadeInLocalImage(
                                    path: item.path,
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      color: colors.surfaceContainerHighest,
                                      child: Icon(Icons.broken_image_outlined, color: colors.onSurface.withValues(alpha: 0.3)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // 底部计数
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '共 ${_filteredItems.length} 张图片',
                              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
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

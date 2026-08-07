import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/animated_star_rating.dart';

class PlaylistAddItemPage extends StatefulWidget {
  final Playlist playlist;
  const PlaylistAddItemPage({super.key, required this.playlist});

  @override
  State<PlaylistAddItemPage> createState() => _PlaylistAddItemPageState();
}

class _PlaylistAddItemPageState extends State<PlaylistAddItemPage> {
  final _searchController = TextEditingController();
  List<String> _existingItemIds = [];
  String _keyword = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final provider = context.read<AppProvider>();
    final ids = await provider.getPlaylistItemIds(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _existingItemIds = ids;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final type = widget.playlist.type;

    // 获取对应类型的条目列表
    List<_SelectableItem> items;
    if (type == 'movie') {
      items = provider.movies
          .where((m) => !m.isDeleted)
          .map((m) => _SelectableItem(
                id: m.id,
                title: m.title,
                coverPath: m.posterPath,
                rating: m.rating,
                subtitle: m.directors.isNotEmpty ? m.directors.take(2).join(' / ') : '',
              ))
          .toList();
    } else if (type == 'book') {
      items = provider.books
          .where((b) => !b.isDeleted)
          .map((b) => _SelectableItem(
                id: b.id,
                title: b.title,
                coverPath: b.coverPath,
                rating: b.rating,
                subtitle: b.authors.isNotEmpty ? b.authors.take(2).join(' / ') : '',
              ))
          .toList();
    } else {
      items = provider.games
          .where((g) => !g.isDeleted)
          .map((g) => _SelectableItem(
                id: g.id,
                title: g.title,
                coverPath: g.coverPath,
                rating: g.rating,
                subtitle: g.developer.isNotEmpty ? g.developer.take(2).join(' / ') : '',
              ))
          .toList();
    }

    // 搜索过滤
    if (_keyword.isNotEmpty) {
      items = items.where((i) => i.title.toLowerCase().contains(_keyword.toLowerCase())).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('添加${widget.playlist.typeLabel}'),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 15, color: colors.onSurface),
              decoration: InputDecoration(
                hintText: '搜索${widget.playlist.typeLabel}名称',
                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 15),
                prefixIcon: Icon(Icons.search, color: colors.onSurface.withValues(alpha: 0.4), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _keyword = '');
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.close, color: colors.onSurface.withValues(alpha: 0.5), size: 16),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          // 列表
          Expanded(
            child: _loading
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : items.isEmpty
                    ? Center(
                        child: Text('没有找到${widget.playlist.typeLabel}',
                            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _buildItem(context, items[index], provider),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, _SelectableItem item, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final isAdded = _existingItemIds.contains(item.id);
    final type = widget.playlist.type;

    return GestureDetector(
      onTap: () async {
        if (isAdded) {
          final playlistItems = await provider.getPlaylistItems(widget.playlist.id);
          final match = playlistItems.firstWhere((pi) => pi.itemId == item.id);
          await provider.removePlaylistItem(match.id, widget.playlist.id);
          setState(() {
            _existingItemIds.remove(item.id);
          });
        } else {
          final playlistItem = PlaylistItem(
            id: const Uuid().v4(),
            playlistId: widget.playlist.id,
            itemId: item.id,
            addedAt: DateTime.now(),
          );
          await provider.addPlaylistItem(playlistItem);
          setState(() {
            _existingItemIds.add(item.id);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isAdded ? colors.surfaceContainerHighest.withValues(alpha: 0.5) : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAdded ? colors.outlineVariant.withValues(alpha: 0.2) : colors.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40, height: 56,
                child: item.coverPath != null && item.coverPath!.isNotEmpty
                    ? FadeInLocalImage(
                        path: item.coverPath,
                        fit: BoxFit.cover,
                        errorWidget: _buildPlaceholder(type, colors),
                      )
                    : _buildPlaceholder(type, colors),
              ),
            ),
            const SizedBox(width: 10),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isAdded ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.rating != null)
              AnimatedStarRating(rating: item.rating!, starSize: 10, showNumber: true)
            else if (!isAdded)
              const SizedBox(width: 40),
            if (isAdded) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 18, color: colors.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String type, ColorScheme colors) {
    final icon = switch (type) {
      'movie' => Icons.movie_outlined,
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      _ => Icons.list_outlined,
    };
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(child: Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }
}

class _SelectableItem {
  final String id;
  final String title;
  final String? coverPath;
  final double? rating;
  final String subtitle;

  _SelectableItem({
    required this.id,
    required this.title,
    this.coverPath,
    this.rating,
    this.subtitle = '',
  });
}

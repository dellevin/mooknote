import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';
import 'playlist_create_page.dart';
import 'playlist_detail_page.dart';

class PlaylistListPage extends StatefulWidget {
  const PlaylistListPage({super.key});

  @override
  State<PlaylistListPage> createState() => _PlaylistListPageState();
}

class _PlaylistListPageState extends State<PlaylistListPage> {
  final Map<String, List<String>> _playlistItemIds = {};
  int _layoutStyle = UserPrefs().playlistLayoutStyle;
  final Map<String, double> _slideOffsets = {};
  double _dragStartX = 0;
  double _dragStartOffset = 0;
  bool _isHorizontalDrag = false;

  @override
  void initState() {
    super.initState();
    _loadAllItemIds();
  }

  Future<void> _loadAllItemIds() async {
    final provider = context.read<AppProvider>();
    for (final playlist in provider.playlists) {
      final ids = await provider.getPlaylistItemIds(playlist.id);
      if (!mounted) return;
      setState(() {
        _playlistItemIds[playlist.id] = ids;
      });
    }
  }

  List<String?> _getCoverPaths(Playlist playlist, AppProvider provider, {int limit = 4}) {
    final ids = _playlistItemIds[playlist.id] ?? [];
    final covers = <String?>[];
    for (final id in ids.take(limit)) {
      if (playlist.type == 'movie') {
        final movie = provider.movies.where((m) => m.id == id).firstOrNull;
        covers.add(movie?.posterPath);
      } else if (playlist.type == 'book') {
        final book = provider.books.where((b) => b.id == id).firstOrNull;
        covers.add(book?.coverPath);
      } else if (playlist.type == 'game') {
        final game = provider.games.where((g) => g.id == id).firstOrNull;
        covers.add(game?.coverPath);
      }
    }
    return covers;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final playlists = provider.playlists;

        return Scaffold(
          appBar: AppBar(
            title: const Text('书影片单'),
            actions: [
              IconButton(
                icon: Icon(_layoutStyle == 0 ? Icons.grid_view : Icons.view_list, size: 20),
                onPressed: () {
                  final newStyle = _layoutStyle == 0 ? 1 : 0;
                  setState(() => _layoutStyle = newStyle);
                  UserPrefs().setPlaylistLayoutStyle(newStyle);
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 22),
                onPressed: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const PlaylistCreatePage()),
                  );
                  if (result == true && mounted) {
                    provider.loadPlaylists();
                    _loadAllItemIds();
                  }
                },
              ),
            ],
          ),
          body: playlists.isEmpty
              ? _buildEmpty(context)
              : _layoutStyle == 0
                  ? _buildListView(context, playlists, provider)
                  : _buildGridView(context, playlists, provider),
        );
      },
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.playlist_play, size: 36, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 16),
          Text('还没有片单', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('点击右上角 + 创建一个片单吧', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  // ─── 列表视图（长按1秒拖动排序 + 左滑操作）──────────────────────────

  Widget _buildListView(BuildContext context, List<Playlist> playlists, AppProvider provider) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: playlists.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final list = List<Playlist>.from(playlists);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        provider.reorderPlaylists(list.map((p) => p.id).toList());
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(animation.value);
            return Transform.scale(
              scale: 1.0 + 0.03 * t,
              child: Opacity(opacity: 1.0 - 0.15 * t, child: child),
            );
          },
        );
      },
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return _buildSlidableCard(context, playlist, index, provider);
      },
    );
  }

  Widget _buildSlidableCard(BuildContext context, Playlist playlist, int index, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final typeColor = _typeColor(playlist.type, colors);
    final covers = _getCoverPaths(playlist, provider);
    const actionWidth = 56.0;

    return Padding(
      key: Key(playlist.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 底层：操作按钮
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        setState(() => _slideOffsets[playlist.id] = 0.0);
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => PlaylistCreatePage(playlist: playlist)),
                        );
                        if (result == true && mounted) {
                          provider.loadPlaylists();
                          _loadAllItemIds();
                        }
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.edit_outlined, size: 20, color: colors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        setState(() => _slideOffsets[playlist.id] = 0.0);
                        await _showDeleteDialog(context, playlist, provider);
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.delete_outline, size: 20, color: colors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 上层：卡片内容（左滑 + 长按1秒拖动排序）
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_slideOffsets[playlist.id] ?? 0, 0, 0),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _dragStartX = event.position.dx;
                _dragStartOffset = _slideOffsets[playlist.id] ?? 0;
                _isHorizontalDrag = false;
              },
              onPointerMove: (event) {
                final dx = event.position.dx - _dragStartX;
                if (!_isHorizontalDrag && dx.abs() > 10) {
                  if (dx < 0 || _dragStartOffset < 0) {
                    _isHorizontalDrag = true;
                  }
                }
                if (_isHorizontalDrag) {
                  setState(() {
                    _slideOffsets[playlist.id] = (_dragStartOffset + dx).clamp(-actionWidth * 2, 0.0);
                  });
                }
              },
              onPointerUp: (_) {
                if (_isHorizontalDrag) {
                  final offset = _slideOffsets[playlist.id] ?? 0.0;
                  final target = offset < -actionWidth ? -actionWidth * 2 : 0.0;
                  setState(() => _slideOffsets[playlist.id] = target);
                }
                _isHorizontalDrag = false;
              },
              child: GestureDetector(
                onTap: () async {
                  if ((_slideOffsets[playlist.id] ?? 0) < 0) {
                    setState(() => _slideOffsets[playlist.id] = 0.0);
                    return;
                  }
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlist: playlist)),
                  );
                  if (mounted) {
                    provider.loadPlaylists();
                    _loadAllItemIds();
                  }
                },
                // 长按1秒后可拖动排序
                child: ReorderableDelayedDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        _buildCoverWall(context, playlist, covers, typeColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(playlist.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildTypeTag(playlist.typeLabel, typeColor),
                                ],
                              ),
                              if (playlist.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(playlist.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.collections_outlined, size: 13, color: colors.onSurface.withValues(alpha: 0.3)),
                                  const SizedBox(width: 4),
                                  Text('${playlist.itemCount} 个条目',
                                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                                  const Spacer(),
                                  Text(_formatDate(playlist.updatedAt),
                                      style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 网格视图 ──────────────────────────────────────────────────────

  Widget _buildGridView(BuildContext context, List<Playlist> playlists, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final typeColor = _typeColor(playlist.type, colors);
        final covers = _getCoverPaths(playlist, provider, limit: 3);

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaylistDetailPage(playlist: playlist)),
            );
            if (mounted) {
              provider.loadPlaylists();
              _loadAllItemIds();
            }
          },
          onLongPress: () => _showActionSheet(context, playlist, provider),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildGridCoverWall(context, playlist, covers, typeColor),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTypeTag(playlist.typeLabel, typeColor, compact: true),
                          const Spacer(),
                          Icon(Icons.collections_outlined, size: 10, color: colors.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(width: 2),
                          Text('${playlist.itemCount}',
                              style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.35))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 通用组件 ──────────────────────────────────────────────────────

  Widget _buildTypeTag(String label, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 3 : 4),
      ),
      child: Text(label,
          style: TextStyle(
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w500,
            color: color,
          )),
    );
  }

  Color _typeColor(String type, ColorScheme colors) {
    return switch (type) {
      'movie' => Colors.blue,
      'book' => Colors.teal,
      'game' => Colors.orange,
      _ => colors.onSurface,
    };
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '今天';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  Widget _buildGridCoverWall(BuildContext context, Playlist playlist, List<String?> covers, Color typeColor) {
    final colors = Theme.of(context).colorScheme;
    final typeIcon = switch (playlist.type) {
      'movie' => Icons.movie_outlined,
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      _ => Icons.list_outlined,
    };

    if (covers.isEmpty) {
      return Container(
        color: typeColor.withValues(alpha: 0.08),
        child: Center(child: Icon(typeIcon, size: 32, color: typeColor.withValues(alpha: 0.4))),
      );
    }

    return Row(
      children: List.generate(covers.length, (i) {
        final path = covers[i];
        return Expanded(
          child: path != null && path.isNotEmpty
              ? FadeInLocalImage(
                  path: path,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: colors.surfaceContainerHighest,
                    child: Icon(typeIcon, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
                  ),
                )
              : Container(
                  color: colors.surfaceContainerHighest,
                  child: Icon(typeIcon, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
                ),
        );
      }),
    );
  }

  Widget _buildCoverWall(BuildContext context, Playlist playlist, List<String?> covers, Color typeColor) {
    final colors = Theme.of(context).colorScheme;
    final typeIcon = switch (playlist.type) {
      'movie' => Icons.movie_outlined,
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      _ => Icons.list_outlined,
    };

    if (covers.isEmpty) {
      return Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(typeIcon, size: 28, color: typeColor),
      );
    }

    const cellSize = 31.0;
    const gap = 2.0;
    final wallSize = cellSize * 2 + gap;

    return SizedBox(
      width: wallSize,
      height: wallSize,
      child: Column(
        children: [
          Row(
            children: [
              _buildCoverCell(covers, 0, cellSize, typeIcon, colors, typeColor),
              SizedBox(width: gap),
              _buildCoverCell(covers, 1, cellSize, typeIcon, colors, typeColor),
            ],
          ),
          SizedBox(height: gap),
          Row(
            children: [
              _buildCoverCell(covers, 2, cellSize, typeIcon, colors, typeColor),
              SizedBox(width: gap),
              _buildCoverCell(covers, 3, cellSize, typeIcon, colors, typeColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoverCell(List<String?> covers, int index, double size, IconData typeIcon, ColorScheme colors, Color typeColor) {
    if (index >= covers.length) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    final path = covers[index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size, height: size,
        child: path != null && path.isNotEmpty
            ? FadeInLocalImage(
                path: path,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: typeColor.withValues(alpha: 0.08),
                  child: Icon(typeIcon, size: 12, color: typeColor.withValues(alpha: 0.3)),
                ),
              )
            : Container(
                color: typeColor.withValues(alpha: 0.08),
                child: Icon(typeIcon, size: 12, color: typeColor.withValues(alpha: 0.3)),
              ),
      ),
    );
  }

  // ─── 操作菜单 ──────────────────────────────────────────────────────

  void _showActionSheet(BuildContext context, Playlist playlist, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Container(
                width: 28, height: 3,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            _buildSheetAction(
              context: ctx,
              icon: Icons.edit_outlined,
              label: '编辑片单',
              color: colors.primary,
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => PlaylistCreatePage(playlist: playlist)),
                );
                if (result == true && mounted) {
                  provider.loadPlaylists();
                  _loadAllItemIds();
                }
              },
            ),
            Divider(height: 0.5, thickness: 0.5, color: colors.outlineVariant.withValues(alpha: 0.3)),
            _buildSheetAction(
              context: ctx,
              icon: Icons.delete_outline,
              label: '删除片单',
              color: colors.error,
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _showDeleteDialog(context, playlist, provider);
                if (confirmed == true && mounted) {
                  provider.loadPlaylists();
                  _loadAllItemIds();
                }
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, Playlist playlist, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除片单「${playlist.name}」吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.removePlaylist(playlist.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

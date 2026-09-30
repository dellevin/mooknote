import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/fade_in_local_image.dart';

class PlaylistCreatePage extends StatefulWidget {
  final Playlist? playlist; // 传入则为编辑模式
  const PlaylistCreatePage({super.key, this.playlist});

  @override
  State<PlaylistCreatePage> createState() => _PlaylistCreatePageState();
}

class _PlaylistCreatePageState extends State<PlaylistCreatePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  final FocusNode _nameFocusNode = FocusNode();
  late String _selectedType;
  bool _isSaving = false;

  /// 各类型预览卡要层叠的封面（页面打开时随机取一次，避免输入时重洗）
  late final Map<String, List<String>> _typeCovers;

  /// 编辑模式：片单内实际条目的封面（null=加载中，空=片单无封面）
  List<String>? _editCovers;

  bool get _isEdit => widget.playlist != null;
  bool get _canSave => _nameController.text.trim().isNotEmpty && !_isSaving;

  static const _types = [
    ('movie', '影视', Icons.movie_outlined),
    ('book', '书籍', Icons.menu_book_outlined),
    ('game', '游戏', Icons.sports_esports_outlined),
    ('all', '所有', Icons.all_inclusive),
  ];

  static Color _typeColor(String type, ColorScheme colors) {
    return switch (type) {
      'movie' => Colors.blue,
      'book' => Colors.teal,
      'game' => Colors.orange,
      'all' => Colors.purple,
      _ => colors.onSurface,
    };
  }

  static List<String> _pickCovers(Iterable<String?> paths, int n) {
    final list = paths.whereType<String>().where((p) => p.isNotEmpty).toList()..shuffle();
    return list.take(n).toList();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _descController = TextEditingController(text: widget.playlist?.description ?? '');
    _selectedType = widget.playlist?.type ?? 'movie';

    final provider = context.read<AppProvider>();
    final moviePaths = provider.movies.where((m) => !m.isDeleted).map((m) => m.posterPath);
    final bookPaths = provider.books.where((b) => !b.isDeleted).map((b) => b.coverPath);
    final gamePaths = provider.games.where((g) => !g.isDeleted).map((g) => g.coverPath);
    _typeCovers = {
      'movie': _pickCovers(moviePaths, 4),
      'book': _pickCovers(bookPaths, 4),
      'game': _pickCovers(gamePaths, 4),
      // 所有类型：从三个分类各自的完整池里独立随机抽一张
      'all': [
        ..._pickCovers(moviePaths, 1),
        ..._pickCovers(bookPaths, 1),
        ..._pickCovers(gamePaths, 1),
      ],
    };

    if (_isEdit) _loadEditCovers();
  }

  /// 编辑模式：取片单内条目的封面（最多 4 张），没有则为空
  Future<void> _loadEditCovers() async {
    final provider = context.read<AppProvider>();
    final ids = await provider.getPlaylistItemIds(widget.playlist!.id);
    if (!mounted) return;
    final covers = <String>[];
    for (final id in ids) {
      final path = _coverForItemId(provider, id);
      if (path != null && path.isNotEmpty) covers.add(path);
      if (covers.length >= 4) break;
    }
    setState(() => _editCovers = covers);
  }

  String? _coverForItemId(AppProvider provider, String id) {
    final type = widget.playlist!.type;
    if (type == 'movie' || type == 'all') {
      final movie = provider.movies.where((m) => m.id == id).firstOrNull;
      if (movie != null) return movie.posterPath;
    }
    if (type == 'book' || type == 'all') {
      final book = provider.books.where((b) => b.id == id).firstOrNull;
      if (book != null) return book.coverPath;
    }
    if (type == 'game' || type == 'all') {
      final game = provider.games.where((g) => g.id == id).firstOrNull;
      if (game != null) return game.coverPath;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final provider = context.read<AppProvider>();

    if (_isEdit) {
      final updated = widget.playlist!.copyWith(
        name: name,
        description: _descController.text.trim(),
        type: _selectedType,
        updatedAt: DateTime.now(),
      );
      await provider.updatePlaylist(updated);
    } else {
      final now = DateTime.now();
      final playlist = Playlist(
        id: const Uuid().v4(),
        name: name,
        description: _descController.text.trim(),
        type: _selectedType,
        createdAt: now,
        updatedAt: now,
      );
      await provider.addPlaylist(playlist);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typeColor = _typeColor(_selectedType, colors);
    final previewCard = _PreviewCard(
      type: _selectedType,
      typeColor: typeColor,
      name: _nameController.text.trim(),
      covers: _isEdit ? (_editCovers ?? const []) : (_typeCovers[_selectedType] ?? const []),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑片单'.tr : '创建片单'.tr),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      const SizedBox(width: 10),
                      Text('保存中…'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  )
                : Text(_isEdit ? '保存'.tr : '创建片单'.tr,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // 编辑模式：预览卡居中；新建模式：类型网格在左、预览卡在右
          if (_isEdit)
            Center(child: previewCard)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: _typeCard(0, colors)),
                        const SizedBox(width: 8),
                        Expanded(child: _typeCard(1, colors)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _typeCard(2, colors)),
                        const SizedBox(width: 8),
                        Expanded(child: _typeCard(3, colors)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                previewCard,
              ],
            ),
          const SizedBox(height: 28),
          // 片单名称
          _sectionLabel('片单名称', colors),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: !_isEdit,
            maxLength: 30,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: '输入片单名称'.tr,
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
              counterText: '',
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${_nameController.text.length}/30',
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                  ],
                ),
              ),
              suffixIconConstraints: const BoxConstraints(),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: typeColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          // 片单描述
          _sectionLabel('片单描述', colors),
          const SizedBox(height: 8),
          Stack(
            children: [
              TextField(
                controller: _descController,
                maxLines: 3,
                maxLength: 200,
                style: const TextStyle(fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  hintText: '描述一下这个片单（选填）'.tr,
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
                  counterText: '',
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: typeColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Positioned(
                right: 12,
                bottom: 8,
                child: IgnorePointer(
                  child: Text('${_descController.text.length}/200',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeCard(int i, ColorScheme colors) {
    final (type, label, icon) = _types[i];
    return _TypeCard(
      type: type,
      label: label,
      icon: icon,
      color: _typeColor(type, colors),
      selected: _selectedType == type,
      onTap: () => setState(() => _selectedType = type),
    );
  }

  Widget _sectionLabel(String text, ColorScheme colors) {
    return Text(text.tr,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6)));
  }
}

/// 实时预览卡 — 有封面时层叠真实封面+底部名称渐变条；无封面回退为类型色渐变+图标
class _PreviewCard extends StatelessWidget {
  final String type;
  final Color typeColor;
  final String name;
  final List<String> covers;

  const _PreviewCard({
    required this.type,
    required this.typeColor,
    required this.name,
    required this.covers,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCovers = covers.isNotEmpty;
    final icon = switch (type) {
      'movie' => Icons.movie_outlined,
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      'all' => Icons.all_inclusive,
      _ => Icons.list_outlined,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 148,
      height: 200,
      decoration: BoxDecoration(
        gradient: hasCovers
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  typeColor.withValues(alpha: isDark ? 0.22 : 0.10),
                  typeColor.withValues(alpha: isDark ? 0.40 : 0.24),
                ],
              ),
        color: hasCovers ? colors.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: hasCovers
                ? colors.shadow.withValues(alpha: 0.15)
                : typeColor.withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCovers ? _buildCoverStack(colors) : _buildIconFallback(colors, isDark, icon),
    );
  }

  /// 层叠封面 + 底部名称渐变条
  Widget _buildCoverStack(ColorScheme colors) {
    final count = covers.length;
    const offset = 8.0;
    const inset = 8.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = count - 1; i >= 0; i--)
          Positioned(
            left: inset + i * offset,
            top: inset,
            right: inset + (count - 1 - i) * offset,
            bottom: inset,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.surface, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: FadeInLocalImage(
                path: covers[i],
                fit: BoxFit.cover,
                errorWidget: Container(color: colors.surfaceContainerHighest),
              ),
            ),
          ),
        // 底部名称渐变条
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
              ),
            ),
            child: Text(
              name.isEmpty ? '片单名称'.tr : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: name.isEmpty ? Colors.white.withValues(alpha: 0.5) : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 无封面回退：类型色渐变 + 大图标 + 名称
  Widget _buildIconFallback(ColorScheme colors, bool isDark, IconData icon) {
    return Stack(
      children: [
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(icon, key: ValueKey(type), size: 52, color: typeColor.withValues(alpha: isDark ? 0.7 : 0.5)),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Text(
            name.isEmpty ? '片单名称'.tr : name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: name.isEmpty ? colors.onSurface.withValues(alpha: 0.3) : colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// 类型选择卡片 — 选中=类型色描边+浅填充+右上角对勾
class _TypeCard extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = selected ? color : colors.onSurface.withValues(alpha: 0.4);

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 64,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(height: 3),
                  Text(label.tr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: fg,
                      )),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

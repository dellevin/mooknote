import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import 'character_form_page.dart';

/// 影视角色列表页
class MovieCharactersPage extends StatefulWidget {
  final Movie movie;
  const MovieCharactersPage({super.key, required this.movie});

  @override
  State<MovieCharactersPage> createState() => _MovieCharactersPageState();
}

class _MovieCharactersPageState extends State<MovieCharactersPage> {
  List<MovieCharacter> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);
    final list = await context.read<AppProvider>().getMovieCharacters(widget.movie.id);
    if (!mounted) return;
    setState(() {
      _characters = list;
      _isLoading = false;
    });
  }

  Future<void> _openForm([MovieCharacter? c]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterFormPage(
          entityType: 'movie',
          entityId: widget.movie.id,
          character: c,
        ),
      ),
    );
    if (result == true) _loadCharacters();
  }

  Future<void> _delete(MovieCharacter c) async {
    if (c.imagePath != null && c.imagePath!.isNotEmpty) {
      await ImagePathHelper.instance.deleteCharacterImages(c.id);
    }
    await context.read<AppProvider>().deleteMovieCharacter(c.id);
    _loadCharacters();
    if (mounted) ToastUtil.show(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    return _CharacterListScaffold(
      title: '角色',
      isLoading: _isLoading,
      characters: _characters,
      onAdd: () => _openForm(),
      onTap: (c) => _openForm(c),
      onDelete: (c) => _delete(c),
    );
  }
}

/// 书籍角色列表页
class BookCharactersPage extends StatefulWidget {
  final Book book;
  const BookCharactersPage({super.key, required this.book});

  @override
  State<BookCharactersPage> createState() => _BookCharactersPageState();
}

class _BookCharactersPageState extends State<BookCharactersPage> {
  List<BookCharacter> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);
    final list = await context.read<AppProvider>().getBookCharacters(widget.book.id);
    if (!mounted) return;
    setState(() {
      _characters = list;
      _isLoading = false;
    });
  }

  Future<void> _openForm([BookCharacter? c]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterFormPage(
          entityType: 'book',
          entityId: widget.book.id,
          character: c,
        ),
      ),
    );
    if (result == true) _loadCharacters();
  }

  Future<void> _delete(BookCharacter c) async {
    if (c.imagePath != null && c.imagePath!.isNotEmpty) {
      await ImagePathHelper.instance.deleteCharacterImages(c.id);
    }
    await context.read<AppProvider>().deleteBookCharacter(c.id);
    _loadCharacters();
    if (mounted) ToastUtil.show(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    return _CharacterListScaffold(
      title: '角色',
      isLoading: _isLoading,
      characters: _characters,
      onAdd: () => _openForm(),
      onTap: (c) => _openForm(c),
      onDelete: (c) => _delete(c),
    );
  }
}

/// 游戏角色列表页
class GameCharactersPage extends StatefulWidget {
  final Game game;
  const GameCharactersPage({super.key, required this.game});

  @override
  State<GameCharactersPage> createState() => _GameCharactersPageState();
}

class _GameCharactersPageState extends State<GameCharactersPage> {
  List<GameCharacter> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    setState(() => _isLoading = true);
    final list = await context.read<AppProvider>().getGameCharacters(widget.game.id);
    if (!mounted) return;
    setState(() {
      _characters = list;
      _isLoading = false;
    });
  }

  Future<void> _openForm([GameCharacter? c]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterFormPage(
          entityType: 'game',
          entityId: widget.game.id,
          character: c,
        ),
      ),
    );
    if (result == true) _loadCharacters();
  }

  Future<void> _delete(GameCharacter c) async {
    if (c.imagePath != null && c.imagePath!.isNotEmpty) {
      await ImagePathHelper.instance.deleteCharacterImages(c.id);
    }
    await context.read<AppProvider>().deleteGameCharacter(c.id);
    _loadCharacters();
    if (mounted) ToastUtil.show(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    return _CharacterListScaffold(
      title: '角色',
      isLoading: _isLoading,
      characters: _characters,
      onAdd: () => _openForm(),
      onTap: (c) => _openForm(c),
      onDelete: (c) => _delete(c),
    );
  }
}

/// 通用角色列表 UI（接收 dynamic 角色列表，访问 .name/.aliases/.tags/.imagePath/.description）
class _CharacterListScaffold extends StatelessWidget {
  final String title;
  final bool isLoading;
  final List<dynamic> characters;
  final VoidCallback onAdd;
  final void Function(dynamic) onTap;
  final Future<void> Function(dynamic) onDelete;

  const _CharacterListScaffold({
    required this.title,
    required this.isLoading,
    required this.characters,
    required this.onAdd,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton(
        onPressed: onAdd,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : characters.isEmpty
              ? _buildEmpty(colors)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: characters.length,
                  separatorBuilder: (_, __) => Divider(height: 1, thickness: 0.5, color: colors.outlineVariant),
                  itemBuilder: (context, index) {
                    final c = characters[index];
                    return _CharacterTile(
                      name: c.name as String,
                      aliases: c.aliases as List<String>,
                      tags: c.tags as List<String>,
                      description: c.description as String?,
                      imagePath: c.imagePath as String?,
                      onTap: () => onTap(c),
                      onDelete: () => _confirmDelete(context, c),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.people_outline, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          Text('暂无角色', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text('点击右下角 + 添加角色', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, dynamic c) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除该角色吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete(c);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  final String name;
  final List<String> aliases;
  final List<String> tags;
  final String? description;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CharacterTile({
    required this.name,
    required this.aliases,
    required this.tags,
    required this.description,
    required this.imagePath,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(name + imagePath.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: colors.onError),
      ),
      confirmDismiss: (_) async {
        _showDeleteDialog(context);
        return false;
      },
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAvatar(colors),
        title: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(aliases.join('、'),
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6))),
                  )).toList(),
                ),
              ),
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colors) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? FadeInLocalImage(path: imagePath, fit: BoxFit.cover)
          : Center(
              child: Text(
                name.isNotEmpty ? name.characters.first : '?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除"$name"吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

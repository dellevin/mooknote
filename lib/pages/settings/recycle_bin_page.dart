import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';

/// 回收站页面
class RecycleBinPage extends StatefulWidget {
  const RecycleBinPage({super.key});

  @override
  State<RecycleBinPage> createState() => _RecycleBinPageState();
}

enum _ItemType { movie, book, note, game, movieReview, bookReview, bookExcerpt, gameReview, person, movieCharacter, bookCharacter, gameCharacter }

class _DeletedItem {
  final _ItemType type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String typeLabel;

  _DeletedItem.movie(Movie m)
      : type = _ItemType.movie,
        id = m.id,
        title = m.title,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(m.updatedAt)}),
        icon = Icons.movie_outlined,
        typeLabel = '影视'.tr;

  _DeletedItem.book(Book b)
      : type = _ItemType.book,
        id = b.id,
        title = b.title,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(b.updatedAt)}),
        icon = Icons.menu_book_outlined,
        typeLabel = '书籍'.tr;

  _DeletedItem.note(Note n)
      : type = _ItemType.note,
        id = n.id,
        title = n.title.isNotEmpty ? n.title : n.summary,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(n.updatedAt)}),
        icon = Icons.description_outlined,
        typeLabel = '笔记'.tr;

  _DeletedItem.movieReview(MovieReview r)
      : type = _ItemType.movieReview,
        id = r.id,
        title = r.content.isNotEmpty ? r.content : '影评'.tr,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(r.updatedAt)}),
        icon = Icons.rate_review_outlined,
        typeLabel = '影评'.tr;

  _DeletedItem.bookReview(BookReview r)
      : type = _ItemType.bookReview,
        id = r.id,
        title = r.content.isNotEmpty ? r.content : '书评'.tr,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(r.updatedAt)}),
        icon = Icons.rate_review_outlined,
        typeLabel = '书评'.tr;

  _DeletedItem.bookExcerpt(BookExcerpt e)
      : type = _ItemType.bookExcerpt,
        id = e.id,
        title = e.content.isNotEmpty ? e.content : '摘抄'.tr,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(e.updatedAt)}),
        icon = Icons.format_quote_outlined,
        typeLabel = '书摘'.tr;

  _DeletedItem.game(Game g)
      : type = _ItemType.game,
        id = g.id,
        title = g.title,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(g.updatedAt)}),
        icon = Icons.sports_esports_outlined,
        typeLabel = '游戏'.tr;

  _DeletedItem.gameReview(GameReview r)
      : type = _ItemType.gameReview,
        id = r.id,
        title = r.content.isNotEmpty ? r.content : '游戏评价'.tr,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(r.updatedAt)}),
        icon = Icons.rate_review_outlined,
        typeLabel = '游戏评价'.tr;

  _DeletedItem.person(Person p)
      : type = _ItemType.person,
        id = p.id,
        title = p.name,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(p.updatedAt)}),
        icon = Icons.person_outline,
        typeLabel = '人物'.tr;

  _DeletedItem.movieCharacter(MovieCharacter c)
      : type = _ItemType.movieCharacter,
        id = c.id,
        title = c.name,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(c.updatedAt)}),
        icon = Icons.movie_outlined,
        typeLabel = '影视角色'.tr;

  _DeletedItem.bookCharacter(BookCharacter c)
      : type = _ItemType.bookCharacter,
        id = c.id,
        title = c.name,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(c.updatedAt)}),
        icon = Icons.menu_book_outlined,
        typeLabel = '书籍角色'.tr;

  _DeletedItem.gameCharacter(GameCharacter c)
      : type = _ItemType.gameCharacter,
        id = c.id,
        title = c.name,
        subtitle = '删除于 {date}'.trf({'date': _fmtDate(c.updatedAt)}),
        icon = Icons.sports_esports_outlined,
        typeLabel = '游戏角色'.tr;

  static String _fmtDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}

class _RecycleBinPageState extends State<RecycleBinPage> {
  List<_DeletedItem> _allItems = [];
  _ItemType? _filterType;
  bool _isLoading = true;

  List<_DeletedItem> get _filteredItems =>
      _filterType == null ? _allItems : _allItems.where((i) => i.type == _filterType).toList();

  @override
  void initState() {
    super.initState();
    _loadDeletedItems();
  }

  Future<void> _loadDeletedItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final movies = await provider.getDeletedMovies();
    final books = await provider.getDeletedBooks();
    final notes = await provider.getDeletedNotes();
    final games = await provider.getDeletedGames();
    final movieReviews = await provider.getDeletedMovieReviews();
    final bookReviews = await provider.getDeletedBookReviews();
    final bookExcerpts = await provider.getDeletedBookExcerpts();
    final gameReviews = await provider.getDeletedGameReviews();
    final people = await provider.getDeletedPeople();
    final movieCharacters = await provider.getDeletedMovieCharacters();
    final bookCharacters = await provider.getDeletedBookCharacters();
    final gameCharacters = await provider.getDeletedGameCharacters();
    if (!mounted) return;
    setState(() {
      _allItems = [
        for (final m in movies) _DeletedItem.movie(m),
        for (final b in books) _DeletedItem.book(b),
        for (final n in notes) _DeletedItem.note(n),
        for (final g in games) _DeletedItem.game(g),
        for (final r in movieReviews) _DeletedItem.movieReview(r),
        for (final r in bookReviews) _DeletedItem.bookReview(r),
        for (final e in bookExcerpts) _DeletedItem.bookExcerpt(e),
        for (final r in gameReviews) _DeletedItem.gameReview(r),
        for (final p in people) _DeletedItem.person(p),
        for (final c in movieCharacters) _DeletedItem.movieCharacter(c),
        for (final c in bookCharacters) _DeletedItem.bookCharacter(c),
        for (final c in gameCharacters) _DeletedItem.gameCharacter(c),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('回收站'.tr),
        actions: [
          if (_allItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _showClearAllDialog,
                style: TextButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: colors.error.withValues(alpha: 0.15), width: 0.5),
                  ),
                  minimumSize: Size.zero,
                ),
                child: Text('清空'.tr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
          : Column(
              children: [
                if (_allItems.isNotEmpty) _buildFilterRow(),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadDeletedItems,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filteredItems.length,
                            itemBuilder: (_, i) => _buildCard(_filteredItems[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterRow() {
    final colors = Theme.of(context).colorScheme;
    final chips = <Widget>[
      _filterChip('全部'.tr, null),
      _filterChip('影视'.tr, _ItemType.movie),
      _filterChip('书籍'.tr, _ItemType.book),
      _filterChip('笔记'.tr, _ItemType.note),
      _filterChip('游戏'.tr, _ItemType.game),
      _filterChip('影评'.tr, _ItemType.movieReview),
      _filterChip('书评'.tr, _ItemType.bookReview),
      _filterChip('书摘'.tr, _ItemType.bookExcerpt),
      _filterChip('游戏评价'.tr, _ItemType.gameReview),
      _filterChip('人物'.tr, _ItemType.person),
      _filterChip('影视角色'.tr, _ItemType.movieCharacter),
      _filterChip('书籍角色'.tr, _ItemType.bookCharacter),
      _filterChip('游戏角色'.tr, _ItemType.gameCharacter),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0.0, 0.04, 0.96, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                chips[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, _ItemType? type) {
    final colors = Theme.of(context).colorScheme;
    final active = _filterType == type;
    final count = type == null ? _allItems.length : _allItems.where((i) => i.type == type).length;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label · $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_DeletedItem item) {
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: Key('${item.type.name}_${item.id}'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (_) async =>
          _showConfirmDialog('确定要彻底删除吗？此操作不可恢复。'.tr),
      onDismissed: (_) => _permanentDelete(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant, width: 0.5),
                ),
                child: Icon(item.icon, size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface, height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: colors.outlineVariant, width: 0.5),
                          ),
                          child: Text(
                            item.typeLabel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _actionBtn(Icons.restore, '恢复'.tr, colors.primary, () => _restore(item)),
              const SizedBox(width: 6),
              _actionBtn(Icons.delete_outline, '删除'.tr, colors.error, () => _permanentDelete(item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Icon(Icons.delete_forever, color: Colors.white, size: 22),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.delete_outline, size: 32, color: colors.onSurface.withValues(alpha: 0.15)),
          ),
          const SizedBox(height: 16),
          Text(
            (_filterType == null ? '回收站是空的' : '没有删除的项目').tr,
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
          ),
          const SizedBox(height: 4),
          Text('删除的项目会显示在这里'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.25))),
        ],
      ),
    );
  }

  Future<void> _restore(_DeletedItem item) async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认恢复'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          '确定要恢复"{title}"到{type}里面吗？'.trf({'title': item.title, 'type': item.typeLabel}),
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('恢复'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case _ItemType.movie:
        await provider.restoreMovie(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '影视'.tr}));
      case _ItemType.book:
        await provider.restoreBook(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '书籍'.tr}));
      case _ItemType.note:
        await provider.restoreNote(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '笔记'.tr}));
      case _ItemType.game:
        await provider.restoreGame(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '游戏'.tr}));
      case _ItemType.movieReview:
        await provider.restoreMovieReview(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '影评'.tr}));
      case _ItemType.bookReview:
        await provider.restoreBookReview(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '书评'.tr}));
      case _ItemType.bookExcerpt:
        await provider.restoreBookExcerpt(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '书摘'.tr}));
      case _ItemType.gameReview:
        await provider.restoreGameReview(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '游戏评价'.tr}));
      case _ItemType.person:
        await provider.restorePerson(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '人物'.tr}));
      case _ItemType.movieCharacter:
        await provider.restoreMovieCharacter(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '影视角色'.tr}));
      case _ItemType.bookCharacter:
        await provider.restoreBookCharacter(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '书籍角色'.tr}));
      case _ItemType.gameCharacter:
        await provider.restoreGameCharacter(item.id);
        if (mounted) ToastUtil.show(context, '{type}已恢复'.trf({'type': '游戏角色'.tr}));
    }
    _loadDeletedItems();
  }

  Future<void> _permanentDelete(_DeletedItem item) async {
    final confirmed =
        await _showConfirmDialog('确定要彻底删除吗？此操作不可恢复。'.tr);
    if (!confirmed) return;
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case _ItemType.movie:
        await provider.permanentDeleteMovie(item.id);
      case _ItemType.book:
        await provider.permanentDeleteBook(item.id);
      case _ItemType.note:
        await provider.permanentDeleteNote(item.id);
      case _ItemType.game:
        await provider.permanentDeleteGame(item.id);
      case _ItemType.movieReview:
        await provider.permanentDeleteMovieReview(item.id);
      case _ItemType.bookReview:
        await provider.permanentDeleteBookReview(item.id);
      case _ItemType.bookExcerpt:
        await provider.permanentDeleteBookExcerpt(item.id);
      case _ItemType.gameReview:
        await provider.permanentDeleteGameReview(item.id);
      case _ItemType.person:
        await provider.permanentDeletePerson(item.id);
      case _ItemType.movieCharacter:
        await provider.permanentDeleteMovieCharacter(item.id);
      case _ItemType.bookCharacter:
        await provider.permanentDeleteBookCharacter(item.id);
      case _ItemType.gameCharacter:
        await provider.permanentDeleteGameCharacter(item.id);
    }
    _loadDeletedItems();
    if (mounted) ToastUtil.show(context, '已彻底删除'.tr);
  }

  Future<bool> _showConfirmDialog(String message) async {
    final colors = Theme.of(context).colorScheme;
    final result = await appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(message, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6)),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('删除'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return result ?? false;
  }

  void _showClearAllDialog() {
    final pageContext = context;
    final colors = Theme.of(pageContext).colorScheme;
    appDialog(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text('清空回收站'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ],
        ),
        content: Text(
          '确定要清空回收站吗？所有项目将被彻底删除，此操作不可恢复。'.tr,
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6)),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await pageContext.read<AppProvider>().clearRecycleBin();
              _loadDeletedItems();
              if (mounted) ToastUtil.show(pageContext, '回收站已清空'.tr);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('清空'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

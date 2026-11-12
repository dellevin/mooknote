import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../providers/app_provider.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/publisher_avatar.dart';
import 'publisher_detail_page.dart';

/// 出版社列表页（只读：从书籍 publisher 文本实时聚合，无独立数据表）
class PublisherListPage extends StatefulWidget {
  const PublisherListPage({super.key});

  @override
  State<PublisherListPage> createState() => _PublisherListPageState();
}

/// 聚合后的出版社条目
class _PublisherEntry {
  final String name;
  final int bookCount;
  const _PublisherEntry(this.name, this.bookCount);
}

class _PublisherListPageState extends State<PublisherListPage> {
  String _searchKeyword = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // 字母索引
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _activeLetterNotifier = ValueNotifier<String>('');
  final Map<String, int> _letterFirstIndex = {};
  List<_FlatItem> _flatItems = [];

  static final Map<String, String> _letterCache = {};
  static final Map<String, String> _pinyinCache = {};
  static const List<String> _allLetters = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z','#'
  ];

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    _activeLetterNotifier.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _firstLetter(String name) {
    return _letterCache.putIfAbsent(name, () => _firstLetterUncached(name));
  }

  String _pinyinOf(String name) {
    return _pinyinCache.putIfAbsent(name, () => PinyinHelper.getFirstWordPinyin(name));
  }

  String _firstLetterUncached(String name) {
    final s = name.trim();
    if (s.isEmpty) return '#';
    final first = s.substring(0, 1);
    if (RegExp(r'[A-Za-z]').hasMatch(first)) return first.toUpperCase();
    final py = PinyinHelper.getFirstWordPinyin(first);
    if (py.isEmpty) return '#';
    final c = py.substring(0, 1).toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  /// 从书籍列表聚合出版社：精确匹配 trim 后的完整社名，不拆分分隔符
  List<_PublisherEntry> _aggregatePublishers(List<dynamic> books) {
    final counts = <String, int>{};
    for (final b in books) {
      if (b.isDeleted) continue;
      final name = b.publisher?.trim() ?? '';
      if (name.isEmpty) continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final entries = counts.entries
        .map((e) => _PublisherEntry(e.key, e.value))
        .toList();
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      entries.removeWhere((e) => !e.name.toLowerCase().contains(kw));
    }
    return entries;
  }

  void _buildFlatItems(List<_PublisherEntry> entries) {
    _flatItems = [];
    _letterFirstIndex.clear();
    if (entries.isEmpty) {
      _activeLetterNotifier.value = '';
      return;
    }

    final groups = <String, List<_PublisherEntry>>{};
    for (final e in entries) {
      final letter = _firstLetter(e.name);
      groups.putIfAbsent(letter, () => []).add(e);
    }
    for (final g in groups.values) {
      g.sort((a, b) => _pinyinOf(a.name).compareTo(_pinyinOf(b.name)));
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });

    for (final k in keys) {
      _letterFirstIndex[k] = _flatItems.length;
      _flatItems.add(_FlatItem.letter(k));
      for (final e in groups[k]!) {
        _flatItems.add(_FlatItem.publisher(e));
      }
    }

    if (_activeLetterNotifier.value.isEmpty || !_letterFirstIndex.containsKey(_activeLetterNotifier.value)) {
      _activeLetterNotifier.value = keys.first;
    }
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final firstVisible = positions.reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    final idx = firstVisible.index;
    String current = '';
    for (final entry in _letterFirstIndex.entries) {
      if (entry.value <= idx) {
        current = entry.key;
      } else {
        break;
      }
    }
    if (current.isNotEmpty && current != _activeLetterNotifier.value) {
      _activeLetterNotifier.value = current;
    }
  }

  void _jumpToLetter(String letter) {
    final index = _letterFirstIndex[letter];
    if (index == null) return;
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.jumpTo(index: index);
  }

  Widget _buildIndexBar(ColorScheme colors) {
    final present = _letterFirstIndex.keys.toSet();
    final barKey = GlobalKey();
    return Positioned(
      right: 2,
      top: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          const barPadding = 4.0;
          final available = maxH - barPadding * 2;
          // 触摸格严格均分整条高度，保证触点换算与视觉位置一致；字体单独限幅
          final itemH = available / _allLetters.length;

          String letterAtY(double y) {
            final localY = (y - barPadding).clamp(0.0, available);
            final i = (localY / itemH).floor().clamp(0, _allLetters.length - 1);
            return _allLetters[i];
          }

          void handleAt(Offset globalPos) {
            final robj = barKey.currentContext?.findRenderObject();
            if (robj is! RenderBox) return;
            final local = robj.globalToLocal(globalPos);
            final letter = letterAtY(local.dy);
            if (!present.contains(letter)) return;
            if (_activeLetterNotifier.value != letter) {
              _activeLetterNotifier.value = letter;
              _jumpToLetter(letter);
            }
          }

          return Padding(
            key: barKey,
            padding: const EdgeInsets.symmetric(vertical: barPadding),
            child: ValueListenableBuilder<String>(
              valueListenable: _activeLetterNotifier,
              builder: (context, activeLetter, _) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragDown: (d) => handleAt(d.globalPosition),
                  onVerticalDragUpdate: (d) => handleAt(d.globalPosition),
                  onTapDown: (d) => handleAt(d.globalPosition),
                  child: Container(
                    width: 22,
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final letter in _allLetters)
                          SizedBox(
                            height: itemH,
                            width: 22,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: (activeLetter == letter ? itemH * 0.95 : itemH * 0.7)
                                    .clamp(8.0, 15.0),
                                fontWeight: activeLetter == letter ? FontWeight.w800 : FontWeight.w500,
                                color: present.contains(letter)
                                    ? (activeLetter == letter ? colors.primary : colors.onSurface.withValues(alpha: 0.7))
                                    : colors.onSurface.withValues(alpha: 0.25),
                              ),
                              child: Text(letter, textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final books = context.watch<AppProvider>().books;
    final entries = _aggregatePublishers(books);
    _buildFlatItems(entries);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('出版社'.tr),
      ),
      body: Column(
        children: [
          _buildSearchBar(colors),
          Expanded(
            child: entries.isEmpty
                ? _buildEmptyState(colors)
                : Stack(
                    children: [
                      ScrollablePositionedList.builder(
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        padding: const EdgeInsets.only(left: 16, right: 28, top: 8, bottom: 8),
                        itemCount: _flatItems.length,
                        itemBuilder: (context, i) {
                          final item = _flatItems[i];
                          if (item.isHeader) {
                            return Container(
                              height: 26,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(top: 8, bottom: 2),
                              child: Text(
                                item.letter!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            );
                          }
                          return _buildPublisherItem(item.entry!, colors);
                        },
                      ),
                      _buildIndexBar(colors),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: '搜索出版社名称'.tr,
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _searchKeyword = v),
              ),
            ),
            if (_searchKeyword.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _searchKeyword = '');
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              )
            else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPublisherItem(_PublisherEntry entry, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _navigateToDetail(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const PublisherAvatar(
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '书籍 ({n})'.trf({'n': entry.bookCount}),
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
        Divider(
          height: 0.5,
          thickness: 0.5,
          indent: 44,
          endIndent: 0,
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_library_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            _searchKeyword.isNotEmpty ? '未找到匹配的出版社'.tr : '暂无出版社'.tr,
            style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(_PublisherEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublisherDetailPage(publisherName: entry.name),
      ),
    );
  }
}

class _FlatItem {
  final String? letter;
  final _PublisherEntry? entry;
  bool get isHeader => letter != null;

  _FlatItem.letter(this.letter) : entry = null;
  _FlatItem.publisher(this.entry) : letter = null;
}

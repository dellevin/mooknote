import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../widgets/person_avatar.dart';
import 'person_detail_page.dart';
import 'person_form_page.dart';

/// 人物列表页
class PersonListPage extends StatefulWidget {
  const PersonListPage({super.key});

  @override
  State<PersonListPage> createState() => _PersonListPageState();
}

class _PersonListPageState extends State<PersonListPage> {
  String _searchKeyword = '';
  String? _occupationFilter; // 职业筛选
  final TextEditingController _searchCtrl = TextEditingController();

  // 字母索引
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _activeLetterNotifier = ValueNotifier<String>('');
  final Map<String, int> _letterFirstIndex = {};
  List<_FlatItem> _flatItems = [];
  List<Person> _lastFiltered = const [];

  // 拼音缓存：人名 -> 首字母；人名 -> 拼音（用于组内排序）
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

  /// 取人名首字母（A-Z），非字母开头返回 '#'。结果缓存。
  String _firstLetter(String name) {
    return _letterCache.putIfAbsent(name, () => _firstLetterUncached(name));
  }

  /// 取人名拼音（用于组内排序）。结果缓存。
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

  /// 把 filtered 列表按首字母分组，扁平化为 header + person。
  /// 仅在 filtered 引用或长度变化时重算，避免每次 build 重复计算。
  void _buildFlatItems(List<Person> filtered) {
    if (identical(filtered, _lastFiltered) && filtered.length == _lastFiltered.length) return;
    _lastFiltered = filtered;
    _flatItems = [];
    _letterFirstIndex.clear();
    if (filtered.isEmpty) {
      _activeLetterNotifier.value = '';
      return;
    }

    final groups = <String, List<Person>>{};
    for (final p in filtered) {
      final letter = _firstLetter(p.name);
      groups.putIfAbsent(letter, () => []).add(p);
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
      for (final p in groups[k]!) {
        _flatItems.add(_FlatItem.person(p));
      }
    }

    if (_activeLetterNotifier.value.isEmpty || !_letterFirstIndex.containsKey(_activeLetterNotifier.value)) {
      _activeLetterNotifier.value = keys.first;
    }
  }

  void _onPositionsChanged() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    // 取屏幕顶部第一个可见 item 的 index，反查它属于哪个字母
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
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
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
          final itemH = (available / _allLetters.length).clamp(12.0, 24.0);

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
                    width: itemH + 12,
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final letter in _allLetters)
                          SizedBox(
                            height: itemH,
                            width: itemH + 12,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: activeLetter == letter ? itemH * 0.95 : itemH * 0.7,
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

  List<Person> _filterPeople(List<Person> people) {
    var result = people;
    if (_occupationFilter != null) {
      result = result.where((p) => p.occupation.contains(_occupationFilter)).toList();
    }
    if (_searchKeyword.isNotEmpty) {
      final kw = _searchKeyword.toLowerCase();
      result = result.where((p) {
        if (p.name.toLowerCase().contains(kw)) return true;
        if (p.alternateNames.any((n) => n.toLowerCase().contains(kw))) return true;
        return false;
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final people = context.watch<AppProvider>().people;
    final filtered = _filterPeople(people);
    _buildFlatItems(filtered);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('人物'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '扫描作品自动关联',
            onPressed: () => _refreshRelations(),
          ),
          IconButton(
            icon: const Icon(Icons.add_outlined),
            tooltip: '添加人物',
            onPressed: () => _navigateToForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(colors),
          // 职业筛选
          _buildOccupationFilter(colors, people),
          // 列表
          Expanded(
            child: filtered.isEmpty
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
                              height: 32,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(top: 10, bottom: 4),
                              child: Text(
                                item.letter!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            );
                          }
                          return _buildPersonItem(item.person!, colors);
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
                  hintText: '搜索人物名称或别名',
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

  Widget _buildOccupationFilter(ColorScheme colors, List<Person> people) {
    // 收集所有职业及其数量
    final occupationCounts = <String, int>{};
    for (final p in people) {
      for (final occ in p.occupation) {
        occupationCounts[occ] = (occupationCounts[occ] ?? 0) + 1;
      }
    }
    if (occupationCounts.isEmpty) return const SizedBox.shrink();

    final sorted = occupationCounts.keys.toList()..sort();
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        children: [
          _buildFilterChip('全部', null, people.length, colors),
          for (final occ in sorted)
            _buildFilterChip(occ, occ, occupationCounts[occ] ?? 0, colors),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? value, int count, ColorScheme colors) {
    final selected = _occupationFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _occupationFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                  color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? colors.onPrimary.withValues(alpha: 0.7) : colors.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonItem(Person person, ColorScheme colors) {
    return InkWell(
      onTap: () => _navigateToDetail(person),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            PersonAvatar(
              photoPath: person.photoPath,
              name: person.name,
              size: 48,
              fontSize: 20,
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (person.occupation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      person.occupation.join(' / '),
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (person.alternateNames.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '又名：${person.alternateNames.join('、')}',
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 16),
          Text(
            _searchKeyword.isNotEmpty ? '未找到匹配的人物' : '暂无人物',
            style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
          if (_searchKeyword.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _navigateToForm(),
              child: const Text('添加人物'),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToDetail(Person person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonDetailPage(person: person),
      ),
    );
  }

  Future<void> _refreshRelations() async {
    final provider = context.read<AppProvider>();
    // 显示加载弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    try {
      final result = await provider.refreshPersonRelations();
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载弹窗
      if (result.newPersons == 0 && result.newRelations == 0 && result.merged == 0) {
        ToastUtil.show(context, '已是最新，无新增关联');
      } else {
        final parts = <String>[];
        if (result.merged > 0) parts.add('合并 ${result.merged} 个重复人物');
        if (result.newPersons > 0) parts.add('新增 ${result.newPersons} 个人物');
        if (result.newRelations > 0) parts.add('${result.newRelations} 条关联');
        ToastUtil.show(context, parts.join('，'));
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ToastUtil.show(context, '刷新失败：$e');
    }
  }

  void _navigateToForm([Person? person]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonFormPage(person: person),
      ),
    ).then((_) {
      if (mounted) context.read<AppProvider>().loadPeople();
    });
  }
}

class _FlatItem {
  final String? letter;
  final Person? person;
  bool get isHeader => letter != null;

  _FlatItem.letter(this.letter) : person = null;
  _FlatItem.person(this.person) : letter = null;
}

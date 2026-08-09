import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/responsive.dart';
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildPersonItem(filtered[index], colors),
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

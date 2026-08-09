import 'package:flutter/material.dart';
import '../../utils/user_prefs.dart';
import 'search_page.dart';
import 'online_search_page.dart';

/// 统一搜索页 —— 本地搜索 / 增强搜索（在线）切换
class SearchHubPage extends StatefulWidget {
  const SearchHubPage({super.key});

  @override
  State<SearchHubPage> createState() => _SearchHubPageState();
}

class _SearchHubPageState extends State<SearchHubPage> {
  late bool _isOnline;

  @override
  void initState() {
    super.initState();
    _isOnline = UserPrefs().lastSearchOnline;
  }

  void _switchTo(bool online) {
    if (!mounted || _isOnline == online) return;
    setState(() => _isOnline = online);
    UserPrefs().setLastSearchOnline(online);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showToggle = UserPrefs().enhancedSearchEnabled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (showToggle) _buildToggle(colors),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _isOnline ? 1 : 0,
        children: const [
          SearchPageBody(),
          OnlineSearchPageBody(),
        ],
      ),
    );
  }

  Widget _buildToggle(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('本地', !_isOnline, () => _switchTo(false), colors),
          _toggleBtn('增强', _isOnline, () => _switchTo(true), colors),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap, ColorScheme colors) {
    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

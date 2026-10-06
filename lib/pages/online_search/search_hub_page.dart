import 'package:flutter/material.dart';
import '../../utils/user_prefs.dart';
import '../../l10n/app_strings.dart';
import 'search_page.dart';
import 'online_search_page.dart';
import 'tmdb_search_page.dart';

/// 统一搜索页 —— 本地 / 增强 / TMDB 切换
class SearchHubPage extends StatefulWidget {
  const SearchHubPage({super.key});

  @override
  State<SearchHubPage> createState() => _SearchHubPageState();
}

class _SearchHubPageState extends State<SearchHubPage> {
  late int _mode;

  bool get _enhancedOn => UserPrefs().enhancedSearchEnabled;
  bool get _tmdbOn => UserPrefs().tmdbApiToken.isNotEmpty;

  /// 可用模式: 0=本地, 1=增强, 2=TMDB
  List<int> get _modes => [0, if (_enhancedOn) 1, if (_tmdbOn) 2];

  @override
  void initState() {
    super.initState();
    _mode = UserPrefs().lastSearchMode;
    if (!_modes.contains(_mode)) _mode = 0;
  }

  void _switchTo(int mode) {
    if (!mounted || _mode == mode) return;
    setState(() => _mode = mode);
    UserPrefs().setLastSearchMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final modes = _modes;
    if (!modes.contains(_mode)) _mode = 0;
    final children = <Widget>[
      const SearchPageBody(),
      if (_enhancedOn) const OnlineSearchPageBody(),
      if (_tmdbOn) const TmdbSearchPageBody(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('搜索'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (modes.length > 1) _buildToggle(colors, modes),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: modes.indexOf(_mode),
        children: children,
      ),
    );
  }

  Widget _buildToggle(ColorScheme colors, List<int> modes) {
    String labelOf(int mode) {
      switch (mode) {
        case 1:
          return '增强'.tr;
        case 2:
          return 'TMDB';
        default:
          return '本地'.tr;
      }
    }

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
          for (final m in modes)
            _toggleBtn(
                labelOf(m), _mode == m, () => _switchTo(m), colors),
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

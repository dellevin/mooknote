import 'package:flutter/material.dart';
import '../../utils/user_prefs.dart';
import 'epub_player.dart';

/// 预设主题
const _presetThemes = [
  {'bg': 'FFFFFFFF', 'fg': 'FF1A1A1A', 'name': '默认'},
  {'bg': 'FF1A1A1A', 'fg': 'FFE5E5E5', 'name': '暗黑'},
  {'bg': 'FFF8F0E3', 'fg': 'FF333333', 'name': '护眼'},
  {'bg': 'FF2B2B2B', 'fg': 'FFCCCCCC', 'name': '深灰'},
  {'bg': 'FF2D3E50', 'fg': 'FFD4D4D4', 'name': '蓝灰'},
];

/// 样式设置面板 — 字号、行距、主题
class StylePanel extends StatefulWidget {
  final GlobalKey<EpubPlayerState> epubPlayerKey;

  const StylePanel({super.key, required this.epubPlayerKey});

  @override
  State<StylePanel> createState() => _StylePanelState();
}

class _StylePanelState extends State<StylePanel> {
  double _fontSize = 1.0;
  double _lineHeight = 1.6;
  int _selectedTheme = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  void _loadPrefs() {
    final sp = UserPrefs().prefs;
    setState(() {
      _fontSize = sp.getDouble('reader_font_size') ?? 1.0;
      _lineHeight = sp.getDouble('reader_line_height') ?? 1.6;
      _selectedTheme = sp.getInt('reader_theme_index') ?? 0;
    });
  }

  void _savePrefs() {
    final sp = UserPrefs().prefs;
    sp.setDouble('reader_font_size', _fontSize);
    sp.setDouble('reader_line_height', _lineHeight);
    sp.setInt('reader_theme_index', _selectedTheme);
  }

  void _applyStyle() {
    widget.epubPlayerKey.currentState?.changeStyle(
      fontSize: _fontSize,
      lineHeight: _lineHeight,
    );
    _savePrefs();
  }

  void _applyTheme(int index) {
    final theme = _presetThemes[index];
    final bg = theme['bg']!;
    final fg = theme['fg']!;
    widget.epubPlayerKey.currentState?.changeTheme(bg, fg);
    setState(() => _selectedTheme = index);
    _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 字号
          Row(
            children: [
              Text('字号', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: '${(_fontSize * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _fontSize = value);
                    _applyStyle();
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text('${(_fontSize * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
              ),
            ],
          ),
          // 行距
          Row(
            children: [
              Text('行距', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
              Expanded(
                child: Slider(
                  value: _lineHeight,
                  min: 1.0,
                  max: 3.0,
                  divisions: 20,
                  label: _lineHeight.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _lineHeight = value);
                    _applyStyle();
                  },
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(_lineHeight.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 主题色块
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_presetThemes.length, (index) {
              final theme = _presetThemes[index];
              final bg = Color(int.parse(theme['bg']!, radix: 16));
              final fg = Color(int.parse(theme['fg']!, radix: 16));
              final isSelected = index == _selectedTheme;

              return GestureDetector(
                onTap: () => _applyTheme(index),
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.outlineVariant,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('A', style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

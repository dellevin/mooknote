import 'package:flutter/material.dart';
import '../../utils/epub/epub_theme.dart';
import 'widgets/integer_stepper.dart';
import 'widgets/reader_scale_slider.dart';

/// Simplified reader style configuration bottom sheet.
///
/// Provides zoom slider, margin controls, and font size adjustments.
class ReaderStyleSheet extends StatefulWidget {
  final double zoom;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final double fontSize;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onMarginTopChanged;
  final ValueChanged<double> onMarginBottomChanged;
  final ValueChanged<double> onMarginLeftChanged;
  final ValueChanged<double> onMarginRightChanged;
  final ValueChanged<double> onFontSizeChanged;
  final int themeIndex;
  final int customBgColor;
  final int customTextColor;
  final ValueChanged<int> onThemeIndexChanged;
  final void Function(int bgColor, int textColor) onCustomColorChanged;

  const ReaderStyleSheet({
    super.key,
    required this.zoom,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.fontSize,
    required this.onZoomChanged,
    required this.onMarginTopChanged,
    required this.onMarginBottomChanged,
    required this.onMarginLeftChanged,
    required this.onMarginRightChanged,
    required this.onFontSizeChanged,
    required this.themeIndex,
    required this.customBgColor,
    required this.customTextColor,
    required this.onThemeIndexChanged,
    required this.onCustomColorChanged,
  });

  @override
  State<ReaderStyleSheet> createState() => _ReaderStyleSheetState();
}

class _ReaderStyleSheetState extends State<ReaderStyleSheet> {
  late double _scale;
  late int _topMargin;
  late int _bottomMargin;
  late int _leftMargin;
  late int _rightMargin;
  late double _fontSize;
  late int _themeIndex;
  late int _customBgColor;
  late int _customTextColor;

  static const int _marginMin = 0;
  static const int _marginMax = 64;
  static const int _marginStep = 2;
  static const double _fontSizeMin = 12.0;
  static const double _fontSizeMax = 32.0;

  @override
  void initState() {
    super.initState();
    _scale = widget.zoom;
    _topMargin = widget.marginTop.toInt();
    _bottomMargin = widget.marginBottom.toInt();
    _leftMargin = widget.marginLeft.toInt();
    _rightMargin = widget.marginRight.toInt();
    _fontSize = widget.fontSize;
    _themeIndex = widget.themeIndex;
    _customBgColor = widget.customBgColor;
    _customTextColor = widget.customTextColor;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -- 缩放比例 --
                const _SectionTitle(label: '缩放比例'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _SubLabel(label: '缩放'),
                    const Spacer(),
                    Text(
                      '${_scale.toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ReaderScaleSlider(
                  value: _scale,
                  onChanged: (v) {
                    setState(() => _scale = v);
                    widget.onZoomChanged(v);
                  },
                ),

                const SizedBox(height: 20),

                // -- 字号 --
                const _SectionTitle(label: '字号'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const _SubLabel(label: '字号'),
                    const Spacer(),
                    Text(
                      '${_fontSize.toInt()}px',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _fontSize > _fontSizeMin
                          ? () {
                              final v =
                                  (_fontSize - 1).clamp(_fontSizeMin, _fontSizeMax);
                              setState(() => _fontSize = v);
                              widget.onFontSizeChanged(v);
                            }
                          : null,
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 12,
                          color: _fontSize > _fontSizeMin
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: _fontSizeMin,
                        max: _fontSizeMax,
                        divisions: 20,
                        label: _fontSize.toInt().toString(),
                        onChanged: (v) {
                          setState(() => _fontSize = v);
                          widget.onFontSizeChanged(v);
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: _fontSize < _fontSizeMax
                          ? () {
                              final v =
                                  (_fontSize + 1).clamp(_fontSizeMin, _fontSizeMax);
                              setState(() => _fontSize = v);
                              widget.onFontSizeChanged(v);
                            }
                          : null,
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: 22,
                          color: _fontSize < _fontSizeMax
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // -- 边距 --
                const _SectionTitle(label: '边距'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: IntegerStepper(
                        label: '上',
                        value: _topMargin,
                        min: _marginMin,
                        max: _marginMax,
                        step: _marginStep,
                        onChanged: (v) {
                          setState(() => _topMargin = v);
                          widget.onMarginTopChanged(v.toDouble());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: IntegerStepper(
                        label: '下',
                        value: _bottomMargin,
                        min: _marginMin,
                        max: _marginMax,
                        step: _marginStep,
                        onChanged: (v) {
                          setState(() => _bottomMargin = v);
                          widget.onMarginBottomChanged(v.toDouble());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: IntegerStepper(
                        label: '左',
                        value: _leftMargin,
                        min: _marginMin,
                        max: _marginMax,
                        step: _marginStep,
                        onChanged: (v) {
                          setState(() => _leftMargin = v);
                          widget.onMarginLeftChanged(v.toDouble());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: IntegerStepper(
                        label: '右',
                        value: _rightMargin,
                        min: _marginMin,
                        max: _marginMax,
                        step: _marginStep,
                        onChanged: (v) {
                          setState(() => _rightMargin = v);
                          widget.onMarginRightChanged(v.toDouble());
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // -- 阅读主题 --
                const _SectionTitle(label: '阅读主题'),
                const SizedBox(height: 10),
                _buildThemePresets(colorScheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemePresets(ColorScheme colorScheme) {
    final presets = ReaderThemePresets.presets;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length + 1, // +1 for custom
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final isSelected = _themeIndex == i;
          final borderColor = isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant;
          if (i < presets.length) {
            final preset = presets[i];
            return GestureDetector(
              onTap: () {
                setState(() => _themeIndex = i);
                widget.onThemeIndexChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: i == 0
                      ? colorScheme.surfaceContainerHighest
                      : preset.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: Center(
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: i == 0
                              ? colorScheme.onSurface
                              : preset.onSurface,
                        )
                      : i == 0
                          ? Icon(
                              Icons.phone_android,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            )
                          : Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: preset.onSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                ),
              ),
            );
          }
          // Custom color chip
          return GestureDetector(
            onTap: () => _showCustomColorPicker(ctx),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Color(_customBgColor),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: Center(
                child: isSelected
                    ? Icon(Icons.check, size: 20, color: Color(_customTextColor))
                    : Icon(Icons.palette_outlined, size: 18, color: Color(_customTextColor)),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCustomColorPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bgColor = Color(_customBgColor);
    Color textColor = Color(_customTextColor);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('自定义颜色', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Preview
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant, width: 0.5),
                    ),
                    child: Center(
                      child: Text('预览文字 Aa 字体',
                          style: TextStyle(color: textColor, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Background color
                  _buildColorRow(
                    label: '背景色',
                    color: bgColor,
                    onChanged: (c) => setDialogState(() => bgColor = c),
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  // Text color
                  _buildColorRow(
                    label: '文字色',
                    color: textColor,
                    onChanged: (c) => setDialogState(() => textColor = c),
                    cs: cs,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _customBgColor = bgColor.value;
                      _customTextColor = textColor.value;
                      _themeIndex = 9;
                    });
                    widget.onCustomColorChanged(bgColor.value, textColor.value);
                    widget.onThemeIndexChanged(9);
                    Navigator.pop(ctx);
                  },
                  child: Text('确定', style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildColorRow({
    required String label,
    required Color color,
    required ValueChanged<Color> onChanged,
    required ColorScheme cs,
  }) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const Spacer(),
        // Preset color chips
        ..._presetColors.map((c) {
          final selected = c.$2 == color;
          return GestureDetector(
            onTap: () => onChanged(c.$2),
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: c.$2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 14,
                      color: ThemeData.estimateBrightnessForColor(c.$2) == Brightness.dark
                          ? Colors.white : Colors.black)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  static const _presetColors = [
    ('白色', Color(0xFFFFFFFF)),
    ('浅灰', Color(0xFFF5F5F5)),
    ('护眼', Color(0xFFF4ECD8)),
    ('抹茶', Color(0xFFF6FBF5)),
    ('樱花', Color(0xFFFFF8F8)),
    ('浅蓝', Color(0xFFF0F4FF)),
    ('深灰', Color(0xFF333333)),
    ('深褐', Color(0xFF2C2418)),
    ('深蓝', Color(0xFF1A2A3A)),
    ('深绿', Color(0xFF1A2E1A)),
    ('黑色', Color(0xFF1A1A1A)),
    ('深红', Color(0xFF3A1A1A)),
  ];
}

/// Section title (equivalent to lumina's SettingsSectionTitle)
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Sub-label (equivalent to lumina's SettingsSubLabel)
class _SubLabel extends StatelessWidget {
  const _SubLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

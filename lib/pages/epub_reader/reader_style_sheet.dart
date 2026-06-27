import 'package:flutter/material.dart';
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
              ],
            ),
          ),
        );
      },
    );
  }
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

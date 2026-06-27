import 'package:flutter/material.dart';
import 'reader_scripts.dart';

/// 阅读器主题预设
class ReaderThemePreset {
  final String name;
  final Color surface;
  final Color onSurface;
  final bool isDark;

  const ReaderThemePreset({
    required this.name,
    required this.surface,
    required this.onSurface,
    this.isDark = false,
  });
}

class ReaderThemePresets {
  static const List<ReaderThemePreset> presets = [
    ReaderThemePreset(name: '跟随App', surface: Colors.white, onSurface: Colors.black),
    ReaderThemePreset(name: '纯白', surface: Color(0xFFFFFFFF), onSurface: Color(0xFF1A1A1A)),
    ReaderThemePreset(name: '护眼', surface: Color(0xFFF4ECD8), onSurface: Color(0xFF5B4636)),
    ReaderThemePreset(name: '抹茶', surface: Color(0xFFF6FBF5), onSurface: Color(0xFF2E3E2E)),
    ReaderThemePreset(name: '樱花', surface: Color(0xFFFFF8F8), onSurface: Color(0xFF4A2030)),
    ReaderThemePreset(name: '午夜蓝', surface: Color(0xFFF7F9FC), onSurface: Color(0xFF1A2A3A)),
    ReaderThemePreset(name: '深色', surface: Color(0xFF191919), onSurface: Color(0xFFD4D4D4), isDark: true),
    ReaderThemePreset(name: '深色护眼', surface: Color(0xFF1C1A18), onSurface: Color(0xFFC8B8A0), isDark: true),
    ReaderThemePreset(name: '咖啡', surface: Color(0xFFFCF8F3), onSurface: Color(0xFF3E2E1E)),
  ];
}

class EpubTheme {
  final double zoom;
  final bool shouldOverrideTextColor;
  final ColorScheme colorScheme;
  final Color? overridePrimaryColor;
  final EdgeInsets padding;

  /// File name (with extension) of the custom font, or null for epub default.
  final String? fontFileName;

  /// When true, force the custom font on top of the epub's own font rules.
  final bool overrideFontFamily;

  EpubTheme({
    required this.zoom,
    required this.shouldOverrideTextColor,
    required this.colorScheme,
    this.overridePrimaryColor,
    required this.padding,
    this.fontFileName,
    this.overrideFontFamily = false,
  });

  bool get isDark => colorScheme.brightness == Brightness.dark;

  Color get surfaceColor => colorScheme.surface;

  EpubTheme copyWith({
    double? zoom,
    bool? shouldOverrideTextColor,
    ColorScheme? colorScheme,
    Color? overridePrimaryColor,
    EdgeInsets? padding,
    Object? fontFileName = _kUnset,
    bool? overrideFontFamily,
  }) {
    return EpubTheme(
      zoom: zoom ?? this.zoom,
      shouldOverrideTextColor:
          shouldOverrideTextColor ?? this.shouldOverrideTextColor,
      colorScheme: colorScheme ?? this.colorScheme,
      overridePrimaryColor: overridePrimaryColor ?? this.overridePrimaryColor,
      padding: padding ?? this.padding,
      fontFileName: identical(fontFileName, _kUnset)
          ? this.fontFileName
          : fontFileName as String?,
      overrideFontFamily: overrideFontFamily ?? this.overrideFontFamily,
    );
  }

  static const Object _kUnset = Object();

  Map<String, dynamic> toThemeMap() {
    return {
      'padding': {'top': padding.top, 'left': padding.left},
      'theme': {
        'zoom': zoom,
        'shouldOverrideTextColor': shouldOverrideTextColor,

        'primaryColor': overridePrimaryColor != null
            ? colorToMap(overridePrimaryColor!)
            : colorToMap(colorScheme.primary),
        'onPrimaryColor': colorToMap(colorScheme.onPrimary),
        'secondaryColor': colorToMap(colorScheme.secondary),
        'onSecondaryColor': colorToMap(colorScheme.onSecondary),
        'errorColor': colorToMap(colorScheme.error),
        'onErrorColor': colorToMap(colorScheme.onError),
        'surfaceColor': colorToMap(colorScheme.surface),
        'onSurfaceColor': colorToMap(colorScheme.onSurface),
        'primaryContainerColor': colorToMap(colorScheme.primaryContainer),
        'onSurfaceVariantColor': colorToMap(colorScheme.onSurfaceVariant),
        'outlineVariantColor': colorToMap(colorScheme.outlineVariant),
        'surfaceContainerColor': colorToMap(colorScheme.surfaceContainer),
        'surfaceContainerHighColor': colorToMap(
          colorScheme.surfaceContainerHigh,
        ),

        'fontFileName': fontFileName,
        'overrideFontFamily': overrideFontFamily,
      },
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EpubTheme &&
        other.zoom == zoom &&
        other.shouldOverrideTextColor == shouldOverrideTextColor &&
        other.colorScheme == colorScheme &&
        other.overridePrimaryColor == overridePrimaryColor &&
        other.padding == padding &&
        other.fontFileName == fontFileName &&
        other.overrideFontFamily == overrideFontFamily;
  }

  @override
  int get hashCode => Object.hash(
        zoom,
        shouldOverrideTextColor,
        colorScheme,
        overridePrimaryColor,
        padding,
        fontFileName,
        overrideFontFamily,
      );
}

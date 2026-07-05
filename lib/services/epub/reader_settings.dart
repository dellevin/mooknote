import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'epub_theme.dart';

/// Controls how the reader handles external link taps.
enum ReaderLinkHandling { ask, always, never }

/// Controls the page-turning animation style.
enum ReaderPageAnimation { none, slide }

class ReaderSettings {
  final double zoom;
  final bool followAppTheme;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final ReaderLinkHandling linkHandling;
  final ReaderPageAnimation pageAnimation;

  /// File name (with extension) of the user-imported font to use, or null to
  /// use the epub's own fonts.
  final String? fontFileName;

  /// When true the custom font overrides the epub's own font-family rules.
  final bool overrideFontFamily;

  /// When true, volume up/down keys turn pages in the reader.
  final bool volumeKeyTurnsPage;

  /// Reader theme preset index (0 = follow app, 1-8 = presets, 9 = custom).
  final int themeIndex;

  /// Custom background color (ARGB int), used when themeIndex == 9.
  final int customBgColor;

  /// Custom text color (ARGB int), used when themeIndex == 9.
  final int customTextColor;

  const ReaderSettings({
    this.zoom = 1.0,
    this.followAppTheme = true,
    this.marginTop = 16.0,
    this.marginBottom = 16.0,
    this.marginLeft = 16.0,
    this.marginRight = 16.0,
    this.linkHandling = ReaderLinkHandling.ask,
    this.pageAnimation = ReaderPageAnimation.slide,
    this.fontFileName,
    this.overrideFontFamily = false,
    this.volumeKeyTurnsPage = false,
    this.themeIndex = 0,
    this.customBgColor = 0xFFFFFFFF,
    this.customTextColor = 0xFF1A1A1A,
  });

  // Sentinel: lets copyWith(fontFileName: null) mean "set to null" rather than
  // "leave unchanged". Used only for the nullable fontFileName field.
  static const Object _kUnset = Object();

  ReaderSettings copyWith({
    double? zoom,
    bool? followAppTheme,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    ReaderLinkHandling? linkHandling,
    ReaderPageAnimation? pageAnimation,
    Object? fontFileName = _kUnset,
    bool? overrideFontFamily,
    bool? volumeKeyTurnsPage,
    int? themeIndex,
    int? customBgColor,
    int? customTextColor,
  }) {
    return ReaderSettings(
      zoom: zoom ?? this.zoom,
      followAppTheme: followAppTheme ?? this.followAppTheme,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      linkHandling: linkHandling ?? this.linkHandling,
      pageAnimation: pageAnimation ?? this.pageAnimation,
      fontFileName: identical(fontFileName, _kUnset)
          ? this.fontFileName
          : fontFileName as String?,
      overrideFontFamily: overrideFontFamily ?? this.overrideFontFamily,
      volumeKeyTurnsPage: volumeKeyTurnsPage ?? this.volumeKeyTurnsPage,
      themeIndex: themeIndex ?? this.themeIndex,
      customBgColor: customBgColor ?? this.customBgColor,
      customTextColor: customTextColor ?? this.customTextColor,
    );
  }

  EpubTheme toEpubTheme(BuildContext context) {
    ColorScheme colorScheme;
    bool shouldOverride = true;

    if (themeIndex == 0) {
      // 跟随 App 主题
      colorScheme = Theme.of(context).colorScheme;
    } else {
      Color bg;
      Color text;
      bool isDark;

      if (themeIndex == 9) {
        // 自定义颜色
        bg = Color(customBgColor);
        text = Color(customTextColor);
        isDark = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;
      } else if (themeIndex >= 1 &&
          themeIndex <= ReaderThemePresets.presets.length) {
        final preset = ReaderThemePresets.presets[themeIndex];
        bg = preset.surface;
        text = preset.onSurface;
        isDark = preset.isDark;
      } else {
        colorScheme = Theme.of(context).colorScheme;
        return EpubTheme(
          zoom: zoom,
          shouldOverrideTextColor: true,
          colorScheme: colorScheme,
          padding: EdgeInsets.only(
            top: marginTop, bottom: marginBottom,
            left: marginLeft, right: marginRight,
          ),
          fontFileName: fontFileName,
          overrideFontFamily: overrideFontFamily,
        );
      }

      colorScheme = ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: text,
        onPrimary: bg,
        secondary: text,
        onSecondary: bg,
        error: const Color(0xFFDC2626),
        onError: bg,
        surface: bg,
        onSurface: text,
        surfaceContainerHighest: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        surfaceContainerHigh: isDark ? const Color(0xFF222222) : const Color(0xFFFAFAFA),
        surfaceContainer: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        surfaceContainerLow: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
        outline: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
        outlineVariant: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5),
        onSurfaceVariant: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
        primaryContainer: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
      );
    }

    return EpubTheme(
      zoom: zoom,
      shouldOverrideTextColor: shouldOverride,
      colorScheme: colorScheme,
      padding: EdgeInsets.only(
        top: marginTop, bottom: marginBottom,
        left: marginLeft, right: marginRight,
      ),
      fontFileName: fontFileName,
      overrideFontFamily: overrideFontFamily,
    );
  }

  // ==================== Persistence ====================

  static const _kPrefix = 'reader_';

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_kPrefix}zoom', zoom);
    await prefs.setBool('${_kPrefix}followAppTheme', followAppTheme);
    await prefs.setDouble('${_kPrefix}marginTop', marginTop);
    await prefs.setDouble('${_kPrefix}marginBottom', marginBottom);
    await prefs.setDouble('${_kPrefix}marginLeft', marginLeft);
    await prefs.setDouble('${_kPrefix}marginRight', marginRight);
    await prefs.setInt('${_kPrefix}linkHandling', linkHandling.index);
    await prefs.setInt('${_kPrefix}pageAnimation', pageAnimation.index);
    if (fontFileName != null) {
      await prefs.setString('${_kPrefix}fontFileName', fontFileName!);
    } else {
      await prefs.remove('${_kPrefix}fontFileName');
    }
    await prefs.setBool('${_kPrefix}overrideFontFamily', overrideFontFamily);
    await prefs.setBool('${_kPrefix}volumeKeyTurnsPage', volumeKeyTurnsPage);
    await prefs.setInt('${_kPrefix}themeIndex', themeIndex);
    await prefs.setInt('${_kPrefix}customBgColor', customBgColor);
    await prefs.setInt('${_kPrefix}customTextColor', customTextColor);
  }

  static Future<ReaderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReaderSettings(
      zoom: prefs.getDouble('${_kPrefix}zoom') ?? 1.0,
      followAppTheme: prefs.getBool('${_kPrefix}followAppTheme') ?? true,
      marginTop: prefs.getDouble('${_kPrefix}marginTop') ?? 16.0,
      marginBottom: prefs.getDouble('${_kPrefix}marginBottom') ?? 16.0,
      marginLeft: prefs.getDouble('${_kPrefix}marginLeft') ?? 16.0,
      marginRight: prefs.getDouble('${_kPrefix}marginRight') ?? 16.0,
      linkHandling: ReaderLinkHandling.values[
          prefs.getInt('${_kPrefix}linkHandling') ??
              ReaderLinkHandling.ask.index],
      pageAnimation: ReaderPageAnimation.values[
          prefs.getInt('${_kPrefix}pageAnimation') ??
              ReaderPageAnimation.slide.index],
      fontFileName: prefs.getString('${_kPrefix}fontFileName'),
      overrideFontFamily:
          prefs.getBool('${_kPrefix}overrideFontFamily') ?? false,
      volumeKeyTurnsPage:
          prefs.getBool('${_kPrefix}volumeKeyTurnsPage') ?? false,
    );
  }
}

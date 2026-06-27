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
    );
  }

  EpubTheme toEpubTheme(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return EpubTheme(
      zoom: zoom,
      shouldOverrideTextColor: true,
      colorScheme: colorScheme,
      padding: EdgeInsets.only(
        top: marginTop,
        bottom: marginBottom,
        left: marginLeft,
        right: marginRight,
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

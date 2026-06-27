part of '../reader_screen.dart';

mixin _ThemeMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  ReaderRendererController get rendererController;

  ReaderSettings get readerSettings;

  ThemeData? get currentTheme;
  set currentTheme(ThemeData? v);

  bool get updatingTheme;
  set updatingTheme(bool v);

  Timer? get themeUpdateDebouncer;
  set themeUpdateDebouncer(Timer? v);

  EpubTheme getEpubTheme() {
    return readerSettings.toEpubTheme(context);
  }

  void updateWebViewThemeWithDebounce() {
    themeUpdateDebouncer?.cancel();
    themeUpdateDebouncer = Timer(const Duration(milliseconds: 50), () {
      updateWebViewTheme();
    });
  }

  Future<void> updateWebViewTheme() async {
    final newTheme = getEpubTheme();
    final currentWebViewTheme = rendererController.currentTheme;
    if (currentWebViewTheme != null && currentWebViewTheme == newTheme) {
      return;
    }

    setState(() {
      updatingTheme = true;
    });

    await rendererController.updateTheme(getEpubTheme());

    setState(() {
      updatingTheme = false;
    });
  }
}

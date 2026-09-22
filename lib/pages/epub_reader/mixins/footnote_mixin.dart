part of '../reader_screen.dart';

mixin _FootnoteMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  OverlayEntry? get footnoteOverlayEntry;
  set footnoteOverlayEntry(OverlayEntry? v);

  GlobalKey<FootnotePopupOverlayState> get footnoteKey;

  bool get isClosingFootnote;
  set isClosingFootnote(bool v);

  EpubWebViewHandler get webViewHandler;

  BookSession get bookSession;

  ReaderSettings get readerSettings;

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  void handleFootnoteTap(String innerHtml, Rect rect, String baseUrl) {
    removeFootnoteOverlay();
    final overlayState = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    setState(() {
      footnoteOverlayEntry = OverlayEntry(
        builder: (context) => FootnotePopupOverlay(
          key: footnoteKey,
          anchorRect: rect,
          rawHtml: innerHtml,
          onDismiss: () => removeFootnoteOverlay(),
          colorScheme: colorScheme,
          zoom: readerSettings.zoom,
        ),
      );
    });
    overlayState.insert(footnoteOverlayEntry!);
  }

  Future<void> removeFootnoteOverlay() async {
    if (footnoteOverlayEntry == null || isClosingFootnote) return;

    isClosingFootnote = true;
    if (footnoteKey.currentState != null) {
      await footnoteKey.currentState!.playReverseAnimation();
    }

    footnoteOverlayEntry?.remove();
    if (mounted) {
      setState(() {
        footnoteOverlayEntry = null;
        isClosingFootnote = false;
      });
    } else {
      // 动画期间页面已销毁：直接清字段，不能再 setState
      footnoteOverlayEntry = null;
      isClosingFootnote = false;
    }
  }
}

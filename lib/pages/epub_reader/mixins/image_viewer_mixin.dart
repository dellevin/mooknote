part of '../reader_screen.dart';

mixin _ImageViewerMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  BookSession get bookSession;

  bool get showControls;

  bool get isImageViewerVisible;
  set isImageViewerVisible(bool v);

  Uint8List? get currentImageData;
  set currentImageData(Uint8List? v);

  Rect? get currentImageRect;
  set currentImageRect(Rect? v);

  Future<void> handleImageLongPress(String imageUrl, Rect rect) async {
    if (!bookSession.isLoaded) return;
    if (showControls) return;

    // Resolve image bytes from the epub via webViewHandler
    final data = await webViewHandler.resolveImageFromEpub(
      epubPath: bookSession.book['file_path'] as String? ?? '',
      imageUrl: imageUrl,
      fileHash: widget.bookId,
    );
    if (data == null || !mounted) return;

    setState(() {
      currentImageData = data;
      currentImageRect = rect;
      isImageViewerVisible = true;
    });
  }

  void closeImageViewer() {
    setState(() {
      isImageViewerVisible = false;
      currentImageData = null;
      currentImageRect = null;
    });
  }

  // Cross-reference: webViewHandler is defined in _ReaderScreenState
  EpubWebViewHandler get webViewHandler;
}

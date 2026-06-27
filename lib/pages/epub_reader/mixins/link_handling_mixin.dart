part of '../reader_screen.dart';

mixin _LinkHandlingMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  BookSession get bookSession;

  ReaderSettings get readerSettings;

  // === Cross-mixin: _SpineNavigationMixin ===
  Future<void> loadCarousel({
    String anchor = 'top',
    int? overrideSpineIndex,
    double? restoreScrollRatio,
  });

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  bool shouldHandleLinkTap(String url) {
    if (url.startsWith('epub://')) {
      final index = bookSession.findSpineIndexByUrl(url);
      return index != null;
    } else {
      return readerSettings.linkHandling != ReaderLinkHandling.never;
    }
  }

  Future<void> handleLinkTap(String url) async {
    if (url.startsWith('epub://')) {
      final index = bookSession.findSpineIndexByUrl(url);
      if (index != null) {
        String anchor = 'top';
        if (url.contains('#')) {
          anchor = url.split('#').last;
        }
        await loadCarousel(anchor: anchor, overrideSpineIndex: index);
      }
    } else {
      final linkHandling = readerSettings.linkHandling;
      final uri = Uri.tryParse(url);

      if (uri != null && await canLaunchUrl(uri)) {
        if (linkHandling == ReaderLinkHandling.always) {
          await launchUrl(uri);
        } else if (linkHandling == ReaderLinkHandling.ask) {
          if (mounted && context.mounted) {
            final shouldOpen =
                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('打开外部链接'),
                    content: Text('是否打开链接: $url'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('打开'),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (shouldOpen) {
              await launchUrl(uri);
            }
          }
        }
        // ReaderLinkHandling.never: do nothing
      } else {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开链接: $url')),
          );
        }
      }
    }
  }
}

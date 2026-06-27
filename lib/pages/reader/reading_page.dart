import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/reader_book.dart';
import '../../service/book_server.dart';
import '../../utils/reader/book_file_helper.dart';
import '../../widgets/reader/reading_notes_panel.dart';
import 'epub_player.dart';
import 'toc_drawer.dart';
import 'progress_panel.dart';

/// 书籍阅读页面
class ReadingPage extends StatefulWidget {
  final ReaderBook book;

  const ReadingPage({super.key, required this.book});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final GlobalKey<EpubPlayerState> _epubPlayerKey = GlobalKey<EpubPlayerState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _readerFocusNode = FocusNode();

  static const _empty = SizedBox.shrink();
  bool _toolbarOffstage = true;
  Widget _currentPage = const SizedBox.shrink();
  bool _serverReady = false;
  List<TocItem> _toc = [];

  @override
  void initState() {
    super.initState();
    _initServer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readerFocusNode.requestFocus();
    });
  }

  Future<void> _initServer() async {
    String _ = await BookFileHelper.instance.bookFileRoot;
    await Server().start(preferredPort: 0);
    if (mounted) setState(() => _serverReady = true);
  }

  @override
  void dispose() {
    _epubPlayerKey.currentState?.saveReadingProgress();
    Server().stop();
    _readerFocusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showToolbar() => setState(() => _toolbarOffstage = false);

  void _hideToolbar() {
    setState(() {
      _currentPage = _empty;
      _toolbarOffstage = true;
    });
  }

  void _toggleToolbar() => _toolbarOffstage ? _showToolbar() : _hideToolbar();

  void _onTocReady(List<TocItem> toc) {
    if (mounted) setState(() => _toc = toc);
  }

  void _openTocDrawer() {
    _hideToolbar();
    _scaffoldKey.currentState?.openDrawer();
  }

  void _setPanel(Widget panel) {
    setState(() => _currentPage = panel);
  }

  // ─── 键盘快捷键 ──────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      _epubPlayerKey.currentState?.nextPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp) {
      _epubPlayerKey.currentState?.prevPage();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      _toggleToolbar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && !_toolbarOffstage) {
      _hideToolbar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ─── 构建 ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final toolbar = Offstage(
      offstage: _toolbarOffstage,
      child: PointerInterceptor(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideToolbar,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.black.withAlpha(38)),
              ),
            ),
            Column(
              children: [
                AppBar(
                  backgroundColor: colors.surface.withAlpha(240),
                  title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                BottomSheet(
                  onClosing: () {},
                  enableDrag: false,
                  builder: (context) => SafeArea(
                    top: false,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: StatefulBuilder(
                        builder: (BuildContext context, StateSetter modalSetState) {
                          final hasContent = !identical(_currentPage, _empty);
                          return IntrinsicHeight(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasContent)
                                  Expanded(
                                    child: SingleChildScrollView(child: _currentPage),
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.toc),
                                      tooltip: '目录',
                                      onPressed: _openTocDrawer,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note),
                                      tooltip: '笔记',
                                      onPressed: () {
                                        modalSetState(() {
                                          _setPanel(_buildNotesPanel());
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.data_usage),
                                      tooltip: '进度',
                                      onPressed: () {
                                        modalSetState(() {
                                          _setPanel(ProgressPanel(epubPlayerKey: _epubPlayerKey));
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous),
                                      tooltip: '上一章',
                                      onPressed: () {
                                        _epubPlayerKey.currentState?.prevChapter();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next),
                                      tooltip: '下一章',
                                      onPressed: () {
                                        _epubPlayerKey.currentState?.nextChapter();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.surface,
      drawer: PointerInterceptor(
        child: Drawer(
          width: MediaQuery.of(context).size.width * 0.75,
          child: TocDrawer(
            toc: _toc,
            epubPlayerKey: _epubPlayerKey,
          ),
        ),
      ),
      body: _serverReady
          ? Focus(
              focusNode: _readerFocusNode,
              onKeyEvent: _handleKeyEvent,
              autofocus: true,
              child: Stack(
                children: [
                  EpubPlayer(
                    key: _epubPlayerKey,
                    book: widget.book,
                    showOrHideToolbar: _toggleToolbar,
                    onTocReady: _onTocReady,
                  ),
                  toolbar,
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotesPanel() {
    return ReadingNotesPanel(
      bookId: widget.book.id,
      onNavigate: (cfi) {
        _hideToolbar();
        _epubPlayerKey.currentState?.goToCfi(cfi);
      },
    );
  }
}

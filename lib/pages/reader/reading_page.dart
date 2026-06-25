import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/reader_book.dart';
import '../../service/book_server.dart';
import '../../utils/reader/book_file_helper.dart';
import 'epub_player.dart';
import 'toc_drawer.dart';
import 'progress_panel.dart';
import 'style_panel.dart';

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

  static const _empty = SizedBox.shrink();
  bool _toolbarOffstage = true; // true=隐藏, false=显示
  Widget _currentPage = const SizedBox.shrink();
  bool _serverReady = false;

  List<TocItem> _toc = [];

  @override
  void initState() {
    super.initState();
    _initServer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showToolbar() {
    setState(() {
      _toolbarOffstage = false;
    });
  }

  void _hideToolbar() {
    setState(() {
      _currentPage = _empty;
      _toolbarOffstage = true;
    });
  }

  void _toggleToolbar() {
    if (_toolbarOffstage) {
      _showToolbar();
    } else {
      _hideToolbar();
    }
  }

  void _onTocReady(List<TocItem> toc) {
    if (mounted) setState(() => _toc = toc);
  }

  void _openTocDrawer() {
    _hideToolbar();
    _scaffoldKey.currentState?.openDrawer();
  }

  // ─── 底部面板切换 ─────────────────────────────────────

  void _onProgressPressed() {
    setState(() {
      _currentPage = ProgressPanel(epubPlayerKey: _epubPlayerKey);
    });
  }

  void _onStylePressed() {
    setState(() {
      _currentPage = StylePanel(epubPlayerKey: _epubPlayerKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // ─── 工具栏覆盖层（照抄 anx-reader 的 Offstage + PointerInterceptor 模式）
    Offstage controller = Offstage(
      offstage: _toolbarOffstage,
      child: PointerInterceptor(
        child: Stack(
          children: [
            // 半透明背景，点击关闭工具栏
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideToolbar,
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {},
                onVerticalDragEnd: (details) {},
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                ),
              ),
            ),
            // 顶部 AppBar + 底部工具栏
            Column(
              children: [
                // 顶部 AppBar
                AppBar(
                  backgroundColor: colors.surface.withValues(alpha: 0.94),
                  title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                // 底部面板 + 按钮行
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
                                // 面板内容区域
                                if (hasContent)
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: _currentPage,
                                    ),
                                  ),
                                // 按钮行
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.toc),
                                      tooltip: '目录',
                                      onPressed: _openTocDrawer,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.data_usage),
                                      tooltip: '进度',
                                      onPressed: () {
                                        modalSetState(() {
                                          _onProgressPressed();
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.color_lens),
                                      tooltip: '样式',
                                      onPressed: () {
                                        modalSetState(() {
                                          _onStylePressed();
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
      // TOC 目录抽屉
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
          ? Stack(
              children: [
                // 阅读内容（WebView）
                EpubPlayer(
                  key: _epubPlayerKey,
                  book: widget.book,
                  showOrHideToolbar: _toggleToolbar,
                  onTocReady: _onTocReady,
                ),
                // 工具栏覆盖层
                controller,
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../main.dart';
import '../utils/image_path_helper.dart';

class VditorEditor extends StatefulWidget {
  final String? initialContent;
  final String noteId;
  final bool isDark;
  final Color surfaceColor;
  final ValueChanged<String>? onContentChanged;
  final ValueChanged<double>? onHeightChanged;
  final String placeholder;

  const VditorEditor({
    super.key,
    this.initialContent,
    required this.noteId,
    this.isDark = false,
    this.surfaceColor = Colors.white,
    this.onContentChanged,
    this.onHeightChanged,
    this.placeholder = '使用 Markdown 格式书写...',
  });

  @override
  State<VditorEditor> createState() => VditorEditorState();
}

class VditorEditorState extends State<VditorEditor> {
  InAppWebViewController? _controller;
  bool _isReady = false;
  bool _loadFailed = false;
  late final TextEditingController _fallbackController;
  String? _distDir; // Windows: 文件系统路径
  double _contentHeight = 200; // WebView 内容高度，随内容撑开
  double _lastKeyboardH = 0; // 上次键盘高度，用于检测键盘弹出
  final Completer<void> _readyCompleter = Completer<void>();
  Timer? _fallbackTimer;

  Future<void> get ready => _readyCompleter.future;
  bool get isReady => _isReady;

  @override
  void initState() {
    super.initState();
    _fallbackController = TextEditingController(text: widget.initialContent ?? '');
    _startFallbackTimer();
    if (Platform.isWindows) {
      _locateDistDir();
    } else {
      // Android/iOS: 直接从 asset 加载，无需定位文件系统路径
      if (mounted) setState(() {});
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer = Timer(const Duration(seconds: 15), () {
      if (!_isReady && mounted) {
        setState(() => _loadFailed = true);
      }
    });
  }

  /// 定位 vditor_dist 目录（Windows 构建时由 CMakeLists 复制到 data/ 下）
  Future<void> _locateDistDir() async {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final candidate = p.join(exeDir, 'data', 'vditor_dist');
      if (await File(p.join(candidate, 'vditor_editor.html')).exists()) {
        _distDir = candidate;
        if (mounted) setState(() {});
        return;
      }
      debugPrint('[VditorEditor] vditor_dist not found at $candidate');
      if (mounted) setState(() => _loadFailed = true);
    } catch (e) {
      debugPrint('[VditorEditor] locateDistDir error: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _fallbackController.dispose();
    _destroyVditor();
    super.dispose();
  }

  Future<void> _destroyVditor() async {
    if (_controller != null) {
      try {
        await _controller!.evaluateJavascript(source: 'destroy()');
      } catch (_) {}
    }
  }

  Future<String> getValue() async {
    if (_controller == null || !_isReady) return widget.initialContent ?? '';
    try {
      final result = await _controller!.evaluateJavascript(source: 'getValue()');
      return result?.toString() ?? '';
    } catch (_) {
      return widget.initialContent ?? '';
    }
  }

  Future<void> setValue(String text) async {
    if (_controller == null || !_isReady) return;
    try {
      final escaped = jsonEncode(text);
      await _controller!.evaluateJavascript(source: 'setValue($escaped)');
    } catch (_) {}
  }

  Future<void> setTheme(bool isDark) async {
    if (_controller == null || !_isReady) return;
    final theme = isDark ? 'dark' : 'light';
    try {
      await _controller!.evaluateJavascript(source: 'setTheme("$theme")');
    } catch (_) {}
  }

  Future<void> setBgColor(String hexColor) async {
    if (_controller == null || !_isReady) return;
    try {
      final escaped = jsonEncode(hexColor);
      await _controller!.evaluateJavascript(source: 'setBgColor($escaped)');
    } catch (_) {}
  }

  Future<void> insertValue(String text) async {
    if (_controller == null || !_isReady) return;
    try {
      final escaped = jsonEncode(text);
      await _controller!.evaluateJavascript(source: 'insertValue($escaped)');
    } catch (_) {}
  }

  Future<void> _scrollToCursor() async {
    if (_controller == null || !_isReady) return;
    try {
      // 延迟一帧让键盘动画完成
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.evaluateJavascript(source: 'scrollToCursor()');
    } catch (_) {}
  }

  Future<void> _requestHeightUpdate() async {
    if (_controller == null || !_isReady) return;
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.evaluateJavascript(source: 'requestHeightUpdate()');
    } catch (_) {}
  }

  void _onVditorReady() {
    if (_isReady) return;
    _fallbackTimer?.cancel();
    _isReady = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      setValue(widget.initialContent!);
    }
    setBgColor(_colorToHex(widget.surfaceColor));
  }

  @override
  void didUpdateWidget(covariant VditorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.surfaceColor != oldWidget.surfaceColor) {
      setBgColor(_colorToHex(widget.surfaceColor));
    }
  }

  static String _colorToHex(Color color) {
    return '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetDir = await ImagePathHelper.instance.getNoteImagesDir(widget.noteId);
      await ImagePathHelper.instance.ensureDirExists(targetDir);
      final targetPath = p.join(targetDir, fileName);
      await File(image.path).copy(targetPath);
      final mdPath = targetPath.replaceAll('\\', '/');
      if (mounted) await insertValue('![]($mdPath)');
    } catch (e) {
      debugPrint('[VditorEditor] pickImage error: $e');
    }
  }

  Future<void> _handleImageUpload(String base64Data, String fileName, String mimeType) async {
    try {
      final targetDir = await ImagePathHelper.instance.getNoteImagesDir(widget.noteId);
      await ImagePathHelper.instance.ensureDirExists(targetDir);
      final base64Str = base64Data.contains(',') ? base64Data.split(',')[1] : base64Data;
      final bytes = base64Decode(base64Str);
      final ext = mimeType.contains('png') ? 'png' : 'jpg';
      final savedName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final targetPath = p.join(targetDir, savedName);
      await File(targetPath).writeAsBytes(bytes);
      final mdPath = targetPath.replaceAll('\\', '/');
      if (mounted) await insertValue('![]($mdPath)');
    } catch (e) {
      debugPrint('[VditorEditor] handleImageUpload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loadFailed) {
      return TextField(
        controller: _fallbackController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.6, fontSize: 14),
        style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25), height: 1.6),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: widget.onContentChanged,
      );
    }

    // Windows: 等待 dist 目录定位完成
    if (Platform.isWindows && _distDir == null) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary));
    }

    // Windows: WebView 环境未初始化时，直接 fallback 到纯文本编辑
    if (Platform.isWindows && windowsWebViewEnvironment == null) {
      _loadFailed = true;
      return TextField(
        controller: _fallbackController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.6, fontSize: 14),
        style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25), height: 1.6),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: widget.onContentChanged,
      );
    }

    final String initialUrl;
    if (Platform.isWindows) {
      final htmlPath = p.join(_distDir!, 'vditor_editor.html');
      initialUrl = 'file:///${htmlPath.replaceAll('\\', '/')}';
    } else {
      // Android: 直接访问 APK 内 asset，相对路径自动解析
      initialUrl = 'file:///android_asset/flutter_assets/assets/vditor/dist/vditor_editor.html';
    }
    debugPrint('[VditorEditor] loading: $initialUrl');

    // 键盘弹出时，滚动到光标位置；键盘收起时，重新通知高度
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    if (keyboardH > 0 && _lastKeyboardH == 0 && _isReady) {
      Future.microtask(() => _scrollToCursor());
    } else if (keyboardH == 0 && _lastKeyboardH > 0 && _isReady) {
      // 键盘收起，请求 JS 端重新计算高度
      Future.microtask(() => _requestHeightUpdate());
    }
    _lastKeyboardH = keyboardH;

    // Windows 桌面端：WebView 填满父容器，自身管理内部滚动
    // 移动端：使用 _contentHeight 动态撑开，配合 onHeightChanged 回调
    if (Platform.isWindows) {
      return Stack(
        children: [
          InAppWebView(
            webViewEnvironment: windowsWebViewEnvironment,
            initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              transparentBackground: true,
              disableContextMenu: false,
              useHybridComposition: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              controller.addJavaScriptHandler(
                handlerName: 'onVditorReady',
                callback: (_) => _onVditorReady(),
              );
              controller.addJavaScriptHandler(
                handlerName: 'onContentChanged',
                callback: (args) {
                  if (args.isNotEmpty) {
                    widget.onContentChanged?.call(args[0].toString());
                  }
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'onPickImage',
                callback: (_) => _pickImage(),
              );
              controller.addJavaScriptHandler(
                handlerName: 'onImageUpload',
                callback: (args) {
                  if (args.length >= 3) {
                    _handleImageUpload(args[0].toString(), args[1].toString(), args[2].toString());
                  }
                },
              );
              controller.addJavaScriptHandler(
                handlerName: 'onHeightChanged',
                callback: (args) {
                  if (args.isNotEmpty) {
                    final h = double.tryParse(args[0].toString()) ?? _contentHeight;
                    if ((h - _contentHeight).abs() > 2 && h > 0) {
                      setState(() => _contentHeight = h);
                      widget.onHeightChanged?.call(h);
                    }
                  }
                },
              );
            },
            onLoadStop: (controller, url) async {
              final theme = widget.isDark ? 'dark' : 'light';
              final escapedPlaceholder = jsonEncode(widget.placeholder);
              await controller.evaluateJavascript(
                source: 'initVditor("$theme", $escapedPlaceholder)',
              );
            },
            onReceivedError: (controller, request, error) {
              debugPrint('[VditorEditor] load error: ${error.description}');
            },
          ),
          // 加载动画：Vditor 就绪前显示
          if (!_isReady)
            Container(
              color: colors.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '编辑器加载中...',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return SizedBox(
      height: _contentHeight,
      child: Stack(
        children: [
          Container(
            color: colors.surface,
            child: InAppWebView(
              webViewEnvironment: Platform.isWindows ? windowsWebViewEnvironment : null,
              initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                disableContextMenu: false,
                useHybridComposition: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'onVditorReady',
                  callback: (_) => _onVditorReady(),
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onContentChanged',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      widget.onContentChanged?.call(args[0].toString());
                    }
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onPickImage',
                  callback: (_) => _pickImage(),
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onImageUpload',
                  callback: (args) {
                    if (args.length >= 3) {
                      _handleImageUpload(args[0].toString(), args[1].toString(), args[2].toString());
                    }
                  },
                );
                controller.addJavaScriptHandler(
                  handlerName: 'onHeightChanged',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      final h = double.tryParse(args[0].toString()) ?? _contentHeight;
                      if ((h - _contentHeight).abs() > 2 && h > 0) {
                        setState(() => _contentHeight = h);
                        widget.onHeightChanged?.call(h);
                      }
                    }
                  },
                );
              },
              onLoadStop: (controller, url) async {
                final theme = widget.isDark ? 'dark' : 'light';
                final escapedPlaceholder = jsonEncode(widget.placeholder);
                await controller.evaluateJavascript(
                  source: 'initVditor("$theme", $escapedPlaceholder)',
                );
              },
              onReceivedError: (controller, request, error) {
                debugPrint('[VditorEditor] load error: ${error.description}');
              },
            ),
          ),
          // 加载动画：Vditor 就绪前显示
          if (!_isReady)
            Container(
              color: colors.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '编辑器加载中...',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

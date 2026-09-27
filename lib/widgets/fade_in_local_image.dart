import 'dart:io';
import 'package:flutter/material.dart';

/// 带淡入动画的图片组件（支持本地文件 + HTTP URL）
class FadeInLocalImage extends StatefulWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration duration;

  const FadeInLocalImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<FadeInLocalImage> createState() => _FadeInLocalImageState();
}

class _FadeInLocalImageState extends State<FadeInLocalImage>
    with SingleTickerProviderStateMixin {
  /// 本次会话已成功显示过的路径：再次显示时直接出图，
  /// 不再重复走 异步检查+淡入（否则 Hero 转场时详情页海报会"迟到"）
  static final Set<String> _shownPaths = {};

  /// 上限保护：长时间浏览大量不同图片后整体清空，避免无界增长
  static void _rememberShown(String path) {
    if (_shownPaths.length > 1000) _shownPaths.clear();
    _shownPaths.add(path);
  }

  late AnimationController _controller;
  late Animation<double> _opacity;
  bool _loaded = false;
  bool _error = false;
  String? _imageUrl;
  bool _useNetwork = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    final p = widget.path;
    if (p != null && _shownPaths.contains(p)) {
      _loaded = true;
      if (p.startsWith('http')) {
        _useNetwork = true;
        _imageUrl = p;
      }
      _controller.value = 1.0;
      return;
    }
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (widget.path == null || widget.path!.isEmpty) {
      setState(() => _error = true);
      return;
    }

    if (widget.path!.startsWith('http')) {
      _useNetwork = true;
      _imageUrl = widget.path;
      _rememberShown(widget.path!);
      setState(() => _loaded = true);
      _controller.forward();
      return;
    }

    final file = File(widget.path!);
    final exists = await file.exists();
    if (!mounted) return;
    if (exists) {
      _rememberShown(widget.path!);
      setState(() => _loaded = true);
      _controller.forward();
      return;
    }

    if (mounted) setState(() => _error = true);
  }

  @override
  void didUpdateWidget(FadeInLocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _error = false;
      _loaded = false;
      _useNetwork = false;
      _imageUrl = null;
      _controller.reset();
      _loadImage();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_error) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)),
          );
    }
    if (!_loaded) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: colors.surfaceContainerHighest,
          );
    }
    return FadeTransition(
      opacity: _opacity,
      // 按显示尺寸 × dpr 限制解码尺寸：原图（如 4000×6000）全尺寸解码可达 ~96MB，
      // 列表快速滚动时有 OOM 风险。未显式给宽高时取父级约束。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final w = widget.width ??
              (constraints.hasBoundedWidth ? constraints.maxWidth : null);
          final h = widget.height ??
              (constraints.hasBoundedHeight ? constraints.maxHeight : null);
          final cacheW = (w != null && w.isFinite && w > 0)
              ? (w * dpr).round()
              : null;
          final cacheH = (h != null && h.isFinite && h > 0)
              ? (h * dpr).round()
              : null;
          return _useNetwork
              ? Image.network(
                  _imageUrl!,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  cacheWidth: cacheW,
                  cacheHeight: cacheH,
                  errorBuilder: (_, e, __) {
                    debugPrint('[Image] 网络加载失败: $_imageUrl, 错误: $e');
                    return widget.errorWidget ??
                        Container(
                          width: widget.width,
                          height: widget.height,
                          color: colors.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)),
                        );
                  },
                )
              : Image.file(
                  File(widget.path!),
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit,
                  cacheWidth: cacheW,
                  cacheHeight: cacheH,
                  errorBuilder: (_, __, ___) => widget.errorWidget ??
                      Container(
                        width: widget.width,
                        height: widget.height,
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)),
                      ),
                );
        },
      ),
    );
  }
}

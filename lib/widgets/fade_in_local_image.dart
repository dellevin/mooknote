import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/sync/server_data_service.dart';

/// 带淡入动画的图片组件（支持本地文件 + 服务端 URL 回退）
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
      setState(() => _loaded = true);
      _controller.forward();
      return;
    }

    final file = File(widget.path!);
    if (file.existsSync()) {
      setState(() => _loaded = true);
      _controller.forward();
      return;
    }

    if (ServerDataService.isActive) {
      try {
        final url = await ServerDataService.toImageUrl(widget.path!);
        debugPrint('[Image] 本地不存在，使用服务端: $url');
        _useNetwork = true;
        _imageUrl = url;
        setState(() => _loaded = true);
        _controller.forward();
        return;
      } catch (_) {}
    }

    setState(() => _error = true);
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
      child: _useNetwork
          ? Image.network(
              _imageUrl!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
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
              errorBuilder: (_, __, ___) => widget.errorWidget ??
                  Container(
                    width: widget.width,
                    height: widget.height,
                    color: colors.surfaceContainerHighest,
                    child: Icon(Icons.broken_image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)),
                  ),
            ),
    );
  }
}

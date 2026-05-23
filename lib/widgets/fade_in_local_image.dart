import 'dart:io';
import 'package:flutter/material.dart';

/// 带淡入动画的本地图片组件
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _checkFile();
  }

  void _checkFile() {
    if (widget.path == null || widget.path!.isEmpty) {
      setState(() => _error = true);
      return;
    }
    final file = File(widget.path!);
    if (!file.existsSync()) {
      setState(() => _error = true);
      return;
    }
    setState(() => _loaded = true);
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeInLocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _error = false;
      _loaded = false;
      _controller.reset();
      _checkFile();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFFF5F5F5),
            child: const Icon(Icons.broken_image_outlined, size: 24, color: Color(0xFFCCCCCC)),
          );
    }
    if (!_loaded) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFFF5F5F5),
          );
    }
    return FadeTransition(
      opacity: _opacity,
      child: Image.file(
        File(widget.path!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: const Color(0xFFF5F5F5),
              child: const Icon(Icons.broken_image_outlined, size: 24, color: Color(0xFFCCCCCC)),
            ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageViewer extends StatefulWidget {
  final Uint8List imageData;
  final VoidCallback onClose;
  final Rect sourceRect;
  final ColorScheme colorScheme;

  const ImageViewer({
    super.key,
    required this.imageData,
    required this.onClose,
    required this.sourceRect,
    required this.colorScheme,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  double? _imageAspectRatio;
  bool _isLoading = true;
  bool _isClosing = false;

  final TransformationController _transformController =
      TransformationController();
  Rect? _dynamicCloseRect;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);

    _resolveImage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _resolveImage() {
    final imageProvider = MemoryImage(widget.imageData);
    final imageStream = imageProvider.resolve(const ImageConfiguration());

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.width / info.image.height;
            _isLoading = false;
          });
          _triggerAnimation();
        }
        imageStream.removeListener(listener);
      },
      onError: (dynamic error, StackTrace? stackTrace) {
        debugPrint('Error resolving image info: $error');
        imageStream.removeListener(listener);
        _handleLoadError();
      },
    );

    imageStream.addListener(listener);
  }

  void _triggerAnimation() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 10), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  Future<void> _handleClose() async {
    if (_isClosing) return;

    final Size screenSize = MediaQuery.of(context).size;
    final Matrix4 matrix = _transformController.value;
    final double scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    setState(() {
      _isClosing = true;
      _dynamicCloseRect = Rect.fromLTWH(
        translation.x,
        translation.y,
        screenSize.width * scale,
        screenSize.height * scale,
      );
      _transformController.value = Matrix4.identity();
    });

    await _controller.reverse();

    if (mounted) {
      widget.onClose();
    }
  }

  void _handleLoadError() {
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load image')),
      );
      _handleClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final Rect fullscreenRect = Rect.fromLTWH(
      0,
      0,
      screenSize.width,
      screenSize.height,
    );
    final Rect targetEndRect = _dynamicCloseRect ?? fullscreenRect;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleClose();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double t = _curve.value;
          final Rect currentRect = Rect.lerp(
            widget.sourceRect,
            targetEndRect,
            t,
          )!;

          final bool isExpanded = t == 1.0;
          final bool canZoom = isExpanded && !_isLoading;

          final double bgOpacity = 0.9 * t;

          return Stack(
            children: [
              GestureDetector(
                onTap: _handleClose,
                child: Container(
                  color: widget.colorScheme.scrim.withValues(alpha: bgOpacity),
                ),
              ),
              Positioned.fromRect(
                rect: currentRect,
                child: GestureDetector(
                  onTap: _handleClose,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: canZoom
                        ? _buildInteractiveViewer()
                        : Opacity(opacity: t, child: _buildStaticImage()),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageView(double t) {
    if (_imageAspectRatio == null) {
      return const SizedBox();
    }
    final curve = Curves.easeOutQuart.transform(t);
    final backgroundColor = Colors.white.withValues(alpha: curve);

    return Center(
      child: AspectRatio(
        aspectRatio: _imageAspectRatio!,
        child: Container(
          color: backgroundColor,
          child: Image.memory(
            widget.imageData,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveViewer() {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(child: _buildImageView(_controller.value)),
    );
  }

  Widget _buildStaticImage() {
    if (_isLoading) {
      return const SizedBox();
    }
    return SizedBox.expand(child: _buildImageView(_controller.value));
  }
}

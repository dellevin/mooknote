import 'package:flutter/material.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';

/// 游戏截图画廊页面 - 支持左右滑动浏览
class ScreenshotGalleryPage extends StatefulWidget {
  final List<GameScreenshot> screenshots;
  final int initialIndex;

  const ScreenshotGalleryPage({super.key, required this.screenshots, required this.initialIndex});

  @override
  State<ScreenshotGalleryPage> createState() => _ScreenshotGalleryPageState();
}

class _ScreenshotGalleryPageState extends State<ScreenshotGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.screenshots.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final screenshot = widget.screenshots[index];
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Center(
                  child: FadeInLocalImage(path: screenshot.screenshotPath, fit: BoxFit.contain),
                ),
              );
            },
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                    const Spacer(),
                    Text('${_currentIndex + 1} / ${widget.screenshots.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          if (widget.screenshots.length > 1)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.screenshots.length,
                    (index) => Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex ? Colors.white : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

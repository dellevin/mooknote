import 'package:flutter/material.dart';

/// Toast 工具类（带滑入+淡入动画）
class ToastUtil {
  static OverlayEntry? _currentToast;

  /// 显示 Toast
  static void show(BuildContext context, String message) {
    // 移除之前的 Toast
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AnimatedToast(
        message: message,
        onDismiss: () {
          if (_currentToast == entry) {
            entry.remove();
            _currentToast = null;
          }
        },
      ),
    );
    _currentToast = entry;

    overlay.insert(entry);

    // 2秒后自动消失
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentToast == entry) {
        entry.remove();
        _currentToast = null;
      }
    });
  }
}

/// 带动画的 Toast 内容
class _AnimatedToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedToast({required this.message, required this.onDismiss});

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    // 消失前淡出
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) _ctrl.reverse();
    });
  }

  /// 点击手动关闭：淡出动画结束后移除
  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 96,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth > 480 ? 480 : screenWidth * 0.85,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

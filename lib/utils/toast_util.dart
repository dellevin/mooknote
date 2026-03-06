import 'package:flutter/material.dart';

/// Toast 工具类
class ToastUtil {
  static OverlayEntry? _currentToast;

  /// 显示 Toast
  static void show(BuildContext context, String message) {
    // 移除之前的 Toast
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);
    _currentToast = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_currentToast!);

    // 2秒后自动消失
    Future.delayed(const Duration(seconds: 2), () {
      _currentToast?.remove();
      _currentToast = null;
    });
  }
}

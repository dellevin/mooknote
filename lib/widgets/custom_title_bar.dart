import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  static const double height = 32.0;

  @override
  State<CustomTitleBar> createState() => CustomTitleBarState();
}

class CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  Future<void> _checkMaximized() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) setState(() {});
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: CustomTitleBar.height,
        color: colors.surface,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Image.asset('assets/icon/app_icon.webp', width: 16, height: 16),
            const SizedBox(width: 8),
            Text(
              'MookNote',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            _WindowButton(
              icon: Icons.remove,
              size: 18,
              onTap: () => windowManager.minimize(),
            ),
            _WindowButton(
              icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
              size: 14,
              onTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: Icons.close,
              size: 18,
              onTap: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    this.size = 16,
    required this.onTap,
    this.isClose = false,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    if (widget.isClose && _hovering) {
      bg = const Color(0xFFE81123);
      fg = Colors.white;
    } else if (_hovering) {
      bg = colors.onSurface.withValues(alpha: 0.08);
      fg = colors.onSurface;
    } else {
      bg = Colors.transparent;
      fg = colors.onSurface.withValues(alpha: 0.7);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Container(
          width: 46,
          height: CustomTitleBar.height,
          color: bg,
          child: Icon(widget.icon, size: widget.size, color: fg),
        ),
      ),
    );
  }
}

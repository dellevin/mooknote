import 'dart:async';
import 'package:flutter/material.dart';
import 'epub_player.dart';

/// 进度控制面板 — 滑块跳转 + 章节信息
class ProgressPanel extends StatefulWidget {
  final GlobalKey<EpubPlayerState> epubPlayerKey;

  const ProgressPanel({super.key, required this.epubPlayerKey});

  @override
  State<ProgressPanel> createState() => _ProgressPanelState();
}

class _ProgressPanelState extends State<ProgressPanel> {
  double _sliderValue = 0.0;
  Timer? _debounceTimer;

  EpubPlayerState? get _player => widget.epubPlayerKey.currentState;

  @override
  void initState() {
    super.initState();
    _sliderValue = _player?.percentage ?? 0.0;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final player = _player;
    final chapterTitle = player?.chapterTitle ?? '';
    final currentPage = player?.chapterCurrentPage ?? 0;
    final totalPages = player?.chapterTotalPages ?? 0;
    final percent = player?.percentage ?? 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 章节标题
          if (chapterTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
              ),
            ),
          // 滑块行
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _player?.prevChapter(),
              ),
              Expanded(
                child: Slider(
                  value: _sliderValue.clamp(0.0, 1.0),
                  onChanged: (value) {
                    setState(() => _sliderValue = value);
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
                      _player?.goToPercentage(value);
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _player?.nextChapter(),
              ),
            ],
          ),
          // 页码和百分比
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoItem('$currentPage', '当前页', colors),
                _infoItem('$totalPages', '总页数', colors),
                _infoItem('${(percent * 100).toStringAsFixed(1)}%', '进度', colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(String value, String label, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
      ],
    );
  }
}

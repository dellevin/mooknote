import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import 'screenshot_gallery_page.dart';

/// 游戏截图页面
class GameScreenshotsPage extends StatefulWidget {
  final Game game;

  const GameScreenshotsPage({super.key, required this.game});

  @override
  State<GameScreenshotsPage> createState() => _GameScreenshotsPageState();
}

class _GameScreenshotsPageState extends State<GameScreenshotsPage> {
  final ImagePicker _picker = ImagePicker();
  List<GameScreenshot> _screenshots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScreenshots();
  }

  Future<void> _loadScreenshots() async {
    setState(() => _isLoading = true);
    final screenshots = await context.read<AppProvider>().getGameScreenshots(widget.game.id);
    setState(() {
      _screenshots = screenshots;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('游戏截图')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickScreenshot,
        icon: const Icon(Icons.add_photo_alternate, size: 20),
        label: const Text('添加截图'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screenshots.isEmpty
              ? _buildEmptyState()
              : _buildScreenshotGrid(),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.photo_library_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          Text('暂无截图', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScreenshotGrid() {
    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _screenshots.length,
      itemBuilder: (context, index) {
        final screenshot = _screenshots[index];
        return _buildScreenshotItem(screenshot, index);
      },
    );
  }

  Widget _buildScreenshotItem(GameScreenshot screenshot, int index) {
    final heights = [180.0, 220.0, 160.0, 200.0, 240.0, 190.0];
    final height = heights[index % heights.length];

    return GestureDetector(
      onTap: () => _showScreenshotDetail(screenshot),
      onLongPress: () => _showDeleteDialog(screenshot),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FadeInLocalImage(path: screenshot.screenshotPath, fit: BoxFit.cover),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScreenshotDetail(GameScreenshot screenshot) {
    final initialIndex = _screenshots.indexWhere((s) => s.id == screenshot.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScreenshotGalleryPage(
          screenshots: _screenshots,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.outline, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(children: [
                      Text('添加截图', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _buildAddOption(colors: colors, icon: Icons.photo_library_outlined, title: '从相册选择', subtitle: '选择本地图片', onTap: () => Navigator.pop(context, 0)),
                  _buildAddOption(colors: colors, icon: Icons.link_outlined, title: '网络链接', subtitle: '输入图片URL地址', onTap: () => Navigator.pop(context, 1)),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == null) return;
    if (result == 0) {
      await _pickFromGallery();
    } else if (result == 1) {
      await _pickFromUrl();
    }
  }

  Widget _buildAddOption({required ColorScheme colors, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 22, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200, maxHeight: 1800, imageQuality: 85,
      );
      if (pickedFile != null) {
        final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final targetPath = await ImagePathHelper.instance.getGameScreenshotImgPath(widget.game.id, fileName);
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        await File(pickedFile.path).copy(targetPath);

        final newScreenshot = GameScreenshot(
          id: const Uuid().v4(),
          gameId: widget.game.id,
          screenshotPath: targetPath,
          createdAt: DateTime.now(),
        );
        await context.read<AppProvider>().addGameScreenshot(newScreenshot);
        _loadScreenshots();
        if (mounted) ToastUtil.show(context, '添加成功');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '添加截图失败: $e');
    }
  }

  Future<void> _pickFromUrl() async {
    final urlController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('添加网络图片'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请输入图片链接地址', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                  border: const UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.outline)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.primary)),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('确定', style: TextStyle(color: colors.onSurface))),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final url = urlController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      urlController.dispose();
    });
    if (url.isEmpty) { if (mounted) ToastUtil.show(context, '请输入图片链接'); return; }

    try {
      await _downloadAndSaveScreenshot(url);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '添加失败: $e');
    }
  }

  Future<void> _downloadAndSaveScreenshot(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );
      if (response.statusCode != 200) throw Exception('下载失败: HTTP ${response.statusCode}');
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');

      final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getGameScreenshotImgPath(widget.game.id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);

      final newScreenshot = GameScreenshot(
        id: const Uuid().v4(),
        gameId: widget.game.id,
        screenshotPath: targetPath,
        createdAt: DateTime.now(),
      );
      await context.read<AppProvider>().addGameScreenshot(newScreenshot);
      _loadScreenshots();
      if (mounted) ToastUtil.show(context, '添加成功');
    } catch (e) {
      throw Exception('下载图片失败: $e');
    }
  }

  void _showDeleteDialog(GameScreenshot screenshot) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('确定要删除这张截图吗？',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(
              onPressed: () async {
                await context.read<AppProvider>().removeGameScreenshot(screenshot.id);
                Navigator.pop(context);
                _loadScreenshots();
                ToastUtil.show(context, '已删除');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('删除'),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
}

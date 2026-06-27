import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../utils/epub/reader_dao.dart';
import '../../widgets/text_input_panel.dart';

/// EPUB 书籍编辑页
class EpubEditPage extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> book;

  const EpubEditPage({
    super.key,
    required this.bookId,
    required this.book,
  });

  @override
  State<EpubEditPage> createState() => _EpubEditPageState();
}

class _EpubEditPageState extends State<EpubEditPage> {
  final ReaderDao _dao = ReaderDao();

  late TextEditingController _titleCtrl;
  late TextEditingController _authorCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.book['title'] as String? ?? '');
    _authorCtrl = TextEditingController(text: widget.book['author'] as String? ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty) return;
    await _dao.updateReaderBook(widget.bookId, {
      'title': newTitle,
      'author': _authorCtrl.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory(p.join(appDir.path, 'epub_books', widget.bookId));
    if (!await bookDir.exists()) await bookDir.create(recursive: true);

    final existing = bookDir.listSync().whereType<File>().where((f) {
      final name = p.basenameWithoutExtension(f.path);
      return name.startsWith('cover_') && RegExp(r'^cover_\d+$').hasMatch(name);
    }).toList();
    int nextIndex = 1;
    if (existing.isNotEmpty) {
      final indices = existing.map((f) {
        return int.tryParse(p.basenameWithoutExtension(f.path).substring(6)) ?? 0;
      }).toList();
      indices.sort();
      nextIndex = indices.last + 1;
    }

    final ext = p.extension(picked.path).toLowerCase();
    final destPath = p.join(bookDir.path, 'cover_$nextIndex$ext');
    await File(picked.path).copy(destPath);

    await _dao.updateReaderBook(widget.bookId, {
      'cover_path': destPath,
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _revertCover() async {
    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory(p.join(appDir.path, 'epub_books', widget.bookId));

    final existing = bookDir.listSync().whereType<File>().where((f) {
      final name = p.basenameWithoutExtension(f.path);
      return name.startsWith('cover_') && RegExp(r'^cover_\d+$').hasMatch(name);
    }).toList();

    if (existing.isEmpty) return;

    existing.sort((a, b) {
      final ia = int.tryParse(p.basenameWithoutExtension(a.path).substring(6)) ?? 0;
      final ib = int.tryParse(p.basenameWithoutExtension(b.path).substring(6)) ?? 0;
      return ia.compareTo(ib);
    });
    final currentMax = existing.last;
    final currentIndex = int.tryParse(p.basenameWithoutExtension(currentMax.path).substring(6)) ?? 0;
    await currentMax.delete();

    if (currentIndex <= 1) {
      final coverFile = bookDir.listSync().whereType<File>().where((f) {
        final name = p.basenameWithoutExtension(f.path);
        return name == 'cover';
      }).firstOrNull;
      await _dao.updateReaderBook(widget.bookId, {
        'cover_path': coverFile?.path ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      final prev = existing.where((f) {
        final idx = int.tryParse(p.basenameWithoutExtension(f.path).substring(6)) ?? 0;
        return idx == currentIndex - 1;
      }).firstOrNull;
      await _dao.updateReaderBook(widget.bookId, {
        'cover_path': prev?.path ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final coverPath = widget.book['cover_path'] as String?;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('编辑书籍信息',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.close, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('保存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 封面选择
          Center(child: _buildCoverPicker(coverPath, colors)),
          const SizedBox(height: 24),
          // 信息卡片
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (MediaQuery.of(context).size.width - 52) / 2,
                height: 90,
                child: _buildInfoCard(
                  label: '标题',
                  value: _titleCtrl.text,
                  required: true,
                  icon: Icons.auto_stories_outlined,
                  onTap: () async {
                    final result = await TextInputPanel.show(
                      context: context,
                      title: '书名',
                      initialValue: _titleCtrl.text,
                      hint: '请输入书名',
                    );
                    if (result != null) setState(() => _titleCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
              SizedBox(
                width: (MediaQuery.of(context).size.width - 52) / 2,
                height: 90,
                child: _buildInfoCard(
                  label: '作者',
                  value: _authorCtrl.text,
                  icon: Icons.person_outline,
                  onTap: () async {
                    final result = await TextInputPanel.show(
                      context: context,
                      title: '作者',
                      initialValue: _authorCtrl.text,
                      hint: '请输入作者',
                    );
                    if (result != null) setState(() => _authorCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 封面操作
          Text('封面操作',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildActionCard(
              icon: Icons.add_photo_alternate_outlined, title: '更换封面', subtitle: '从相册选择',
              color: colors.primary,
              onTap: _pickCover,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildActionCard(
              icon: Icons.undo, title: '恢复上次', subtitle: '回退到上一个封面',
              color: colors.onSurface.withValues(alpha: 0.5),
              onTap: _revertCover,
            )),
          ]),
        ],
      ),
    );
  }

  // ─── 构建组件 ────────────────────────────────────────────────

  Widget _buildCoverPicker(String? coverPath, ColorScheme colors) {
    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        width: 110, height: 154,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()
            ? Image.file(File(coverPath), fit: BoxFit.cover)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28,
                      color: colors.onSurface.withValues(alpha: 0.25)),
                  const SizedBox(height: 6),
                  Text('点击更换',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String label, required String value, required IconData icon,
    required VoidCallback onTap, required ColorScheme colors,
    bool required = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              if (required)
                Text(' *', style: TextStyle(fontSize: 11, color: colors.error)),
            ]),
            const Spacer(),
            Text(
              value.isEmpty ? '未设置' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: value.isEmpty ? colors.onSurface.withValues(alpha: 0.2) : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon, required String title, required String subtitle,
    required Color color, required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            ],
          )),
        ]),
      ),
    );
  }
}

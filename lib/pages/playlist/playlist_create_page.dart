import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';

class PlaylistCreatePage extends StatefulWidget {
  final Playlist? playlist; // 传入则为编辑模式
  const PlaylistCreatePage({super.key, this.playlist});

  @override
  State<PlaylistCreatePage> createState() => _PlaylistCreatePageState();
}

class _PlaylistCreatePageState extends State<PlaylistCreatePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late String _selectedType;
  bool _isSaving = false;

  bool get _isEdit => widget.playlist != null;

  static const _types = [
    ('movie', '影视', Icons.movie_outlined, Colors.blue),
    ('book', '书籍', Icons.menu_book_outlined, Colors.teal),
    ('game', '游戏', Icons.sports_esports_outlined, Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _descController = TextEditingController(text: widget.playlist?.description ?? '');
    _selectedType = widget.playlist?.type ?? 'movie';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final provider = context.read<AppProvider>();

    if (_isEdit) {
      final updated = widget.playlist!.copyWith(
        name: name,
        description: _descController.text.trim(),
        type: _selectedType,
        updatedAt: DateTime.now(),
      );
      await provider.updatePlaylist(updated);
    } else {
      final now = DateTime.now();
      final playlist = Playlist(
        id: const Uuid().v4(),
        name: name,
        description: _descController.text.trim(),
        type: _selectedType,
        createdAt: now,
        updatedAt: now,
      );
      await provider.addPlaylist(playlist);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑片单' : '创建片单'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isEdit ? '保存' : '创建', style: TextStyle(
              color: _nameController.text.trim().isEmpty ? colors.onSurface.withValues(alpha: 0.3) : colors.primary,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 类型选择
          if (!_isEdit) ...[
            Text('片单类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 10),
            Row(
              children: _types.map((t) {
                final (type, label, icon, color) = t;
                final selected = _selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.1) : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: selected ? Border.all(color: color.withValues(alpha: 0.3)) : null,
                      ),
                      child: Column(
                        children: [
                          Icon(icon, size: 22, color: selected ? color : colors.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(height: 6),
                          Text(label, style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? color : colors.onSurface.withValues(alpha: 0.5),
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          // 片单名称
          Text('片单名称', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: '输入片单名称',
              counterStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          // 片单详情
          Text('片单详情', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '描述一下这个片单（选填）',
              counterStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

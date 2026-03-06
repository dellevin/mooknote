import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑笔记页面 - 极简书写界面
class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  late TextEditingController _contentController;
  late DateTime _createdAt;
  List<String> _tags = [];
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _contentController = TextEditingController(text: note?.content ?? '');
    _createdAt = note?.createdAt ?? DateTime.now();
    _tags = note != null ? List.from(note.tags) : [];
    _isEditing = note != null;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? '编辑笔记' : '新建笔记'),
        actions: [
          TextButton(
            onPressed: _saveNote,
            child: const Text(
              '保存',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 顶部信息栏：创建时间 + 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // 创建时间
                Text(
                  _formatDateTime(_createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 16),
                // 标签
                Expanded(
                  child: _buildTagSelector(),
                ),
              ],
            ),
          ),
          
          // 书写区域
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
                height: 1.6,
              ),
              decoration: const InputDecoration(
                hintText: '开始书写...',
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFCCCCCC),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签选择器
  Widget _buildTagSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._tags.asMap().entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _tags.removeAt(entry.key)),
                  child: const Icon(
                    Icons.close,
                    size: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          );
        }),
        // 添加标签按钮
        GestureDetector(
          onTap: () => _showAddTagDialog(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 12,
                  color: Color(0xFF999999),
                ),
                SizedBox(width: 2),
                Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 显示添加标签对话框
  void _showAddTagDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '添加标签',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称',
            border: UnderlineInputBorder(),
          ),
          onSubmitted: (value) {
            _addTag(value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 添加标签
  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 保存笔记
  Future<void> _saveNote() async {
    final content = _contentController.text.trim();
    
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('笔记内容不能为空')),
      );
      return;
    }

    final now = DateTime.now();

    if (_isEditing) {
      // 更新现有笔记
      final updatedNote = widget.note!.copyWith(
        content: content,
        tags: _tags,
        updatedAt: now,
      );
      await context.read<AppProvider>().updateNote(updatedNote);
    } else {
      // 添加新笔记
      final newNote = Note(
        id: now.millisecondsSinceEpoch.toString(),
        content: content,
        tags: _tags,
        createdAt: _createdAt,
        updatedAt: now,
      );
      await context.read<AppProvider>().addNote(newNote);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? '保存成功' : '添加成功'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }
}

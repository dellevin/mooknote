import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';

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
  List<String> _images = []; // 图片路径列表
  String _contentType = 'plain_text'; // markdown / plain_text
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();
  String? _tempNoteId; // 新建模式时使用的临时笔记ID

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _contentController = TextEditingController(text: note?.content ?? '');
    _createdAt = note?.createdAt ?? DateTime.now();
    _tags = note != null ? List.from(note.tags) : [];
    _images = note != null ? List.from(note.images) : [];
    _contentType = note?.contentType ?? 'plain_text';
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
          IconButton(
            onPressed: _saveNote,
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 顶部信息栏：创建时间 + 格式选择 + 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 创建时间
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                      ),
                      child: Text(
                        _formatDateTime(_createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 格式选择
                    _buildFormatSelector(),
                  ],
                ),
                const SizedBox(height: 12),
                // 标签
                _buildTagSelector(),
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
              decoration: InputDecoration(
                hintText: _contentType == 'markdown' 
                    ? '使用 Markdown 格式书写...' 
                    : '开始书写...',
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFCCCCCC),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          // 图片区域（放在内容下方）
          if (_contentType == 'plain_text' && _images.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                ),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _buildHorizontalImageItem(index);
                },
              ),
            ),
          
          // 底部工具栏（纯文本模式下显示添加图片按钮）
          if (_contentType == 'plain_text')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // 图片数量
                  if (_images.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 14,
                            color: Color(0xFF666666),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_images.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // 添加图片按钮
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '添加图片',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建格式选择器
  Widget _buildFormatSelector() {
    return GestureDetector(
      onTap: () => _showFormatSelector(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _contentType == 'markdown' ? Icons.code : Icons.text_fields,
              size: 16,
              color: const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Text(
              _contentType == 'markdown' ? 'Markdown' : '纯文本',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF999999),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示格式选择对话框
  void _showFormatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示条
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '选择格式',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildFormatOption(
              icon: Icons.code,
              title: 'Markdown',
              subtitle: '支持 Markdown 语法',
              isSelected: _contentType == 'markdown',
              onTap: () {
                setState(() => _contentType = 'markdown');
                Navigator.pop(context);
              },
            ),
            _buildFormatOption(
              icon: Icons.text_fields,
              title: '纯文本',
              subtitle: '普通文本格式，支持图片',
              isSelected: _contentType == 'plain_text',
              onTap: () {
                setState(() => _contentType = 'plain_text');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建格式选项
  Widget _buildFormatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建标签选择器
  Widget _buildTagSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ..._tags.asMap().entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _tags.removeAt(entry.key)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Color(0xFF999999),
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFF999999),
                ),
                SizedBox(width: 4),
                Text(
                  '标签',
                  style: TextStyle(
                    fontSize: 13,
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
    
    // 获取所有已有标签（从所有笔记中收集）
    final provider = context.read<AppProvider>();
    final allTags = _getAllExistingTags(provider);
    // 过滤掉已添加的标签
    final availableTags = allTags.where((tag) => !_tags.contains(tag)).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '添加标签',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 输入框
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '输入新标签名称',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (value) {
                  _addTag(value);
                  Navigator.pop(context);
                },
              ),
              
              // 已有标签列表
              if (availableTags.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '或选择已有标签：',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: availableTags.map((tag) {
                    return GestureDetector(
                      onTap: () {
                        _addTag(tag);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('添加'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  /// 获取所有已有标签（从所有笔记中收集）
  List<String> _getAllExistingTags(AppProvider provider) {
    final allTags = <String>{};
    for (final note in provider.notes) {
      allTags.addAll(note.tags);
    }
    return allTags.toList()..sort();
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
      ToastUtil.show(context, '笔记内容不能为空');
      return;
    }

    final now = DateTime.now();

    if (_isEditing) {
      // 更新现有笔记
      final updatedNote = widget.note!.copyWith(
        content: content,
        contentType: _contentType,
        tags: _tags,
        images: _images,
        updatedAt: now,
      );
      await context.read<AppProvider>().updateNote(updatedNote);
    } else {
      // 添加新笔记 - 先创建笔记获取ID
      final noteId = now.millisecondsSinceEpoch.toString();
      
      // 如果有图片，需要移动到正确的ID目录
      List<String> finalImages = [];
      if (_images.isNotEmpty) {
        // 使用保存的临时ID，如果没有则使用当前noteId（理论上不会走到这里）
        final oldNoteId = _tempNoteId ?? noteId;
        final newNoteId = noteId;
        finalImages = await _moveImagesToNewId(oldNoteId, newNoteId);
      }
      
      final newNote = Note(
        id: noteId,
        content: content,
        contentType: _contentType,
        tags: _tags,
        images: finalImages.isNotEmpty ? finalImages : _images,
        createdAt: _createdAt,
        updatedAt: now,
      );
      await context.read<AppProvider>().addNote(newNote);
    }

    if (!mounted) return;

    ToastUtil.show(context, _isEditing ? '保存成功' : '添加成功');

    // 刷新笔记列表
    await context.read<AppProvider>().loadNotes();
    
    if (!mounted) return;
    Navigator.pop(context);
  }
  
  /// 将图片从临时ID目录移动到新ID目录
  Future<List<String>> _moveImagesToNewId(String oldNoteId, String newNoteId) async {
    final List<String> newPaths = [];
    
    final newDir = await ImagePathHelper.instance.getNoteImagesDir(newNoteId);
    
    for (final imagePath in _images) {
      // 使用路径分隔符检查，兼容 Windows 和 Unix
      final normalizedPath = imagePath.replaceAll('\\', '/');
      if (normalizedPath.contains('/notes/$oldNoteId/')) {
        // 需要移动的文件
        final fileName = p.basename(imagePath);
        final newPath = p.join(newDir, fileName);
        
        await ImagePathHelper.instance.ensureDirExists(newDir);
        
        // 检查源文件是否存在
        final sourceFile = File(imagePath);
        if (await sourceFile.exists()) {
          await sourceFile.rename(newPath);
          newPaths.add(newPath);
        }
      } else {
        // 已经在正确位置的文件
        newPaths.add(imagePath);
      }
    }
    
    // 删除旧目录
    try {
      await ImagePathHelper.instance.deleteNoteImages(oldNoteId);
    } catch (e) {
      // 忽略删除失败
    }
    
    return newPaths;
  }

  /// 选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        // 生成唯一的文件名
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // 如果是编辑模式，使用现有笔记ID；如果是新建模式，使用临时ID（保存时会替换）
        String noteId;
        if (_isEditing) {
          noteId = widget.note!.id;
        } else {
          // 新建模式：使用已存在的临时ID或生成新的
          noteId = _tempNoteId ?? DateTime.now().millisecondsSinceEpoch.toString();
          _tempNoteId = noteId;
        }
        
        // 复制图片到应用目录: images/notes/{noteId}/{fileName}
        final targetDir = await ImagePathHelper.instance.getNoteImagesDir(noteId);
        await ImagePathHelper.instance.ensureDirExists(targetDir);
        final targetPath = p.join(targetDir, fileName);
        
        await File(image.path).copy(targetPath);
        
        setState(() => _images.add(targetPath));
      }
    } catch (e) {
      ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  /// 构建图片项
  Widget _buildImageItem(int index) {
    return InkWell(
      onTap: () => _showImagePreview(index),
      onLongPress: () => _showDeleteImageDialog(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(_images[index]),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 构建横向图片项（用于底部图片栏）
  Widget _buildHorizontalImageItem(int index) {
    return InkWell(
      onTap: () => _showImagePreview(index),
      onLongPress: () => _showDeleteImageDialog(index),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.file(
          File(_images[index]),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 显示图片预览
  void _showImagePreview(int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(_images[index]),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示删除图片确认对话框
  void _showDeleteImageDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '确定要删除这张图片吗？此操作不可恢复。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _images.removeAt(index));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

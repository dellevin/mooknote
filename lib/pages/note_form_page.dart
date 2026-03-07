import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';
import '../utils/image_path_helper.dart';

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
  String _contentType = 'markdown'; // markdown / plain_text
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
    _contentType = note?.contentType ?? 'markdown';
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
          // 顶部信息栏：创建时间 + 格式选择 + 标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // 创建时间
                    Text(
                      _formatDateTime(_createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const Spacer(),
                    // 格式选择
                    _buildFormatSelector(),
                  ],
                ),
                const SizedBox(height: 8),
                // 标签
                _buildTagSelector(),
              ],
            ),
          ),
          
          // 书写区域（纯文本模式下占据35%高度，Markdown模式下占据全部）
          if (_contentType == 'plain_text')
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
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
            )
          else
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
                  hintText: '使用 Markdown 格式书写...',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFCCCCCC),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
          
          // 纯文本模式下的图片区域
          if (_contentType == 'plain_text') ...[
            // 图片网格区域
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题栏
                    Row(
                      children: [
                        const Text(
                          '图片',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_images.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const Spacer(),
                        // 添加图片按钮
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '添加',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // 图片网格（4列，正方形铺满）
                    Expanded(
                      child: _images.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 48,
                                    color: const Color(0xFFCCCCCC),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    '点击添加按钮添加图片',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _images.length,
                              itemBuilder: (context, index) {
                                return _buildImageItem(index);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建格式选择器
  Widget _buildFormatSelector() {
    return GestureDetector(
      onTap: () => _showFormatSelector(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _contentType == 'markdown' ? Icons.code : Icons.text_fields,
              size: 14,
              color: const Color(0xFF666666),
            ),
            const SizedBox(width: 4),
            Text(
              _contentType == 'markdown' ? 'Markdown' : '纯文本',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.code, size: 20),
              title: const Text('Markdown'),
              subtitle: const Text('支持 Markdown 语法'),
              trailing: _contentType == 'markdown' 
                  ? const Icon(Icons.check, color: Color(0xFF1A1A1A))
                  : null,
              onTap: () {
                setState(() => _contentType = 'markdown');
                Navigator.pop(context);
              },
            ),
            const Divider(height: 0.5, indent: 56),
            ListTile(
              leading: const Icon(Icons.text_fields, size: 20),
              title: const Text('纯文本'),
              subtitle: const Text('普通文本格式，支持图片'),
              trailing: _contentType == 'plain_text'
                  ? const Icon(Icons.check, color: Color(0xFF1A1A1A))
                  : null,
              onTap: () {
                setState(() => _contentType = 'plain_text');
                Navigator.pop(context);
              },
            ),
          ],
        ),
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
      onLongPress: () => _showDeleteImageDialog(index),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Image.file(
          File(_images[index]),
          fit: BoxFit.cover,
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这张图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () {
              setState(() => _images.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

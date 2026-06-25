import 'package:flutter/foundation.dart';
import '../models/note_plus_models.dart';
import '../utils/note_plus/note_plus_dao.dart';

/// Note Plus 块编辑器状态管理
class NotePlusProvider extends ChangeNotifier {
  final NotePlusDao _dao = NotePlusDao();

  List<NotePlusDocument> _documents = [];
  NotePlusDocument? _currentDocument;
  List<NoteBlock> _blocks = [];
  int _focusedBlockIndex = 0;
  bool _isDirty = false;

  // Undo/Redo
  final List<List<NoteBlock>> _undoStack = [];
  final List<List<NoteBlock>> _redoStack = [];
  static const int _maxUndoSize = 50;

  // Getters
  List<NotePlusDocument> get documents => _documents;
  NotePlusDocument? get currentDocument => _currentDocument;
  List<NoteBlock> get blocks => _blocks;
  int get focusedBlockIndex => _focusedBlockIndex;
  bool get isDirty => _isDirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  // ========== 文档 CRUD ==========

  Future<void> loadDocuments() async {
    _documents = await _dao.getAll();
    notifyListeners();
  }

  Future<void> loadDocumentById(String id) async {
    _currentDocument = await _dao.getById(id);
    if (_currentDocument != null) {
      _blocks = _currentDocument!.blocks.map((b) => b.deepCopy()).toList();
      _focusedBlockIndex = 0;
      _isDirty = false;
      _undoStack.clear();
      _redoStack.clear();
    }
    notifyListeners();
  }

  Future<void> saveDocument({String? deltaJson}) async {
    if (_currentDocument == null) return;
    final now = DateTime.now();
    // 直接构造，避免 copyWith 的 null 歧义
    _currentDocument = NotePlusDocument(
      id: _currentDocument!.id,
      title: _currentDocument!.title,
      parentId: _currentDocument!.parentId,
      sortIndex: _currentDocument!.sortIndex,
      blocks: deltaJson == null ? List.from(_blocks) : _currentDocument!.blocks,
      blocksJson: deltaJson,
      tags: _currentDocument!.tags,
      images: _currentDocument!.images,
      createdAt: _currentDocument!.createdAt,
      updatedAt: now,
      isDeleted: _currentDocument!.isDeleted,
    );
    await _dao.update(_currentDocument!);
    final idx = _documents.indexWhere((d) => d.id == _currentDocument!.id);
    if (idx >= 0) _documents[idx] = _currentDocument!;
    _isDirty = false;
    notifyListeners();
  }

  /// 保存 Quill Delta JSON 作为文档内容（flutter_quill 模式）
  void saveDeltaJson(String deltaJson) {
    if (_currentDocument == null) return;
    _currentDocument = NotePlusDocument(
      id: _currentDocument!.id,
      title: _currentDocument!.title,
      parentId: _currentDocument!.parentId,
      sortIndex: _currentDocument!.sortIndex,
      blocksJson: deltaJson,
      tags: _currentDocument!.tags,
      images: _currentDocument!.images,
      createdAt: _currentDocument!.createdAt,
      updatedAt: DateTime.now(),
      isDeleted: _currentDocument!.isDeleted,
    );
    _isDirty = true;
  }

  Future<NotePlusDocument> createDocument({String title = '', String parentId = ''}) async {
    final doc = NotePlusDocument(title: title, parentId: parentId);
    await _dao.insert(doc);
    await loadDocuments();
    return doc;
  }

  /// 移动文档到指定父级的指定位置（原子操作，同时处理重排序）
  Future<void> moveDocumentTo(String docId, String newParentId, int insertIndex) async {
    final idx = _documents.indexWhere((d) => d.id == docId);
    if (idx < 0) return;

    final doc = _documents[idx];
    final oldParentId = doc.parentId;

    // 获取目标父级下的同级文档（不含自身）
    final siblings = _documents
        .where((d) => d.parentId == newParentId && d.id != docId)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    // 钳制插入位置
    var pos = insertIndex.clamp(0, siblings.length);

    // 如果是同级移动，且拖到自己的后面，需要减 1（因为移除自己后索引会偏移）
    if (oldParentId == newParentId) {
      final oldIndex = siblings.indexWhere((d) => d.sortIndex > doc.sortIndex);
      if (oldIndex >= 0 && pos > oldIndex) {
        pos = (pos - 1).clamp(0, siblings.length);
      }
    }

    // 插入到指定位置
    siblings.insert(pos, doc);

    // 批量更新 sortIndex 和 parentId
    for (int i = 0; i < siblings.length; i++) {
      final s = siblings[i];
      final needsUpdate = s.sortIndex != i || s.id == docId && doc.parentId != newParentId;
      if (needsUpdate) {
        final updated = s.copyWith(
          parentId: newParentId,
          sortIndex: i,
          updatedAt: DateTime.now(),
        );
        await _dao.update(updated);
        final uIdx = _documents.indexWhere((d) => d.id == updated.id);
        if (uIdx >= 0) _documents[uIdx] = updated;
      }
    }

    notifyListeners();
  }

  /// 旧接口兼容：仅移动到新父级（放到末尾）
  Future<void> moveDocument(String docId, String newParentId) async {
    final siblings = _documents.where((d) => d.parentId == newParentId && d.id != docId).toList();
    await moveDocumentTo(docId, newParentId, siblings.length);
  }

  /// 删除文档时，将其子文档提升到祖父节点
  Future<void> deleteDocument(String id) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx >= 0) {
      final parentId = _documents[idx].parentId;
      // 将子文档的 parent_id 改为被删文档的 parent_id
      final children = _documents.where((d) => d.parentId == id).toList();
      for (final child in children) {
        final updated = child.copyWith(parentId: parentId, updatedAt: DateTime.now());
        await _dao.update(updated);
      }
    }
    await _dao.delete(id);
    await loadDocuments();
  }

  Future<void> restoreDocument(String id) async {
    await _dao.restore(id);
    await loadDocuments();
  }

  Future<void> permanentDeleteDocument(String id) async {
    await _dao.permanentDelete(id);
    await loadDocuments();
  }

  Future<List<NotePlusDocument>> getDeletedDocuments() async {
    return await _dao.getDeleted();
  }

  Future<void> searchDocuments(String query) async {
    _documents = await _dao.search(query);
    notifyListeners();
  }

  // ========== 文档属性 ==========

  void setTitle(String title) {
    if (_currentDocument == null) return;
    _currentDocument = _currentDocument!.copyWith(title: title);
    _isDirty = true;
    notifyListeners();
  }

  /// 重命名文档（在文档列表中调用）
  Future<void> renameDocument(String id, String newTitle) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final doc = _documents[idx].copyWith(title: newTitle, updatedAt: DateTime.now());
    await _dao.update(doc);
    _documents[idx] = doc;
    notifyListeners();
  }

  /// 更新文档所属文件夹
  Future<void> updateDocumentFolder(String id, String folder) async {
    final idx = _documents.indexWhere((d) => d.id == id);
    if (idx < 0) return;
    final doc = _documents[idx].copyWith(parentId: folder, updatedAt: DateTime.now());
    await _dao.update(doc);
    _documents[idx] = doc;
    notifyListeners();
  }

  // ========== Block 操作 ==========

  void setFocusedBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    _focusedBlockIndex = index;
    notifyListeners();
  }

  /// 添加 block（在指定位置之后）
  void addBlock(int afterIndex, NoteBlock block) {
    _pushUndo();
    final insertAt = afterIndex + 1;
    if (insertAt >= _blocks.length) {
      _blocks.add(block);
    } else {
      _blocks.insert(insertAt, block);
    }
    _focusedBlockIndex = insertAt;
    _isDirty = true;
    notifyListeners();
  }

  /// 移除 block
  void removeBlock(int index) {
    if (_blocks.length <= 1 || index < 0 || index >= _blocks.length) return;
    _pushUndo();
    _blocks.removeAt(index);
    if (_focusedBlockIndex >= _blocks.length) {
      _focusedBlockIndex = _blocks.length - 1;
    }
    _isDirty = true;
    notifyListeners();
  }

  /// 更新 block 内容（不触发 notify，编辑时高频调用）
  void updateBlockSilent(int index, NoteBlock block) {
    if (index < 0 || index >= _blocks.length) return;
    _blocks[index] = block;
    _isDirty = true;
  }

  /// 更新 block 并通知
  void updateBlock(int index, NoteBlock block) {
    updateBlockSilent(index, block);
    notifyListeners();
  }

  /// 拖拽移动 block
  void moveBlock(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    _pushUndo();
    final block = _blocks.removeAt(oldIndex);
    final insertAt = newIndex > oldIndex ? newIndex - 1 : newIndex;
    _blocks.insert(insertAt, block);
    _focusedBlockIndex = insertAt;
    _isDirty = true;
    notifyListeners();
  }

  /// 转换 block 类型
  void convertBlockType(int index, NoteBlockType newType) {
    if (index < 0 || index >= _blocks.length) return;
    _pushUndo();
    _blocks[index] = _blocks[index].copyWith(type: newType);
    if (newType == NoteBlockType.divider) {
      _blocks[index] = _blocks[index].copyWith(text: '');
    }
    _isDirty = true;
    notifyListeners();
  }

  /// Enter 分割 block
  /// 返回新 block 的索引
  int splitBlock(int index, int splitPosition) {
    if (index < 0 || index >= _blocks.length) return index;
    _pushUndo();

    final current = _blocks[index];
    final textBefore = current.text.substring(0, splitPosition);
    final textAfter = current.text.substring(splitPosition);

    // 裁剪当前 block 的格式
    final beforeFormatting = _clipFormatting(current.formatting, 0, splitPosition);

    // 新 block 继承类型（heading 降为 paragraph）
    var newType = current.type;
    if (newType == NoteBlockType.heading1 ||
        newType == NoteBlockType.heading2 ||
        newType == NoteBlockType.heading3) {
      newType = NoteBlockType.paragraph;
    }

    // 平移新 block 的格式
    final afterFormatting = _shiftFormatting(current.formatting, splitPosition, -splitPosition);

    // 更新当前 block
    _blocks[index] = current.copyWith(
      text: textBefore,
      formatting: beforeFormatting,
    );

    // 插入新 block
    final newBlock = NoteBlock(
      type: newType,
      text: textAfter,
      formatting: afterFormatting,
    );
    final insertAt = index + 1;
    _blocks.insert(insertAt, newBlock);
    _focusedBlockIndex = insertAt;
    _isDirty = true;
    notifyListeners();
    return insertAt;
  }

  /// Backspace 合并到前一个 block
  /// 返回合并后的光标位置
  int mergeWithPrevious(int index) {
    if (index <= 0 || index >= _blocks.length) return 0;
    _pushUndo();

    final prev = _blocks[index - 1];
    final current = _blocks[index];
    final cursorPos = prev.text.length;

    // 合并文本
    final mergedText = prev.text + current.text;

    // 合并格式：平移当前 block 的格式
    final shiftedFormatting = _shiftFormatting(current.formatting, 0, cursorPos);
    final mergedFormatting = [...prev.formatting, ...shiftedFormatting];

    // 更新前一个 block
    _blocks[index - 1] = prev.copyWith(
      text: mergedText,
      formatting: mergedFormatting,
    );

    // 移除当前 block
    _blocks.removeAt(index);
    _focusedBlockIndex = index - 1;
    _isDirty = true;
    notifyListeners();
    return cursorPos;
  }

  /// 切换待办状态
  void toggleChecklist(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    if (block.type != NoteBlockType.checklist) return;
    _pushUndo();

    final checked = block.metadata['checked'] == true;
    _blocks[index] = block.copyWith(
      metadata: {...block.metadata, 'checked': !checked},
    );
    _isDirty = true;
    notifyListeners();
  }

  /// 应用内联格式
  void applyFormat(int blockIndex, InlineFormatType format, int start, int end) {
    if (blockIndex < 0 || blockIndex >= _blocks.length) return;
    if (start >= end) return;

    final block = _blocks[blockIndex];
    final formatting = List<InlineFormatSpan>.from(block.formatting);

    // 查找是否已有重叠的同格式 span
    bool found = false;
    for (int i = 0; i < formatting.length; i++) {
      final span = formatting[i];
      if (span.start <= start && span.end >= end && span.formats.contains(format)) {
        // 移除格式
        final newFormats = Set<InlineFormatType>.from(span.formats)..remove(format);
        if (newFormats.isEmpty) {
          formatting.removeAt(i);
        } else {
          formatting[i] = span.copyWith(formats: newFormats);
        }
        found = true;
        break;
      }
    }

    if (!found) {
      formatting.add(InlineFormatSpan(start: start, end: end, formats: {format}));
    }

    _blocks[blockIndex] = block.copyWith(formatting: formatting);
    _isDirty = true;
    notifyListeners();
  }

  // ========== Undo/Redo ==========

  void _pushUndo() {
    _undoStack.add(_blocks.map((b) => b.deepCopy()).toList());
    if (_undoStack.length > _maxUndoSize) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_blocks.map((b) => b.deepCopy()).toList());
    _blocks = _undoStack.removeLast();
    if (_focusedBlockIndex >= _blocks.length) {
      _focusedBlockIndex = _blocks.length - 1;
    }
    _isDirty = true;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_blocks.map((b) => b.deepCopy()).toList());
    _blocks = _redoStack.removeLast();
    if (_focusedBlockIndex >= _blocks.length) {
      _focusedBlockIndex = _blocks.length - 1;
    }
    _isDirty = true;
    notifyListeners();
  }

  // ========== 格式辅助 ==========

  /// 裁剪格式区间到 [clipStart, clipEnd)
  List<InlineFormatSpan> _clipFormatting(
      List<InlineFormatSpan> spans, int clipStart, int clipEnd) {
    return spans
        .where((s) => s.end > clipStart && s.start < clipEnd)
        .map((s) => InlineFormatSpan(
              start: s.start < clipStart ? clipStart : s.start,
              end: s.end > clipEnd ? clipEnd : s.end,
              formats: Set.from(s.formats),
            ))
        .toList();
  }

  /// 平移格式区间（从 fromPos 之后的 span 偏移 offset）
  List<InlineFormatSpan> _shiftFormatting(
      List<InlineFormatSpan> spans, int fromPos, int offset) {
    return spans
        .where((s) => s.end > fromPos)
        .map((s) => InlineFormatSpan(
              start: (s.start < fromPos ? fromPos : s.start) + offset,
              end: s.end + offset,
              formats: Set.from(s.formats),
            ))
        .where((s) => s.start >= 0 && s.end > s.start)
        .toList();
  }
}

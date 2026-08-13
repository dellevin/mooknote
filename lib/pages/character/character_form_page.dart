import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/genre_selector_page.dart';
import '../../widgets/app_overlay.dart';

/// 角色编辑/添加页面
///
/// entityType: 'movie' / 'book' / 'game'
/// entityId: 所属作品 ID
/// character: 可空，空=新建
class CharacterFormPage extends StatefulWidget {
  final String entityType;
  final String entityId;
  final dynamic character; // MovieCharacter / BookCharacter / GameCharacter

  const CharacterFormPage({
    super.key,
    required this.entityType,
    required this.entityId,
    this.character,
  });

  @override
  State<CharacterFormPage> createState() => _CharacterFormPageState();
}

class _CharacterFormPageState extends State<CharacterFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<String> _aliases = [];
  List<String> _tags = [];
  String? _imagePath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (widget.character != null) {
      final c = widget.character;
      _nameCtrl.text = c.name;
      _roleCtrl.text = c.role ?? '';
      _descCtrl.text = c.description ?? '';
      _aliases = List<String>.from(c.aliases);
      _tags = List<String>.from(c.tags);
      _imagePath = c.imagePath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.character != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(isEdit ? '编辑角色' : '添加角色'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(child: _buildImagePicker(colors)),
              const SizedBox(height: 24),

              _buildField('名称', _nameCtrl, hint: '角色名称', required: true),
              const SizedBox(height: 16),

              _buildField('角色定位', _roleCtrl, hint: '如：男主、女主、反派、配角'),
              const SizedBox(height: 16),

              _buildChipField('别名', _aliases, colors, onTap: () async {
                final result = await GenreSelectorPage.show(
                  context: context,
                  title: '添加别名',
                  existingTags: [],
                  initialSelected: _aliases,
                  hint: '如：曾用名、英文名',
                );
                if (result != null) setState(() => _aliases = result);
              }),
              const SizedBox(height: 16),

              _buildChipField('标签', _tags, colors, onTap: () async {
                final result = await GenreSelectorPage.show(
                  context: context,
                  title: '添加标签',
                  existingTags: [],
                  initialSelected: _tags,
                  hint: '如：主角、反派',
                );
                if (result != null) setState(() => _tags = result);
              }),
              const SizedBox(height: 16),

              _buildSectionLabel('角色简介', colors),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(minHeight: 120),
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: null,
                  style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
                  decoration: InputDecoration(
                    hintText: '写下角色简介...',
                    hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(ColorScheme colors) {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showImageOptions,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasImage)
                  FadeInLocalImage(path: _imagePath, fit: BoxFit.cover)
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(height: 4),
                      Text('添加图片', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                    ],
                  ),
                if (_isDownloading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        if (hasImage)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => setState(() => _imagePath = null),
              child: Text('移除图片', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
            ),
          ),
      ],
    );
  }

  void _showImageOptions() {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.outline, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(alignment: Alignment.centerLeft,
                  child: Text('添加图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface))),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: colors.onSurface.withValues(alpha: 0.6)),
                title: Text('从相册选择', style: TextStyle(color: colors.onSurface)),
                onTap: () { Navigator.pop(ctx); _pickImage(); },
              ),
              ListTile(
                leading: Icon(Icons.link_outlined, color: colors.onSurface.withValues(alpha: 0.6)),
                title: Text('网络链接', style: TextStyle(color: colors.onSurface)),
                onTap: () { Navigator.pop(ctx); _pickImageFromUrl(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _characterId() async {
    if (widget.character != null) return widget.character.id;
    return const Uuid().v4();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 85);
      if (picked == null) return;
      final fileName = 'char_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final charId = await _characterId();
      final targetPath = await ImagePathHelper.instance.getCharacterImagePath(charId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (mounted) setState(() => _imagePath = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  Future<void> _pickImageFromUrl() async {
    String? url;
    final confirmed = await appDialog<bool>(context: context, builder: (ctx) {
      final urlCtrl = TextEditingController();
      final colors = Theme.of(ctx).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('添加网络图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入图片链接地址', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'https://example.com/image.jpg',
                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                filled: true, fillColor: colors.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () { url = urlCtrl.text.trim(); Navigator.pop(ctx, true); },
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('确定'),
          ),
        ],
      );
    });
    if (confirmed != true || url == null || url!.isEmpty) return;
    await _downloadImageFromUrl(url!);
  }

  Future<void> _downloadImageFromUrl(String url) async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );

      if (response.statusCode != 200) throw Exception('下载失败: HTTP ${response.statusCode}');

      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');

      final fileName = 'char_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final charId = await _characterId();
      final targetPath = await ImagePathHelper.instance.getCharacterImagePath(charId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() => _imagePath = targetPath);
    } catch (e) {
      debugPrint('角色图片下载失败: $e');
      if (mounted) ToastUtil.show(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildSectionLabel(String label, ColorScheme colors) {
    return Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)));
  }

  Widget _buildField(String label, TextEditingController ctrl, {String hint = '', bool required = false}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(required ? '$label *' : label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          style: TextStyle(fontSize: 14, color: colors.onSurface),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? '请输入$label' : null : null,
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
            filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildChipField(String label, List<String> chips, ColorScheme colors, {required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: chips.isEmpty
                ? Text('点击添加$label', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)))
                : Wrap(
                    spacing: 4, runSpacing: 4,
                    children: chips.map((c) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(4)),
                      child: Text(c, style: TextStyle(fontSize: 12, color: colors.onSurface)),
                    )).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  bool _hasContent() {
    if (widget.character != null) return true;
    if (_nameCtrl.text.trim().isNotEmpty) return true;
    if (_roleCtrl.text.trim().isNotEmpty) return true;
    if (_descCtrl.text.trim().isNotEmpty) return true;
    if (_imagePath != null) return true;
    if (_aliases.isNotEmpty || _tags.isNotEmpty) return true;
    return false;
  }

  Future<bool> _confirmLeave() async {
    if (!_hasContent()) return true;
    final colors = Theme.of(context).colorScheme;
    final result = await appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('未保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('当前内容未保存，确定要离开吗？',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('离开'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final now = DateTime.now();
      final provider = context.read<AppProvider>();
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final role = _roleCtrl.text.trim().isEmpty ? null : _roleCtrl.text.trim();

      if (widget.character == null) {
        // 新建
        final newId = const Uuid().v4();
        switch (widget.entityType) {
          case 'movie':
            await provider.addMovieCharacter(MovieCharacter(
              id: newId,
              movieId: widget.entityId,
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              createdAt: now,
              updatedAt: now,
            ));
            break;
          case 'book':
            await provider.addBookCharacter(BookCharacter(
              id: newId,
              bookId: widget.entityId,
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              createdAt: now,
              updatedAt: now,
            ));
            break;
          case 'game':
            await provider.addGameCharacter(GameCharacter(
              id: newId,
              gameId: widget.entityId,
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              createdAt: now,
              updatedAt: now,
            ));
            break;
        }
      } else {
        // 编辑
        final c = widget.character;
        switch (widget.entityType) {
          case 'movie':
            await provider.updateMovieCharacter((c as MovieCharacter).copyWith(
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              updatedAt: now,
            ));
            break;
          case 'book':
            await provider.updateBookCharacter((c as BookCharacter).copyWith(
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              updatedAt: now,
            ));
            break;
          case 'game':
            await provider.updateGameCharacter((c as GameCharacter).copyWith(
              name: _nameCtrl.text.trim(),
              role: role,
              aliases: _aliases,
              tags: _tags,
              description: desc,
              imagePath: _imagePath,
              updatedAt: now,
            ));
            break;
        }
      }

      if (!mounted) return;
      ToastUtil.show(context, widget.character == null ? '添加成功' : '更新成功');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: $e');
    }
  }
}

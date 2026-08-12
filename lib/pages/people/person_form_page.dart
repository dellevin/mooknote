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

/// 人物编辑/添加页面
class PersonFormPage extends StatefulWidget {
  final Person? person;

  const PersonFormPage({super.key, this.person});

  @override
  State<PersonFormPage> createState() => _PersonFormPageState();
}

class _PersonFormPageState extends State<PersonFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _gender;
  DateTime? _birthDate;
  String? _birthPlace;
  List<String> _alternateNames = [];
  List<String> _occupation = [];
  String? _photoPath;
  bool _isDownloading = false;

  static const _genderOptions = [
    ('男', 'male'),
    ('女', 'female'),
    ('其他', 'other'),
  ];

  static const _occupationOptions = [
    '导演', '编剧', '演员', '制片人', '摄影师',
    '作者', '译者', '开发者', '配音', '其他',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.person != null) {
      final p = widget.person!;
      _nameCtrl.text = p.name;
      _summaryCtrl.text = p.summary ?? '';
      _birthPlaceCtrl.text = p.birthPlace ?? '';
      _gender = p.gender;
      _birthDate = p.birthDate;
      _birthPlace = p.birthPlace;
      _alternateNames = List.from(p.alternateNames);
      _occupation = List.from(p.occupation);
      _photoPath = p.photoPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _summaryCtrl.dispose();
    _birthPlaceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.person != null;

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
          title: Text(isEdit ? '编辑人物' : '添加人物'),
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
              // 头像
              Center(child: _buildPhotoPicker(colors)),
              const SizedBox(height: 24),

              // 名称
              _buildField('名称', _nameCtrl, hint: '人物名称', required: true),
              const SizedBox(height: 16),

              // 性别
              _buildSectionLabel('性别', colors),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _genderOptions.map((opt) {
                  final selected = _gender == opt.$2;
                  return GestureDetector(
                    onTap: () => setState(() => _gender = selected ? null : opt.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        opt.$1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                          color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // 出生日期
              _buildDateField('出生日期', _birthDate, (d) => setState(() => _birthDate = d), colors, clearable: true),
              const SizedBox(height: 16),

              // 出生地
              _buildField('出生地', _birthPlaceCtrl, hint: '如：北京',
                onChanged: (v) => _birthPlace = v.isEmpty ? null : v),
              const SizedBox(height: 16),

              // 其他名称
              _buildChipField('其他名称', _alternateNames, colors, onTap: () async {
                final result = await GenreSelectorPage.show(
                  context: context,
                  title: '添加其他名称',
                  existingTags: [],
                  initialSelected: _alternateNames,
                  hint: '如：艺名、英文名',
                );
                if (result != null) setState(() => _alternateNames = result);
              }),
              const SizedBox(height: 16),

              // 职业
              _buildChipField('职业', _occupation, colors, onTap: () async {
                final result = await GenreSelectorPage.show(
                  context: context,
                  title: '选择职业',
                  existingTags: _occupationOptions,
                  initialSelected: _occupation,
                  hint: '如：导演、演员',
                );
                if (result != null) setState(() => _occupation = result);
              }),
              const SizedBox(height: 16),

              // 简介
              _buildSectionLabel('人物简介', colors),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(minHeight: 120),
                child: TextFormField(
                  controller: _summaryCtrl,
                  maxLines: null,
                  style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
                  decoration: InputDecoration(
                    hintText: '写下人物简介...',
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

  Widget _buildPhotoPicker(ColorScheme colors) {
    final hasPhoto = _photoPath != null && _photoPath!.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showPhotoOptions,
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
                if (hasPhoto)
                  FadeInLocalImage(path: _photoPath, fit: BoxFit.cover)
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
        if (hasPhoto)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => setState(() => _photoPath = null),
              child: Text('移除图片', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
            ),
          ),
      ],
    );
  }

  void _showPhotoOptions() {
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
                onTap: () { Navigator.pop(ctx); _pickPhoto(); },
              ),
              ListTile(
                leading: Icon(Icons.link_outlined, color: colors.onSurface.withValues(alpha: 0.6)),
                title: Text('网络链接', style: TextStyle(color: colors.onSurface)),
                onTap: () { Navigator.pop(ctx); _pickPhotoFromUrl(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 85);
      if (picked == null) return;
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final personId = widget.person?.id ?? const Uuid().v4();
      final targetPath = await ImagePathHelper.instance.getPersonPhotoPath(personId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (mounted) setState(() => _photoPath = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  Future<void> _pickPhotoFromUrl() async {
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
    await _downloadPhotoFromUrl(url!);
  }

  Future<void> _downloadPhotoFromUrl(String url) async {
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

      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final personId = widget.person?.id ?? const Uuid().v4();
      final targetPath = await ImagePathHelper.instance.getPersonPhotoPath(personId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() => _photoPath = targetPath);
    } catch (e) {
      debugPrint('头像下载失败: $e');
      if (mounted) ToastUtil.show(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildSectionLabel(String label, ColorScheme colors) {
    return Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)));
  }

  Widget _buildField(String label, TextEditingController ctrl, {String hint = '', bool required = false, ValueChanged<String>? onChanged}) {
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
          onChanged: onChanged,
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

  Widget _buildDateField(String label, DateTime? date, ValueChanged<DateTime?> onChanged, ColorScheme colors, {bool clearable = false}) {
    final hasDate = date != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context, initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1800), lastDate: DateTime.now(),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Text(
                  hasDate ? '${date!.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}' : '选择日期',
                  style: TextStyle(fontSize: 14, color: hasDate ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25)),
                ),
                const Spacer(),
                if (clearable && hasDate)
                  GestureDetector(
                    onTap: () => onChanged(null),
                    child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
              ],
            ),
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
                ? Text('点击选择$label', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)))
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
    if (widget.person != null) return true;
    if (_nameCtrl.text.trim().isNotEmpty) return true;
    if (_summaryCtrl.text.trim().isNotEmpty) return true;
    if (_photoPath != null) return true;
    if (_gender != null || _birthDate != null || _birthPlace != null) return true;
    if (_alternateNames.isNotEmpty || _occupation.isNotEmpty) return true;
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

      if (widget.person == null) {
        // 新建
        final newId = const Uuid().v4();
        String? finalPhotoPath;
        if (_photoPath != null && _photoPath!.isNotEmpty) {
          finalPhotoPath = await _movePhotoToNewId(_photoPath!, newId);
        }

        final person = Person(
          id: newId,
          name: _nameCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          birthPlace: _birthPlace,
          alternateNames: _alternateNames,
          occupation: _occupation,
          summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
          photoPath: finalPhotoPath,
          createdAt: now,
          updatedAt: now,
        );
        await provider.addPerson(person);
      } else {
        // 编辑
        final updated = widget.person!.copyWith(
          name: _nameCtrl.text.trim(),
          gender: _gender,
          birthDate: _birthDate,
          birthPlace: _birthPlace,
          alternateNames: _alternateNames,
          occupation: _occupation,
          summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
          photoPath: _photoPath,
          updatedAt: now,
        );
        await provider.updatePerson(updated);
      }

      if (!mounted) return;
      ToastUtil.show(context, widget.person == null ? '添加成功' : '更新成功');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: $e');
    }
  }

  Future<String?> _movePhotoToNewId(String currentPath, String newPersonId) async {
    final normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath.contains('/people/$newPersonId/')) return currentPath;

    final fileName = p.basename(currentPath);
    final newPath = await ImagePathHelper.instance.getPersonPhotoPath(newPersonId, fileName);
    await ImagePathHelper.instance.ensureDirExists(p.dirname(newPath));

    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      await currentFile.rename(newPath);
      // 清理临时目录
      final tempDir = Directory(p.dirname(currentPath));
      if (await tempDir.exists()) {
        try { await tempDir.delete(recursive: true); } catch (_) {}
      }
      return newPath;
    }
    return null;
  }
}

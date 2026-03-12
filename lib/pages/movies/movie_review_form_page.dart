import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';

/// 添加/编辑影评页面 - 极简设计
class MovieReviewFormPage extends StatefulWidget {
  final String movieId;
  final MovieReview? review;

  const MovieReviewFormPage({
    super.key,
    required this.movieId,
    this.review,
  });

  @override
  State<MovieReviewFormPage> createState() => _MovieReviewFormPageState();
}

class _MovieReviewFormPageState extends State<MovieReviewFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  late TextEditingController _reviewerController;
  late TextEditingController _sourceController;
  late int _reviewType;

  @override
  void initState() {
    super.initState();
    final review = widget.review;
    _contentController = TextEditingController(text: review?.content ?? '');
    _reviewerController = TextEditingController(text: review?.reviewer ?? '');
    _sourceController = TextEditingController(text: review?.source ?? '');
    _reviewType = review?.reviewType ?? 1;
  }

  @override
  void dispose() {
    _contentController.dispose();
    _reviewerController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.review != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? '编辑影评' : '写影评'),
        actions: [
          TextButton(
            onPressed: _saveReview,
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
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // 顶部信息栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // 类型选择
                  _buildTypeSelector(),
                  const SizedBox(width: 16),
                  // 评论人
                  Expanded(
                    child: TextField(
                      controller: _reviewerController,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                      decoration: const InputDecoration(
                        hintText: '评论人',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 来源
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _sourceController,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                      decoration: const InputDecoration(
                        hintText: '来源',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 评论内容区域
            Expanded(
              child: TextFormField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                  height: 1.7,
                ),
                decoration: const InputDecoration(
                  hintText: '写下你的影评...',
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFCCCCCC),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入评论内容';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建类型选择器
  Widget _buildTypeSelector() {
    return GestureDetector(
      onTap: () => _showTypeSelector(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _reviewType == 1 ? '短评' : '长评',
              style: const TextStyle(
                fontSize: 13,
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

  /// 显示类型选择
  void _showTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('短评'),
              trailing: _reviewType == 1
                  ? const Icon(Icons.check, color: Color(0xFF1A1A1A))
                  : null,
              onTap: () {
                setState(() => _reviewType = 1);
                Navigator.pop(context);
              },
            ),
            const Divider(height: 0.5),
            ListTile(
              title: const Text('长评'),
              trailing: _reviewType == 2
                  ? const Icon(Icons.check, color: Color(0xFF1A1A1A))
                  : null,
              onTap: () {
                setState(() => _reviewType = 2);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();

    if (widget.review == null) {
      final newReview = MovieReview(
        id: now.millisecondsSinceEpoch.toString(),
        movieId: widget.movieId,
        content: _contentController.text.trim(),
        reviewer: _reviewerController.text.trim(),
        source: _sourceController.text.trim(),
        reviewType: _reviewType,
        createdAt: now,
        updatedAt: now,
      );
      await context.read<AppProvider>().addMovieReview(newReview);
    } else {
      final updatedReview = widget.review!.copyWith(
        content: _contentController.text.trim(),
        reviewer: _reviewerController.text.trim(),
        source: _sourceController.text.trim(),
        reviewType: _reviewType,
        updatedAt: now,
      );
      await context.read<AppProvider>().updateMovieReview(updatedReview);
    }

    if (!mounted) return;

    ToastUtil.show(context, widget.review == null ? '添加成功' : '更新成功');

    Navigator.pop(context);
  }
}

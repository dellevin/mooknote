import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_strings.dart';
import '../../services/report_service.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_overlay.dart';

/// 意见反馈页：提交反馈给开发者；历史反馈与回复在底部弹窗中查看
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _contentCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _submitting = false;
  int _myCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final items = await ReportService.instance.fetchMyFeedback();
    if (!mounted) return;
    setState(() => _myCount = items.length);
  }

  Future<void> _submit() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ToastUtil.show(context, '请填写反馈内容'.tr);
      return;
    }
    setState(() => _submitting = true);
    final ok = await ReportService.instance
        .submitFeedback(_contentCtrl.text, _contactCtrl.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _contentCtrl.clear();
      ToastUtil.show(context, '已提交，感谢反馈'.tr);
      _refreshCount();
    } else {
      ToastUtil.show(context, '提交失败，请稍后重试'.tr);
    }
  }

  InputDecoration _fieldDeco(ColorScheme colors, String hint) {
    final rounded = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      border: rounded,
      enabledBorder: rounded,
      focusedBorder: rounded,
      contentPadding: const EdgeInsets.all(14),
      counterText: '',
    );
  }

  Widget _sectionLabel(String label, ColorScheme colors) {
    return Text(label,
        style: TextStyle(
            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)));
  }

  void _showMyFeedback() {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => const _MyFeedbackSheet(),
    ).then((_) => _refreshCount());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('意见反馈'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ─── 提交反馈 ───
          _sectionLabel('反馈内容'.tr, colors),
          const SizedBox(height: 6),
          TextField(
            controller: _contentCtrl,
            minLines: 5,
            maxLines: null,
            maxLength: 2000,
            buildCounter: (ctx,
                    {required currentLength, required isFocused, maxLength}) =>
                Text('$currentLength/$maxLength',
                    style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurface.withValues(alpha: 0.3))),
            style:
                TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
            decoration: _fieldDeco(colors, '描述你遇到的问题或建议…'.tr),
          ),
          const SizedBox(height: 12),
          _sectionLabel('联系方式（选填）'.tr, colors),
          const SizedBox(height: 6),
          TextField(
            controller: _contactCtrl,
            maxLength: 100,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: _fieldDeco(colors, 'QQ / 邮箱，方便开发者联系你'.tr),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('提交反馈'.tr,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 28),

          // ─── 我的反馈入口（底部弹窗查看） ───
          _sectionLabel('反馈记录'.tr, colors),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: _showMyFeedback,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.forum_outlined,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('我的反馈'.tr,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface)),
                    ),
                    if (_myCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$_myCount',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors.primary)),
                      ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.35)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ─── 其他联系方式 ───
          _sectionLabel('其他联系方式'.tr, colors),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _contactRow(colors, Icons.email_outlined, '作者邮箱'.tr,
                    'dellevin99@gmail.com'),
                Divider(height: 0.5, indent: 46, color: colors.outlineVariant),
                _contactRow(
                    colors, Icons.group_outlined, 'QQ 群'.tr, '1087203310'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _contactRow(
      ColorScheme colors, IconData icon, String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ToastUtil.show(context, '已复制到剪贴板'.tr);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 18, color: colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.45))),
                  const SizedBox(height: 1),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)),
                ],
              ),
            ),
            Icon(Icons.copy,
                size: 14, color: colors.onSurface.withValues(alpha: 0.35)),
          ],
        ),
      ),
    );
  }
}

/// 「我的反馈」底部弹窗：自成状态，打开时拉取，支持下拉刷新
class _MyFeedbackSheet extends StatefulWidget {
  const _MyFeedbackSheet();

  @override
  State<_MyFeedbackSheet> createState() => _MyFeedbackSheetState();
}

class _MyFeedbackSheetState extends State<_MyFeedbackSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ReportService.instance.fetchMyFeedback();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('我的反馈'.tr,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                const SizedBox(width: 8),
                if (!_loading)
                  Text('${_items.length}',
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.35))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 90),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.chat_bubble_outline,
                                        size: 32,
                                        color: colors.onSurface
                                            .withValues(alpha: 0.15)),
                                    const SizedBox(height: 10),
                                    Text('暂无反馈记录'.tr,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: colors.onSurface
                                                .withValues(alpha: 0.4))),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _items.length,
                            itemBuilder: (ctx, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FeedbackItem(item: _items[i]),
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 单条反馈卡片：状态徽章 + 内容 + 开发者回复
class _FeedbackItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FeedbackItem({required this.item});

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso.substring(0, iso.length.clamp(0, 16));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pending = item['status'] == 'pending';
    final reply = (item['reply'] as String? ?? '').trim();
    // 状态色与徽章页分组色板一致
    final statusColor =
        pending ? const Color(0xFFFFB300) : const Color(0xFF66BB6A);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pending ? '待处理'.tr : '已处理'.tr,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
              const Spacer(),
              Text(_fmtTime(item['created_at'] as String?),
                  style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurface.withValues(alpha: 0.35))),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['content'] as String? ?? '',
              style: TextStyle(
                  fontSize: 13, height: 1.6, color: colors.onSurface)),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply, size: 12, color: colors.primary),
                      const SizedBox(width: 4),
                      Text('开发者回复'.tr,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reply,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: colors.onSurface.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

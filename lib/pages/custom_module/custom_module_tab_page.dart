import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/responsive.dart';
import '../../utils/slide_up_page_route.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../l10n/app_strings.dart';
import 'custom_module_design_list_page.dart';
import 'custom_module_detail_page.dart';

/// 自定义模块首页 tab 内容页：条目网格（封面+标题+评分+状态）+ 新增按钮
class CustomModuleTabPage extends StatefulWidget {
  final CustomModule module;
  const CustomModuleTabPage({super.key, required this.module});

  @override
  State<CustomModuleTabPage> createState() => _CustomModuleTabPageState();
}

class _CustomModuleTabPageState extends State<CustomModuleTabPage> with AutomaticKeepAliveClientMixin {
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();
  final CustomModuleItemDao _itemDao = CustomModuleItemDao();

  List<CustomModuleItem> _items = [];
  bool _hasActiveDesign = false;
  bool _loading = true;
  int _itemsVersion = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final design = await _designDao.getActiveDesign(widget.module.id);
      final items = await _itemDao.getItemsForModule(widget.module.id);
      if (!mounted) return;
      setState(() {
        _hasActiveDesign = design != null;
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;
    // 条目通过底部 + 弹窗等外部入口新增后，版本号变化触发刷新
    final version = context.watch<AppProvider>().customModuleItemsVersion;
    if (version != _itemsVersion) {
      _itemsVersion = version;
      _load();
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_hasActiveDesign) return _buildNoDesign(colors);

    return _items.isEmpty ? _buildEmpty(colors) : _buildGrid(colors);
  }

  Widget _buildNoDesign(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_outlined, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text('「${widget.module.name}」还没有启用中的表单设计',
                style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CustomModuleDesignListPage(moduleId: widget.module.id),
                ));
                _load();
              },
              icon: const Icon(Icons.design_services_outlined, size: 18),
              label: Text('去设计表单'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: colors.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('还没有条目'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('点击底部 + 新增'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  Widget _buildGrid(ColorScheme colors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = Breakpoint.isDesktop(context)
            ? 6
            : Breakpoint.isTablet(context)
                ? 4
                : 3;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) => _buildItemCard(_items[i], colors),
        );
      },
    );
  }

  Widget _buildItemCard(CustomModuleItem item, ColorScheme colors) {
    return GestureDetector(
      onTap: () async {
        final changed = await Navigator.push(context, SlideUpPageRoute(
          page: CustomModuleDetailPage(module: widget.module, itemId: item.id),
        ));
        if (changed == true) _load();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.coverPath != null && item.coverPath!.isNotEmpty
                  ? FadeInLocalImage(path: item.coverPath, fit: BoxFit.cover)
                  : Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 6),
          // 标题
          Text(
            item.title.isEmpty ? '未命名'.tr : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
          const SizedBox(height: 2),
          // 评分 + 状态
          Row(
            children: [
              if (item.rating != null) ...[
                const Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                const SizedBox(width: 2),
                Text(
                  item.rating! % 1 == 0 ? item.rating!.toInt().toString() : item.rating!.toString(),
                  style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6),
              ],
              if (item.status != null && item.status!.isNotEmpty)
                Expanded(
                  child: Text(
                    item.status!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.45)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

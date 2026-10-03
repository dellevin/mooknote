import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../../data/custom_module/custom_module_item_dao.dart';
import '../../utils/responsive.dart';
import '../../utils/slide_up_page_route.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/pressable_scale.dart';
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
  late final AppProvider _appProvider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // 条目通过底部 + 弹窗等外部入口新增后，版本号变化触发刷新；
    // 用显式监听替代 build 内的 watch+副作用
    // 缓存 provider 引用：dispose 阶段不可再用 context.read（element 已卸载）
    _appProvider = context.read<AppProvider>();
    _itemsVersion = _appProvider.customModuleItemsVersion;
    _appProvider.addListener(_onItemsVersionChanged);
  }

  void _onItemsVersionChanged() {
    final version = _appProvider.customModuleItemsVersion;
    if (version != _itemsVersion) {
      _itemsVersion = version;
      _load();
    }
  }

  @override
  void dispose() {
    _appProvider.removeListener(_onItemsVersionChanged);
    super.dispose();
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
            Text('「{name}」还没有启用中的表单设计'.trf({'name': widget.module.name}),
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
        // 与影视 tab 一致：按可用宽度自适应列数
        final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
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

  /// 长按卡片弹出删除确认（与影视 tab 一致：软删除，回收站可恢复）
  void _showDeleteDialog(CustomModuleItem item) {
    final colors = Theme.of(context).colorScheme;
    final title = item.title.isEmpty ? '未命名'.tr : item.title;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除《{title}》吗？删除后可在回收站恢复。'.trf({'title': title}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              await _itemDao.deleteItem(item.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ToastUtil.show(context, '已删除'.tr);
              // 与新增入口一致：bump 版本号，本页及其他观察者统一刷新
              context.read<AppProvider>().bumpCustomModuleItemsVersion();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: Text('删除'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildItemCard(CustomModuleItem item, ColorScheme colors) {
    return PressableScale(
      onTap: () async {
        final changed = await Navigator.push(context, SlideUpPageRoute(
          page: CustomModuleDetailPage(module: widget.module, itemId: item.id),
        ));
        if (changed == true) _load();
      },
      onLongPress: () => _showDeleteDialog(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面：灰底空壁纸占位（无海报时），有图后 BoxFit.cover 填满盖住灰底
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: FadeInLocalImage(
                path: item.coverPath,
                fit: BoxFit.cover,
                placeholder: Center(child: Icon(Icons.image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
                errorWidget: Center(child: Icon(Icons.image_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            item.title.isEmpty ? '未命名'.tr : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
          ),
          const SizedBox(height: 4),
          // 星级评分（与影视卡片一致；无评分占位保持卡片对齐）
          if (item.rating != null)
            AnimatedStarRating(rating: item.rating!, starSize: 12, showNumber: true)
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

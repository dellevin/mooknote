import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 自定义左侧弹出菜单
class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Drawer(
      child: Column(
        children: [
          // 顶部用户信息区域（含热力图）
          _buildHeader(context),
          
          // 分割线
          Divider(height: 1, color: colorScheme.outlineVariant),
          
          // 菜单项列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('统计'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 跳转到统计页面
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('回收站'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 跳转到回收站页面
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('设置'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 跳转到设置页面
                  },
                ),
              ],
            ),
          ),
          
          // 底部版本信息
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'MookNote v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头部（含热力图）
  Widget _buildHeader(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.surface,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 用户头像和名称
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '用户',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '记录生活点滴',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // GitHub 风格热力图
              _buildHeatmap(context),
            ],
          ),
        );
      },
    );
  }

  /// 构建热力图
  Widget _buildHeatmap(BuildContext context) {
    const int weeks = 52; // 一年 52 周
    const int daysPerWeek = 7;
    
    // 生成随机数据（实际应从数据库获取）
    final random = DateTime.now().millisecondsSinceEpoch;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '年度记录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: daysPerWeek * 14, // 每个格子 14x14
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(weeks, (weekIndex) {
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Column(
                  children: List.generate(daysPerWeek, (dayIndex) {
                    // 根据随机值决定颜色深度
                    final intensity = (random + weekIndex * 7 + dayIndex) % 100 / 100;
                    final color = _getHeatmapColor(intensity, context);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Less',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              'More',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }

  /// 根据强度获取热力图颜色
  Color _getHeatmapColor(double intensity, BuildContext context) {
    if (intensity == 0) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    } else if (intensity < 0.25) {
      return Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4);
    } else if (intensity < 0.5) {
      return Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6);
    } else if (intensity < 0.75) {
      return Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8);
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }
}

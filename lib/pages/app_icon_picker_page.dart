import 'package:flutter/material.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../utils/app_icon_channel.dart';

/// 应用图标选择页面
class AppIconPickerPage extends StatefulWidget {
  const AppIconPickerPage({super.key});

  @override
  State<AppIconPickerPage> createState() => _AppIconPickerPageState();
}

class _AppIconPickerPageState extends State<AppIconPickerPage> {
  final UserPrefs _userPrefs = UserPrefs();
  String _currentIconName = 'app_icon';

  // 预定义的图标列表
  final List<Map<String, String>> _icons = [
    {'name': 'app_icon', 'label': '默认图标'},
    {'name': 'app_icon2', 'label': '风格二'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    // 先从原生层获取当前实际启用的图标（更准确）
    final nativeIcon = await AppIconChannel.getCurrentIcon();
    setState(() {
      _currentIconName = nativeIcon;
    });
  }

  Future<void> _selectIcon(String iconName) async {
    if (iconName == _currentIconName) return;

    try {
      // 调用原生层切换桌面图标
      final success = await AppIconChannel.switchIcon(iconName);

      if (success) {
        await _userPrefs.setAppIconName(iconName);
        setState(() {
          _currentIconName = iconName;
        });

        if (mounted) {
          ToastUtil.show(context, '图标已切换，请返回桌面查看');
        }
      } else {
        if (mounted) {
          ToastUtil.show(context, '图标切换失败');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '切换出错: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('应用图标'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _icons.length,
        itemBuilder: (context, index) {
          final icon = _icons[index];
          final isSelected = _currentIconName == icon['name'];
          
          return GestureDetector(
            onTap: () => _selectIcon(icon['name']!),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F0F0) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 图标预览
                  Image.asset(
                    'assets/icon/${icon['name']}.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEEE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_not_supported, color: Color(0xFF999999)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // 标签
                  Text(
                    icon['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF1A1A1A)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    final nativeIcon = await AppIconChannel.getCurrentIcon();
    setState(() {
      _currentIconName = nativeIcon;
    });
  }

  Future<void> _selectIcon(String iconName) async {
    if (iconName == _currentIconName) return;

    try {
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
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
                color: isSelected ? colors.outlineVariant : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/${icon['name']}.png',
                    width: 64,
                    height: 64,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.image_not_supported, color: colors.onSurface.withValues(alpha: 0.4)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    icon['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: colors.onSurface,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 4),
                    Icon(Icons.check_circle, size: 18, color: colors.primary),
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

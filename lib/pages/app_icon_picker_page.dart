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
    {'name': 'app_icon_m', 'label': '风格三'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    final nativeIcon = await AppIconChannel.getCurrentIcon();
    setState(() => _currentIconName = nativeIcon);
  }

  Future<void> _selectIcon(String iconName) async {
    if (iconName == _currentIconName) return;
    try {
      final success = await AppIconChannel.switchIcon(iconName);
      if (success) {
        await _userPrefs.setAppIconName(iconName);
        setState(() => _currentIconName = iconName);
        if (mounted) ToastUtil.show(context, '图标已切换，请返回桌面查看');
      } else {
        if (mounted) ToastUtil.show(context, '图标切换失败');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '切换出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        title: const Text('应用图标'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _icons.length,
        itemBuilder: (context, index) {
          final icon = _icons[index];
          final isSelected = _currentIconName == icon['name'];

          return InkWell(
            onTap: () => _selectIcon(icon['name']!),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colors.primary : Colors.transparent,
                  width: isSelected ? 2 : 0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: colors.outlineVariant, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/${icon['name']}.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
                        color: colors.surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported,
                            size: 18,
                            color: colors.onSurface.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      icon['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 20, color: colors.primary)
                  else
                    Icon(Icons.radio_button_unchecked,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.2)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

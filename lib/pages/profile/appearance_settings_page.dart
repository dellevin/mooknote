import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/theme/app_theme.dart';
import 'font_picker_page.dart';

/// 界面设置：主题模式（跟随系统 / 浅色 / 深色）+ 配色方案（莫奈取色 / 种子色卡片）
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const _themeModes = [
    (ThemeMode.system, Icons.brightness_auto),
    (ThemeMode.light, Icons.light_mode),
    (ThemeMode.dark, Icons.dark_mode),
  ];
  static const _themeLabels = ['跟随系统', '浅色模式', '深色模式'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('界面设置'.tr)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSectionHeader(colors, '主题模式'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (int i = 0; i < _themeModes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _buildThemeCard(
                      context,
                      colors,
                      mode: _themeModes[i].$1,
                      icon: _themeModes[i].$2,
                      label: _themeLabels[i].tr,
                      selected: provider.themeMode == _themeModes[i].$1,
                      onTap: () =>
                          context.read<AppProvider>().setThemeMode(_themeModes[i].$1),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(colors, '配色方案'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildMonetCard(context, colors, provider),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2),
              itemCount: AppTheme.seedColors.length,
              itemBuilder: (_, i) {
                final selected = provider.colorSchemeIndex == i;
                return GestureDetector(
                  onTap: () => context.read<AppProvider>().setColorScheme(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.seedColors[i].withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? AppTheme.seedColors[i]
                              : Colors.transparent,
                          width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: AppTheme.seedColors[i],
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(AppTheme.colorSchemeNames[i].tr,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: colors.onSurface)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(colors, '字体'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFontTile(context, colors, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildFontTile(
      BuildContext context, ColorScheme colors, AppProvider provider) {
    final label =
        provider.fontFamily.isEmpty ? '系统默认'.tr : provider.fontFamily;
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
              builder: (_) => const FontPickerPage(initialFamily: '')),
        );
        if (result != null && context.mounted) {
          context.read<AppProvider>().setFontFamily(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.font_download_outlined,
                size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('字体'.tr,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ColorScheme colors, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.5))),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    ColorScheme colors, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: colors.onSurface)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonetCard(
      BuildContext context, ColorScheme colors, AppProvider provider) {
    final selected = provider.colorSchemeIndex == -1;
    final monetColor = AppTheme.monetColor;
    final available = monetColor != null;
    return GestureDetector(
      onTap: available
          ? () => context.read<AppProvider>().setColorScheme(-1)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (monetColor ?? colors.primary).withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? (monetColor ?? colors.primary)
                  : available
                      ? colors.outlineVariant
                      : colors.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: monetColor != null
                    ? LinearGradient(
                        colors: [monetColor, monetColor.withValues(alpha: 0.6)])
                    : null,
                color: available ? null : colors.outlineVariant,
              ),
              child: available
                  ? null
                  : Icon(Icons.auto_awesome,
                      size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('莫奈取色'.tr,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: available
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.35))),
                    Text(
                        available
                            ? '从系统壁纸自动提取配色'.tr
                            : '此设备不支持'.tr,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.35))),
                  ]),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  size: 18, color: monetColor ?? colors.primary),
          ],
        ),
      ),
    );
  }
}

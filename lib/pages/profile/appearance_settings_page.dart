import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/theme/app_theme.dart';
import 'font_picker_page.dart';

/// 界面设置：主题模式（跟随系统 / 浅色 / 深色）+ 配色方案（莫奈取色 / 种子色卡片）+ 字体
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  static const _themeModes = [
    (ThemeMode.system, Icons.brightness_auto, '跟随系统'),
    (ThemeMode.light, Icons.light_mode, '浅色模式'),
    (ThemeMode.dark, Icons.dark_mode, '深色模式'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('界面设置'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildSectionHeader(colors, '主题模式'.tr),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < _themeModes.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _ThemeCard(
                    colors: colors,
                    mode: _themeModes[i].$1,
                    icon: _themeModes[i].$2,
                    label: _themeModes[i].$3.tr,
                    selected: provider.themeMode == _themeModes[i].$1,
                    onTap: () => context
                        .read<AppProvider>()
                        .setThemeMode(_themeModes[i].$1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          _buildSectionHeader(colors, '配色方案'.tr),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: AppTheme.seedColors.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _MonetColorCard(colors: colors, provider: provider);
              }
              final index = i - 1;
              return _SeedColorCard(
                colors: colors,
                seed: AppTheme.seedColors[index],
                name: AppTheme.colorSchemeNames[index].tr,
                selected: provider.colorSchemeIndex == index,
                onTap: () =>
                    context.read<AppProvider>().setColorScheme(index),
              );
            },
          ),
          const SizedBox(height: 22),
          _buildSectionHeader(colors, '字体'.tr),
          _FontCard(colors: colors, provider: provider),
        ],
      ),
    );
  }

  /// 分区小标题：与设置页 _buildSectionHeader 同一风格
  Widget _buildSectionHeader(ColorScheme colors, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.6))),
    );
  }
}

/// 主题模式卡片：明暗迷你预览 + 图标 + 名称，选中=primary 淡色底 + primary 描边
class _ThemeCard extends StatelessWidget {
  final ColorScheme colors;
  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.colors,
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.5 : 0.5),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                _ThemePreview(mode: mode),
                if (selected)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                          color: colors.primary, shape: BoxShape.circle),
                      child: Icon(Icons.check,
                          size: 12, color: colors.onPrimary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Icon(icon,
                size: 18,
                color: selected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: colors.onSurface)),
          ],
        ),
      ),
    );
  }
}

/// 主题预览框：用固定示意色模拟浅色 / 深色 / 系统（左右对半）界面
class _ThemePreview extends StatelessWidget {
  final ThemeMode mode;
  const _ThemePreview({required this.mode});

  static const _lightBg = Color(0xFFF1F2F6);
  static const _darkBg = Color(0xFF26272B);
  static const _lightBar = Color(0xFFD8DAE0);
  static const _darkBar = Color(0xFF45474D);

  Widget _half(bool light, Color accent) {
    final bar = light ? _lightBar : _darkBar;
    return Container(
      color: light ? _lightBg : _darkBg,
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(width: 5),
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
              width: double.infinity,
              height: 4,
              decoration: BoxDecoration(
                  color: bar, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: 0.65,
            child: Container(
                height: 4,
                decoration: BoxDecoration(
                    color: bar, borderRadius: BorderRadius.circular(2))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mode == ThemeMode.system
            ? Row(
                children: [
                  Expanded(child: _half(true, accent)),
                  Expanded(child: _half(false, accent)),
                ],
              )
            : _half(mode == ThemeMode.light, accent),
      ),
    );
  }
}

/// 种子配色卡片：紧凑横条，三个小色点 + 名称，选中=种子色描边
class _SeedColorCard extends StatelessWidget {
  final ColorScheme colors;
  final Color seed;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _SeedColorCard({
    required this.colors,
    required this.seed,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? seed.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? seed
                  : colors.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(scheme.primary),
            const SizedBox(width: 4),
            _dot(scheme.secondary),
            const SizedBox(width: 4),
            _dot(scheme.tertiary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: colors.onSurface)),
            ),
            if (selected) ...[
              const SizedBox(width: 3),
              Icon(Icons.check_circle, size: 14, color: seed),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

/// 莫奈取色卡片：与种子卡同构的紧凑横条，渐变色点 + 名称
class _MonetColorCard extends StatelessWidget {
  final ColorScheme colors;
  final AppProvider provider;

  const _MonetColorCard({required this.colors, required this.provider});

  @override
  Widget build(BuildContext context) {
    final selected = provider.colorSchemeIndex == -1;
    final monetColor = AppTheme.monetColor;
    final available = monetColor != null;
    final accent = monetColor ?? colors.primary;
    return Opacity(
      opacity: available ? 1 : 0.4,
      child: GestureDetector(
        onTap: available
            ? () => context.read<AppProvider>().setColorScheme(-1)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? accent
                    : colors.outlineVariant.withValues(alpha: 0.7),
                width: selected ? 1.5 : 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: available
                      ? LinearGradient(colors: [
                          monetColor,
                          monetColor.withValues(alpha: 0.6),
                        ])
                      : null,
                  color: available ? null : colors.outlineVariant,
                ),
                child: available
                    ? null
                    : Icon(Icons.auto_awesome,
                        size: 9,
                        color: colors.onSurface.withValues(alpha: 0.35)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('莫奈取色'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: colors.onSurface)),
              ),
              if (selected) ...[
                const SizedBox(width: 3),
                Icon(Icons.check_circle, size: 14, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 字体入口卡片：与设置页导航项一致的图标盒 + 标题副标题 + 箭头
class _FontCard extends StatelessWidget {
  final ColorScheme colors;
  final AppProvider provider;

  const _FontCard({required this.colors, required this.provider});

  @override
  Widget build(BuildContext context) {
    final label =
        provider.fontFamily.isEmpty ? '系统默认'.tr : provider.fontFamily;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.font_download_outlined,
                  size: 20, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('字体'.tr,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              colors.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

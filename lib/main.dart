import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';
import 'pages/home_page.dart';
import 'utils/theme/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'utils/changelog_service.dart';
import 'utils/sync/auto_backup_service.dart';
import 'utils/usage_stats_service.dart';
import 'providers/app_provider.dart';
import 'providers/note_plus_provider.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPrefs.init();
  final appProvider = AppProvider();
  runApp(MyApp(appProvider: appProvider));

  unawaited(_bootstrap(appProvider));
}

/// 启动后台任务：先校验同步状态，再按顺序初始化数据库与主标签，
/// 保持 UI 先渲染、数据后就绪。
Future<void> _bootstrap(AppProvider appProvider) async {
  // 数据库优先初始化（不被 sync 阻塞）
  try {
    await appProvider.initDatabase();
  } catch (e) {
    debugPrint('[Startup] 数据库初始化失败: $e');
  }
  appProvider.initMainTabIndex();

  unawaited(_initAutoBackup());
  unawaited(_initUsageStats());
}

Future<void> _initAutoBackup() async {
  try {
    final isLocalAutoBackupEnabled = await AutoBackupService.instance.getEnabled();
    if (isLocalAutoBackupEnabled) {
      await AutoBackupService.instance.start();
    }
  } catch (e) {
    debugPrint('初始化自动备份失败: $e');
  }
}

Future<void> _initUsageStats() async {
  try {
    await UsageStatsService.instance.start();
  } catch (e) {
    debugPrint('初始化用户统计失败: $e');
  }
}

class MyApp extends StatefulWidget {
  final AppProvider appProvider;
  const MyApp({super.key, required this.appProvider});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  ThemeMode? _lastAppliedTheme;
  bool _updateCheckDone = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.appProvider.loadThemeMode();
    widget.appProvider.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applySystemUI();
      _checkUpdate(); // 不阻塞，完成后自行弹窗
    });
  }

  /// 延迟到首页渲染后再检查版本更新，确保 context 已就绪
  Future<void> _checkUpdate() async {
    if (_updateCheckDone) return;
    _updateCheckDone = true;
    await Future.delayed(const Duration(milliseconds: 500));
    var ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    try {
      final hasUpdate = await ChangelogService.hasUpdate();
      if (!hasUpdate) return;
      final latestVersion = await ChangelogService.fetchLatestVersion();
      if (latestVersion == null) return;
      final dismissed = UserPrefs().dismissedVersion;
      if (dismissed == latestVersion) return;
      ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      _showUpdateDialog(ctx, latestVersion);
    } catch (_) {}
  }

  void _showUpdateDialog(BuildContext context, String version) {
    if (!context.mounted) return;
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('新版本 $version 已发布，是否下载更新？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () {
              UserPrefs().setDismissedVersion(version);
              Navigator.pop(ctx);
            },
            child: Text('不再显示', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await launchUrl(Uri.parse('https://mooknote.iletter.top/#/'),
                    mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('链接失效')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('去官网下载'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _onThemeChanged() {
    final current = widget.appProvider.themeMode;
    if (_lastAppliedTheme != current) {
      _applySystemUI();
    }
  }

  void _applySystemUI() {
    final mode = widget.appProvider.themeMode;
    final Brightness brightness;
    switch (mode) {
      case ThemeMode.light:  brightness = Brightness.light;
      case ThemeMode.dark:   brightness = Brightness.dark;
      case ThemeMode.system: brightness = PlatformDispatcher.instance.platformBrightness;
    }
    _lastAppliedTheme = mode;
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? Colors.black : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applySystemUI();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appProvider),
        ChangeNotifierProvider(create: (_) => NotePlusProvider()),
      ],
      child: DynamicColorBuilder(
        builder: (lightScheme, darkScheme) {
          final monetColor = lightScheme?.primary;
          AppTheme.setMonetColor(monetColor);

          return Consumer<AppProvider>(
            builder: (context, provider, _) {
              AppTheme.setFontFamily(provider.fontFamily);
              final light = AppTheme.getLightTheme(
                provider.colorSchemeIndex,
                monetColor: monetColor,
              );
              ThemeData dark;
              if (provider.colorSchemeIndex == -1 && monetColor != null) {
                final scheme = ColorScheme.fromSeed(
                  seedColor: monetColor,
                  brightness: Brightness.dark,
                );
                dark = ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                  colorScheme: scheme,
                  scaffoldBackgroundColor: scheme.surface,
                  appBarTheme: AppBarTheme(
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.onSurface,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                  ),
                  cardTheme: CardThemeData(
                    color: scheme.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              } else {
                dark = AppTheme.darkTheme;
              }

              final child = MaterialApp(
                title: 'MookNote',
                debugShowCheckedModeBanner: false,
                theme: light,
                darkTheme: dark,
                themeMode: provider.themeMode,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  quill.FlutterQuillLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('zh', 'CN'),
                  Locale('en', 'US'),
                ],
                home: const HomePage(),
                navigatorKey: _navigatorKey,
                navigatorObservers: [routeObserver],
                onGenerateRoute: AppRouter.generateRoute,
              );

              return child;
            },
          );
        },
      ),
    );
  }
}

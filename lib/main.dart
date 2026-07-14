import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home/home_page.dart';
import 'utils/theme/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'services/changelog_service.dart';
import 'services/usage_stats_service.dart';
import 'providers/app_provider.dart';
import 'widgets/app_shell.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

/// Windows 桌面版 WebView2 环境，注册 epub:// 自定义协议
WebViewEnvironment? windowsWebViewEnvironment;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows 桌面：使用 FFI 初始化 sqflite
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 初始化 window_manager：隐藏原生标题栏
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setMinimumSize(const Size(900, 640));
      await windowManager.show();
    });
    // 注册 epub:// 自定义协议，使 WebView2 能拦截该协议的请求
    try {
      windowsWebViewEnvironment = await WebViewEnvironment.create(settings:
        WebViewEnvironmentSettings(customSchemeRegistrations: [
          CustomSchemeRegistration(
            scheme: 'epub',
            hasAuthorityComponent: true,
            treatAsSecure: true,
          ),
        ]),
      );
      debugPrint('[Startup] WebViewEnvironment created successfully');
    } catch (e) {
      debugPrint('[Startup] WebViewEnvironment 初始化失败: $e');
    }
  }
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
    appProvider.markDbInitFailed();
  }
  appProvider.initMainTabIndex();

  unawaited(_initUsageStats());
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
      final items = await ChangelogService.fetchChangelog();
      if (items.isEmpty) return;
      final latest = items.first;
      final info = await PackageInfo.fromPlatform();
      final localVersion = 'v${info.version}';
      if (ChangelogService.compareVersion(latest.version, localVersion) <= 0) return;
      // 24 小时内 snooze 不弹
      if (DateTime.now().millisecondsSinceEpoch < UserPrefs().dismissedUpdateUntil) return;
      ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      _showUpdateDialog(ctx, latest.version, latest.features, localVersion);
    } catch (_) {}
  }

  void _showUpdateDialog(BuildContext context, String version, List<String> features, String localVersion) {
    if (!context.mounted) return;
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.system_update, size: 22, color: colors.primary),
            const SizedBox(width: 8),
            Text('发现新版本', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本：$localVersion',
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                const SizedBox(height: 4),
                Text('最新版本：$version',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary)),
                if (features.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('更新内容', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(height: 8),
                  ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7), height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final until = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
              UserPrefs().setDismissedUpdateUntil(until);
              Navigator.pop(ctx);
            },
            child: Text('24小时内不显示', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
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
    // Windows: 同步窗口边框明暗
    if (Platform.isWindows) {
      windowManager.setBrightness(isDark ? Brightness.dark : Brightness.light);
    }
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
                builder: (ctx, nav) => AppShell(child: nav!),
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
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

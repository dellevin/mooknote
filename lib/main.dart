import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'utils/theme/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'utils/sync/auto_backup_service.dart';
import 'utils/sync/server_sync_service.dart';
import 'utils/usage_stats_service.dart';
import 'providers/app_provider.dart';

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

  // sync 校验在数据库加载完成后执行（避免阻塞本地数据展示）
  try {
    await _validateSyncOnStartup();
  } catch (e) {
    debugPrint('[Startup] 同步状态校验失败: $e');
  }

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
    print('初始化自动备份失败: $e');
  }
}

Future<void> _initUsageStats() async {
  try {
    await UsageStatsService.instance.start();
  } catch (e) {
    print('初始化用户统计失败: $e');
  }
}

/// 启动时校验同步激活码：有效则继续，过期/失效则下载数据并关闭同步
Future<void> _validateSyncOnStartup() async {
  try {
    final prefs = UserPrefs();
    if (!prefs.syncEnabled || prefs.syncServerUrl.isEmpty || prefs.syncActivationCode.isEmpty) {
      return; // 未开启同步，跳过
    }

    debugPrint('[Startup] 校验同步激活码...');
    final result = await ServerSyncService.instance.checkActivation();

    if (result != null && result['valid'] == true) {
      // 激活码有效，更新有效期信息
      await prefs.setSyncExpiresAt(result['expires_at'] ?? '');
      await prefs.setSyncIsPermanent(result['is_permanent'] == true);
      debugPrint('[Startup] 激活码有效，继续同步模式');
    } else {
      // 激活码无效/过期，下载服务端数据并关闭同步
      debugPrint('[Startup] 激活码失效: ${result?['error'] ?? '未知'}，关闭同步并下载数据');
      await ServerSyncService.instance.downloadToLocal();
      await prefs.setSyncEnabled(false);
      debugPrint('[Startup] 已切换到本地模式');
    }
  } catch (e) {
    debugPrint('[Startup] 激活码校验异常: $e');
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.appProvider.loadThemeMode();
    widget.appProvider.addListener(_onThemeChanged);
    // 延迟到首帧后确保生效
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySystemUI());
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
    final iconName = UserPrefs().appIconName;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appProvider),
      ],
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'MookNote',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: provider.themeMode,
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            home: const HomePage(),
            onGenerateRoute: AppRouter.generateRoute,
            builder: (context, child) {
              return _AppIconWrapper(iconName: iconName, child: child!);
            },
          );
        },
      ),
    );
  }
}

class _AppIconWrapper extends StatefulWidget {
  final Widget child;
  final String iconName;
  const _AppIconWrapper({required this.child, required this.iconName});

  @override
  State<_AppIconWrapper> createState() => _AppIconWrapperState();
}

class _AppIconWrapperState extends State<_AppIconWrapper> {
  @override
  void initState() {
    super.initState();
    _updateSystemIcon();
  }

  Future<void> _updateSystemIcon() async {}

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

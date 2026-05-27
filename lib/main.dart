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
import 'utils/usage_stats_service.dart';
import 'providers/app_provider.dart';
import 'package:flutter/widget_previews.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserPrefs.init();
  final appProvider = AppProvider();
  runApp(MyApp(appProvider: appProvider));
  unawaited(appProvider.initDatabase().then((_) => appProvider.initMainTabIndex()));
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

@Preview(name: "MookNote App Preview")
Widget previewMyApp() {
  final appProvider = AppProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: appProvider),
    ],
    child: MyApp(appProvider: appProvider),
  );
}

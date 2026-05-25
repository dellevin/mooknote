import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'pages/home_page.dart';
import 'utils/theme/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'utils/sync/auto_backup_service.dart';
import 'utils/usage_stats_service.dart';
import 'providers/app_provider.dart';
import 'package:flutter/widget_previews.dart';

void main() async {
  // 确保 Flutter 绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置系统导航栏颜色（与App主题一致）
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 初始化用户偏好设置
  await UserPrefs.init();
  final appProvider = AppProvider();
  // 先显示界面，后台加载数据
  runApp(MyApp(appProvider: appProvider));
  unawaited(appProvider.initDatabase().then((_) => appProvider.initMainTabIndex()));
  unawaited(_initAutoBackup());
  unawaited(_initUsageStats());
}

/// 初始化自动备份
Future<void> _initAutoBackup() async {
  try {
    // 初始化本地自动备份
    final isLocalAutoBackupEnabled = await AutoBackupService.instance.getEnabled();
    if (isLocalAutoBackupEnabled) {
      await AutoBackupService.instance.start();
    }
  } catch (e) {
    print('初始化自动备份失败: $e');
  }
}

/// 初始化匿名用户统计
Future<void> _initUsageStats() async {
  try {
    await UsageStatsService.instance.start();
  } catch (e) {
    print('初始化用户统计失败: $e');
  }
}

class MyApp extends StatelessWidget {
  final AppProvider appProvider;
  
  const MyApp({super.key, required this.appProvider});

  @override
  Widget build(BuildContext context) {
    // 获取当前选中的图标名称
    final iconName = UserPrefs().appIconName;
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
      ],
      child: MaterialApp(
        title: 'MookNote',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
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
          // 尝试动态设置应用图标（Android 13+ 支持动态图标，但 Flutter 目前主要通过静态配置）
          // 这里我们主要实现逻辑上的切换，实际生效通常需要重启应用或配合原生插件
          return _AppIconWrapper(iconName: iconName, child: child!);
        },
      ),
    );
  }
}

/// 应用图标包装器
/// 注意：Flutter 默认不支持运行时动态更换桌面图标。
/// 这里的实现主要是为了在应用内记录用户的选择，并为未来可能的动态图标功能做准备。
/// 如果需要真正的动态图标，通常需要引入 flutter_app_icon_changer 等插件并配置多套图标资源。
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

  Future<void> _updateSystemIcon() async {
    // 目前 Flutter 官方不支持直接通过代码更换 Launcher Icon。
    // 这一步主要用于记录日志或在未来集成第三方库时使用。
    // print('Current selected icon: ${widget.iconName}');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 用于预览 MyApp 的 Widget
/// 添加 @Preview 注解
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
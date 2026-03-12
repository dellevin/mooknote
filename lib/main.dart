import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'utils/theme/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'utils/sync/auto_backup_service.dart';
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
  // 初始化数据库
  final appProvider = AppProvider();
  await appProvider.initDatabase();
  // 检查并恢复本地自动备份
  await _initAutoBackup();
  runApp(MyApp(appProvider: appProvider));
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

class MyApp extends StatelessWidget {
  final AppProvider appProvider;
  
  const MyApp({super.key, required this.appProvider});

  @override
  Widget build(BuildContext context) {
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
        home: const HomePage(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
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
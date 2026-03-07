import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'utils/app_theme.dart';
import 'utils/app_router.dart';
import 'utils/user_prefs.dart';
import 'utils/webdav_service.dart';
import 'providers/app_provider.dart';

void main() async {
  // 确保 Flutter 绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化用户偏好设置
  await UserPrefs.init();
  
  // 初始化数据库
  final appProvider = AppProvider();
  await appProvider.initDatabase();
  
  // 检查并恢复自动备份
  await _initAutoBackup();
  
  runApp(MyApp(appProvider: appProvider));
}

/// 初始化自动备份
Future<void> _initAutoBackup() async {
  try {
    final isEnabled = await WebDAVService.instance.isAutoSyncEnabled();
    if (isEnabled) {
      await WebDAVService.instance.startAutoSync();
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

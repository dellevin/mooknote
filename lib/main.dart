import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'utils/app_theme.dart';
import 'utils/app_router.dart';
import 'providers/app_provider.dart';

void main() async {
  // 确保 Flutter 绑定初始化完成
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化数据库
  final appProvider = AppProvider();
  await appProvider.initDatabase();
  
  runApp(MyApp(appProvider: appProvider));
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

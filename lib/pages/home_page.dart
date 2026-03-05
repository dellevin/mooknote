import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'main_content_page.dart';
import 'profile_page.dart';

/// 主页 - 包含底部导航，可切换主页/我的
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 左侧弹出菜单（仅在主页显示）
      drawer: context.watch<AppProvider>().bottomNavIndex == 0 
          ? const CustomDrawer() 
          : null,
      
      // 主体内容 - 根据底部导航切换
      body: _buildBody(),
      
      // 底部导航栏
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  /// 构建主体内容
  Widget _buildBody() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        switch (provider.bottomNavIndex) {
          case 0:
            // 主页 - 观影/阅读/笔记
            return const MainContentPage();
          case 2:
            // 我的页面
            return const ProfilePage();
          default:
            return const MainContentPage();
        }
      },
    );
  }
}

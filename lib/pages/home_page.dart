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
          ? CustomDrawer() 
          : null,
      
      // 主体内容 - 使用 Stack 让 dock 栏悬浮在内容上方
      body: Stack(
        children: [
          // 底层：主体内容
          _buildBody(),
          
          // 顶层：悬浮 dock 栏
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNavBar(),
          ),
        ],
      ),
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

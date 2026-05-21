import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
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
  /// 当前正在滑动的页面索引（用于PageView）
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 左侧弹出菜单（仅在主页显示）
      drawer: context.watch<AppProvider>().bottomNavIndex == 0
          ? CustomDrawer()
          : null,

      // 主体内容
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          // 同步底部导航栏和 PageView 的页面
          final currentPage = provider.bottomNavIndex == 0 ? 0 : 1;
          if (_pageController.hasClients && _pageController.page?.round() != currentPage) {
            _pageController.jumpToPage(currentPage);
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta;
                if (delta != null && delta.abs() > 2) {
                  // 根据用户设置决定是否启用滚动隐藏
                  final userPrefs = UserPrefs();
                  if (!userPrefs.hideBottomNavOnScroll) return false;
                  if (delta < 0) {
                    // 下拉（内容向下滚动）- 显示导航栏
                    provider.setBottomNavVisible(true);
                  } else {
                    // 上滑（内容向上滚动）- 隐藏导航栏
                    provider.setBottomNavVisible(false);
                  }
                }
              }
              return false;
            },
            child: Stack(
              children: [
                // 底层：主体内容（支持左右滑动切换）
                _buildPageView(provider),

                // 底部导航栏（带动画）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    offset: provider.bottomNavVisible ? Offset.zero : const Offset(-1, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: const CustomBottomNavBar(),
                  ),
                ),

                // 导航栏隐藏时的展开按钮
                if (!provider.bottomNavVisible)
                  Positioned(
                    left: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    child: GestureDetector(
                      onTap: () => provider.setBottomNavVisible(true),
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 0) {
                          provider.setBottomNavVisible(true);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Color(0xFF999999),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建主体内容（使用 PageView 支持左右滑动切换）
  Widget _buildPageView(AppProvider provider) {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (index) {
        if (index == 0) {
          provider.setBottomNavIndex(0);
        } else if (index == 1) {
          provider.setBottomNavIndex(2);
        }
      },
      children: [
        const MainContentPage(),
        const ProfilePage(),
      ],
    );
  }
}

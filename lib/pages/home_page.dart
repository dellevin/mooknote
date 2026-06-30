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
  final PageController _pageController = PageController();
  bool _isSwitchingPage = false;
  int _lastNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastNavIndex = context.read<AppProvider>().bottomNavIndex;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavIndexChanged(AppProvider provider) {
    final currentPage = provider.bottomNavIndex == 0 ? 0 : 1;
    if (currentPage == _lastNavIndex) return;
    _lastNavIndex = currentPage;

    if (!_pageController.hasClients) return;
    if (_pageController.page?.round() == currentPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isSwitchingPage = true;
      _pageController.jumpToPage(currentPage);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isSwitchingPage = false;
          provider.setBottomNavVisible(true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: context.watch<AppProvider>().bottomNavIndex != 1
          ? const CustomDrawer()
          : null,

      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          _onNavIndexChanged(provider);

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_isSwitchingPage) return false;
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta;
                if (delta != null && delta.abs() > 2) {
                  final userPrefs = UserPrefs();
                  if (!userPrefs.hideBottomNavOnScroll) return false;
                  if (delta < 0) {
                    provider.setBottomNavVisible(true);
                  } else {
                    provider.setBottomNavVisible(false);
                  }
                }
              }
              return false;
            },
            child: Stack(
              children: [
                _buildPageView(provider),

                // 底部导航栏区域
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    offset: provider.bottomNavVisible
                        ? Offset.zero
                        : const Offset(-1, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: const CustomBottomNavBar(),
                  ),
                ),

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
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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

  Widget _buildPageView(AppProvider provider) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
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

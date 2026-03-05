import 'package:flutter/material.dart';

class AppTheme {
  // 主色调
  static const Color primaryColor = Color(0xFF6200EE);
  static const Color secondaryColor = Color(0xFF03DAC6);
  
  // 状态颜色
  static const Color watchedColor = Color(0xFF4CAF50);  // 已看 - 绿色
  static const Color wantToWatchColor = Color(0xFFFF9800);  // 想看 - 橙色
  static const Color watchingColor = Color(0xFF2196F3);  // 在看 - 蓝色
  
  static const Color readColor = Color(0xFF4CAF50);  // 读完 - 绿色
  static const Color wantToReadColor = Color(0xFFFF9800);  // 准备读 - 橙色
  static const Color readingColor = Color(0xFF2196F3);  // 在读 - 蓝色

  // 亮色主题
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 8,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
    ),
  );

  // 暗色主题
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 8,
      selectedItemColor: secondaryColor,
      unselectedItemColor: Colors.grey,
    ),
  );
}

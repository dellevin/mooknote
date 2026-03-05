import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 极简主义主题配置
class AppTheme {
  // 中性色板 - 黑白灰为主
  static const Color _black = Color(0xFF1A1A1A);
  static const Color _darkGray = Color(0xFF333333);
  static const Color _gray = Color(0xFF666666);
  static const Color _lightGray = Color(0xFF999999);
  static const Color _lighterGray = Color(0xFFE5E5E5);
  static const Color _offWhite = Color(0xFFF5F5F5);
  static const Color _white = Color(0xFFFFFFFF);
  
  // 强调色 - 仅用于关键操作
  static const Color accent = Color(0xFF0066FF);
  static const Color error = Color(0xFFDC2626);
  
  // 观影状态颜色 - 极简处理
  static const Color watched = Color(0xFF1A1A1A);      // 已看 - 纯黑
  static const Color wantToWatch = Color(0xFF999999);  // 想看 - 浅灰
  static const Color watching = Color(0xFF666666);     // 在看 - 中灰
  
  // 阅读状态颜色 - 极简处理
  static const Color readColor = Color(0xFF1A1A1A);      // 已读 - 纯黑
  static const Color wantToReadColor = Color(0xFF999999); // 想读 - 浅灰
  static const Color readingColor = Color(0xFF666666);    // 在读 - 中灰

  // 字体配置
  static const String _fontFamily = 'Inter';
  
  // 字重
  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;
  static const FontWeight _semibold = FontWeight.w600;

  // 亮色主题 - 极简主义
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _white,
      
      // 颜色方案
      colorScheme: const ColorScheme.light(
        primary: _black,
        onPrimary: _white,
        secondary: _darkGray,
        onSecondary: _white,
        surface: _white,
        onSurface: _black,
        error: error,
        onError: _white,
      ),
      
      // AppBar - 极简无边框
      appBarTheme: const AppBarTheme(
        backgroundColor: _white,
        foregroundColor: _black,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: _semibold,
          color: _black,
          letterSpacing: -0.3,
        ),
      ),
      
      // 卡片 - 无阴影，细边框
      cardTheme: CardThemeData(
        color: _white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: _lighterGray, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      
      // 列表瓦片
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minLeadingWidth: 0,
        dense: true,
      ),
      
      // 分割线 - 极细
      dividerTheme: DividerThemeData(
        color: _lighterGray,
        thickness: 0.5,
        space: 0,
      ),
      
      // 输入框 - 无边框，底部线
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: _lighterGray, width: 0.5),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _lighterGray, width: 0.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _black, width: 1),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: error, width: 0.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: _regular,
          color: _lightGray,
        ),
        labelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: _medium,
          color: _gray,
        ),
      ),
      
      // 按钮 - 文字按钮为主
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _black,
          foregroundColor: _white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: _medium,
            letterSpacing: 0.3,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _black,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: _medium,
          ),
        ),
      ),
      
      // 底部导航
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _white,
        selectedItemColor: _black,
        unselectedItemColor: _lightGray,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: _medium,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: _regular,
        ),
      ),
      
      // 文字主题
      textTheme: const TextTheme(
        // 大标题
        headlineLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 32,
          fontWeight: _semibold,
          color: _black,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 24,
          fontWeight: _semibold,
          color: _black,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 20,
          fontWeight: _semibold,
          color: _black,
          letterSpacing: -0.2,
          height: 1.4,
        ),
        // 正文
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: _regular,
          color: _darkGray,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: _regular,
          color: _darkGray,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: _regular,
          color: _gray,
          height: 1.5,
        ),
        // 标签
        labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 14,
          fontWeight: _medium,
          color: _black,
        ),
        labelMedium: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 12,
          fontWeight: _medium,
          color: _gray,
        ),
        labelSmall: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 11,
          fontWeight: _medium,
          color: _lightGray,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // 暗色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _black,
      
      colorScheme: const ColorScheme.dark(
        primary: _white,
        onPrimary: _black,
        secondary: _offWhite,
        onSecondary: _black,
        surface: _black,
        onSurface: _white,
        error: Color(0xFFEF4444),
        onError: _black,
      ),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: _black,
        foregroundColor: _white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 18,
          fontWeight: _semibold,
          color: _white,
          letterSpacing: -0.3,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: _darkGray,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        margin: EdgeInsets.zero,
      ),
      
      dividerTheme: DividerThemeData(
        color: _darkGray,
        thickness: 0.5,
        space: 0,
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: _darkGray, width: 0.5),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _darkGray, width: 0.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _white, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
        hintStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 15,
          fontWeight: _regular,
          color: _gray,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _white,
          foregroundColor: _black,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _black,
        selectedItemColor: _white,
        unselectedItemColor: _gray,
        elevation: 0,
      ),
    );
  }
}

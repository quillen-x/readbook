import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/app_settings.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'AlibabaPuHuiTi';

  /// 界面无衬线字体回退（macOS 优先苹方）
  static const List<String> sansFallback = [
    'PingFang SC',
    'Heiti SC',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// 衬线字体（书籍、长文标题）
  static const List<String> serifFallback = [
    'Songti SC',
    'STSong',
    'Georgia',
    'serif',
  ];

  /// 等宽字体（代码、日志）
  static const List<String> monoFallback = [
    'Menlo',
    'Monaco',
    'Courier New',
    'monospace',
  ];

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        seedColor: const Color(0xFF6B4F3A),
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        seedColor: const Color(0xFFD4B896),
      );

  /// 护眼主题：暖色低对比，减轻长时间使用的视觉疲劳。
  static ThemeData get eyeCare {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF7A6348),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8DCC8),
      onPrimaryContainer: Color(0xFF3D3224),
      secondary: Color(0xFF6B5A42),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFDDD2BC),
      onSecondaryContainer: Color(0xFF3D3224),
      tertiary: Color(0xFF5C6B4A),
      onTertiary: Color(0xFFFFFFFF),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      surface: Color(0xFFF5F0E6),
      onSurface: Color(0xFF3C3226),
      onSurfaceVariant: Color(0xFF6B5F4F),
      outline: Color(0xFF9A8E7E),
      outlineVariant: Color(0xFFD4C9B8),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF3C3226),
      onInverseSurface: Color(0xFFF5F0E6),
      inversePrimary: Color(0xFFD4B896),
      surfaceTint: Color(0xFF7A6348),
      surfaceContainerHighest: Color(0xFFE8E0D2),
      surfaceContainerHigh: Color(0xFFEDE6D8),
      surfaceContainer: Color(0xFFF0EBE1),
      surfaceContainerLow: Color(0xFFF3EEE4),
      surfaceContainerLowest: Color(0xFFFAF7F0),
    );

    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: sansFallback,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [AppTextStyles.from(colorScheme)],
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleMedium,
        toolbarHeight: 44.h,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: textTheme.bodySmall,
      ),
    );
  }

  static ThemeData themeFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return light;
      case AppThemeMode.dark:
        return dark;
      case AppThemeMode.eyeCare:
        return eyeCare;
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final textTheme = _buildTextTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: sansFallback,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [AppTextStyles.from(colorScheme)],
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleMedium,
        toolbarHeight: 44.h,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: textTheme.bodySmall,
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    final base = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: sansFallback,
      color: colorScheme.onSurface,
    );

    return TextTheme(
      headlineSmall: base.copyWith(fontSize: 18.sp, fontWeight: FontWeight.w600),
      titleLarge: base.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
      titleMedium: base.copyWith(fontSize: 14.sp, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 14.sp),
      bodyMedium: base.copyWith(fontSize: 13.sp),
      bodySmall: base.copyWith(
        fontSize: 12.sp,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: base.copyWith(fontSize: 13.sp, fontWeight: FontWeight.w600),
      labelMedium: base.copyWith(
        fontSize: 12.sp,
        color: colorScheme.onSurfaceVariant,
      ),
      labelSmall: base.copyWith(fontSize: 11.sp),
    );
  }
}

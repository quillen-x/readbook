import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'app_theme.dart';

@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.sidebarTag,
    required this.sidebarTagSelected,
    required this.sidebarEmpty,
    required this.errorBanner,
    required this.bottomBarMeta,
    required this.bottomBarPage,
    required this.batchProgress,
    required this.batchLog,
  });

  final TextStyle sidebarTag;
  final TextStyle sidebarTagSelected;
  final TextStyle sidebarEmpty;
  final TextStyle errorBanner;
  final TextStyle bottomBarMeta;
  final TextStyle bottomBarPage;
  final TextStyle batchProgress;
  final TextStyle batchLog;

  static AppTextStyles from(ColorScheme colorScheme) {
    TextStyle sans({
      double? fontSize,
      FontWeight? fontWeight,
      Color? color,
      double? height,
    }) {
      return TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontFamilyFallback: AppTheme.sansFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? colorScheme.onSurface,
        height: height,
      );
    }

    return AppTextStyles(
      sidebarTag: sans(
        fontSize: 12.sp,
        color: colorScheme.onSurfaceVariant,
      ),
      sidebarTagSelected: sans(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: colorScheme.primary,
      ),
      sidebarEmpty: sans(
        fontSize: 12.sp,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      errorBanner: sans(
        fontSize: 12.sp,
        color: colorScheme.error,
      ),
      bottomBarMeta: sans(
        fontSize: 12.sp,
        color: colorScheme.onSurfaceVariant,
      ),
      bottomBarPage: sans(
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      ),
      batchProgress: sans(fontSize: 12.sp),
      batchLog: sans(
        fontSize: 11.sp,
        color: colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }

  @override
  AppTextStyles copyWith({
    TextStyle? sidebarTag,
    TextStyle? sidebarTagSelected,
    TextStyle? sidebarEmpty,
    TextStyle? errorBanner,
    TextStyle? bottomBarMeta,
    TextStyle? bottomBarPage,
    TextStyle? batchProgress,
    TextStyle? batchLog,
  }) {
    return AppTextStyles(
      sidebarTag: sidebarTag ?? this.sidebarTag,
      sidebarTagSelected: sidebarTagSelected ?? this.sidebarTagSelected,
      sidebarEmpty: sidebarEmpty ?? this.sidebarEmpty,
      errorBanner: errorBanner ?? this.errorBanner,
      bottomBarMeta: bottomBarMeta ?? this.bottomBarMeta,
      bottomBarPage: bottomBarPage ?? this.bottomBarPage,
      batchProgress: batchProgress ?? this.batchProgress,
      batchLog: batchLog ?? this.batchLog,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      sidebarTag: TextStyle.lerp(sidebarTag, other.sidebarTag, t)!,
      sidebarTagSelected:
          TextStyle.lerp(sidebarTagSelected, other.sidebarTagSelected, t)!,
      sidebarEmpty: TextStyle.lerp(sidebarEmpty, other.sidebarEmpty, t)!,
      errorBanner: TextStyle.lerp(errorBanner, other.errorBanner, t)!,
      bottomBarMeta: TextStyle.lerp(bottomBarMeta, other.bottomBarMeta, t)!,
      bottomBarPage: TextStyle.lerp(bottomBarPage, other.bottomBarPage, t)!,
      batchProgress: TextStyle.lerp(batchProgress, other.batchProgress, t)!,
      batchLog: TextStyle.lerp(batchLog, other.batchLog, t)!,
    );
  }
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get appText =>
      Theme.of(this).extension<AppTextStyles>() ??
      AppTextStyles.from(Theme.of(this).colorScheme);
}

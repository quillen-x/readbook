import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, eyeCare }

extension AppThemeModeX on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.light:
        return '亮色';
      case AppThemeMode.dark:
        return '暗色';
      case AppThemeMode.eyeCare:
        return '护眼';
    }
  }
}

enum ReaderThemeMode { light, sepia, dark }

extension ReaderThemeModeX on ReaderThemeMode {
  String get label {
    switch (this) {
      case ReaderThemeMode.light:
        return '白色';
      case ReaderThemeMode.sepia:
        return '护眼';
      case ReaderThemeMode.dark:
        return '深色';
    }
  }

  Color get previewColor {
    switch (this) {
      case ReaderThemeMode.light:
        return const Color(0xFFFFFFF8);
      case ReaderThemeMode.sepia:
        return const Color(0xFFD4C4A8);
      case ReaderThemeMode.dark:
        return const Color(0xFF04060F);
    }
  }
}

enum ReaderFontFamily { alibabaPuHuiTi, pingFang, sourceHanSerif }

extension ReaderFontFamilyX on ReaderFontFamily {
  String get label {
    switch (this) {
      case ReaderFontFamily.alibabaPuHuiTi:
        return '阿里巴巴';
      case ReaderFontFamily.pingFang:
        return '苹方';
      case ReaderFontFamily.sourceHanSerif:
        return '思源宋体';
    }
  }

  String? get familyName {
    switch (this) {
      case ReaderFontFamily.alibabaPuHuiTi:
        return 'AlibabaPuHuiTi';
      case ReaderFontFamily.pingFang:
        return null;
      case ReaderFontFamily.sourceHanSerif:
        return null;
    }
  }
}

enum ReaderFontWeightOption {
  light(FontWeight.w300, '细'),
  regular(FontWeight.w400, '常规'),
  medium(FontWeight.w500, '中等'),
  semibold(FontWeight.w600, '半粗'),
  bold(FontWeight.w700, '粗');

  const ReaderFontWeightOption(this.weight, this.label);

  final FontWeight weight;
  final String label;
}

class AppSettings {
  const AppSettings({
    this.appThemeMode = AppThemeMode.light,
    this.themeMode = ReaderThemeMode.sepia,
    this.fontFamily = ReaderFontFamily.alibabaPuHuiTi,
    this.fontSize = 18,
    this.lineHeight = 1.65,
    this.fontWeight = ReaderFontWeightOption.regular,
    this.margin = ReaderMargin.normal,
    this.readerContentWidthPercent = 0.92,
    this.showTocPanel = false,
    this.homeBackgroundPath,
    this.homeBackgroundOpacity = 0.22,
    this.bookCardBackgroundOpacity = 0.5,
  });

  final AppThemeMode appThemeMode;
  final ReaderThemeMode themeMode;
  final ReaderFontFamily fontFamily;
  final double fontSize;
  final double lineHeight;
  final ReaderFontWeightOption fontWeight;
  final ReaderMargin margin;
  final double readerContentWidthPercent;
  final bool showTocPanel;
  final String? homeBackgroundPath;
  final double homeBackgroundOpacity;
  final double bookCardBackgroundOpacity;

  AppSettings copyWith({
    AppThemeMode? appThemeMode,
    ReaderThemeMode? themeMode,
    ReaderFontFamily? fontFamily,
    double? fontSize,
    double? lineHeight,
    ReaderFontWeightOption? fontWeight,
    ReaderMargin? margin,
    double? readerContentWidthPercent,
    bool? showTocPanel,
    String? homeBackgroundPath,
    bool clearHomeBackgroundPath = false,
    double? homeBackgroundOpacity,
    double? bookCardBackgroundOpacity,
  }) {
    return AppSettings(
      appThemeMode: appThemeMode ?? this.appThemeMode,
      themeMode: themeMode ?? this.themeMode,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontWeight: fontWeight ?? this.fontWeight,
      margin: margin ?? this.margin,
      readerContentWidthPercent:
          readerContentWidthPercent ?? this.readerContentWidthPercent,
      showTocPanel: showTocPanel ?? this.showTocPanel,
      homeBackgroundPath: clearHomeBackgroundPath
          ? null
          : (homeBackgroundPath ?? this.homeBackgroundPath),
      homeBackgroundOpacity: homeBackgroundOpacity ?? this.homeBackgroundOpacity,
      bookCardBackgroundOpacity:
          bookCardBackgroundOpacity ?? this.bookCardBackgroundOpacity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appThemeMode': appThemeMode.name,
      'themeMode': themeMode.name,
      'fontFamily': fontFamily.name,
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontWeight': fontWeight.name,
      'margin': margin.name,
      'readerContentWidthPercent': readerContentWidthPercent,
      'showTocPanel': showTocPanel,
      'homeBackgroundPath': homeBackgroundPath,
      'homeBackgroundOpacity': homeBackgroundOpacity,
      'bookCardBackgroundOpacity': bookCardBackgroundOpacity,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      appThemeMode: _enumByName(
        AppThemeMode.values,
        json['appThemeMode'] as String?,
        AppThemeMode.light,
      ),
      themeMode: _enumByName(
        ReaderThemeMode.values,
        json['themeMode'] as String?,
        ReaderThemeMode.sepia,
      ),
      fontFamily: _enumByName(
        ReaderFontFamily.values,
        json['fontFamily'] as String?,
        ReaderFontFamily.alibabaPuHuiTi,
      ),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.65,
      fontWeight: _enumByName(
        ReaderFontWeightOption.values,
        json['fontWeight'] as String?,
        ReaderFontWeightOption.regular,
      ),
      margin: _enumByName(
        ReaderMargin.values,
        json['margin'] as String?,
        ReaderMargin.normal,
      ),
      readerContentWidthPercent:
          (json['readerContentWidthPercent'] as num?)?.toDouble() ?? 0.92,
      showTocPanel: json['showTocPanel'] as bool? ?? false,
      homeBackgroundPath: json['homeBackgroundPath'] as String?,
      homeBackgroundOpacity:
          (json['homeBackgroundOpacity'] as num?)?.toDouble() ?? 0.22,
      bookCardBackgroundOpacity:
          (json['bookCardBackgroundOpacity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

T _enumByName<T extends Enum>(
  List<T> values,
  String? name,
  T fallback,
) {
  if (name == null) return fallback;
  return values.firstWhere(
    (value) => value.name == name,
    orElse: () => fallback,
  );
}

enum ReaderMargin { narrow, normal, wide }

extension ReaderMarginX on ReaderMargin {
  String get label {
    switch (this) {
      case ReaderMargin.narrow:
        return '窄';
      case ReaderMargin.normal:
        return '正常';
      case ReaderMargin.wide:
        return '宽';
    }
  }

  double get contentWidthPercent {
    switch (this) {
      case ReaderMargin.narrow:
        return 0.88;
      case ReaderMargin.normal:
        return 0.72;
      case ReaderMargin.wide:
        return 0.58;
    }
  }
}

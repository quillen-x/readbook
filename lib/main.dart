import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_messenger.dart';
import 'providers/app_providers.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

/// iPhone 17 Pro Max 逻辑分辨率
const Size kMobileDesignSize = Size(440, 956);

/// macOS 窗口尺寸
const Size kMacWindowSize = Size(491 * 1.5, 856);

bool get _isDesktop =>
    !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

Size get appDesignSize {
  if (!kIsWeb && Platform.isMacOS) return kMacWindowSize;
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    return kMacWindowSize;
  }
  return kMobileDesignSize;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  if (!kIsWeb && Platform.isMacOS) {
    await FilePicker.skipEntitlementsChecks();
  }

  if (_isDesktop) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: kMacWindowSize,
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setMinimumSize(kMacWindowSize);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const ProviderScope(child: ReadBookApp()));
}

class ReadBookApp extends ConsumerWidget {
  const ReadBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(appSettingsProvider).appThemeMode;

    return ScreenUtilInit(
      designSize: appDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: '读本书',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          theme: AppTheme.themeFor(appThemeMode),
          themeMode: ThemeMode.light,
          home: child,
        );
      },
      child: const AppShell(),
    );
  }
}


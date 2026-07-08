import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_messenger.dart';
import '../providers/app_providers.dart';
import '../services/settings_service.dart';

Future<void> pickHomeBackground(WidgetRef ref) async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    dialogTitle: '选择首页背景图',
  );

  if (result == null || result.files.isEmpty) return;

  final path = result.files.single.path;
  if (path == null) return;

  try {
    final settings = ref.read(appSettingsProvider);
    final savedPath = await SettingsService.instance.saveHomeBackground(path);
    await ref.read(appSettingsProvider.notifier).update(
          settings.copyWith(homeBackgroundPath: savedPath),
        );
    showAppSnackBar('首页背景已更新');
  } catch (error) {
    showAppSnackBar('设置背景失败: $error');
  }
}

Future<void> clearHomeBackground(WidgetRef ref) async {
  final settings = ref.read(appSettingsProvider);
  await SettingsService.instance.clearHomeBackground(settings.homeBackgroundPath);
  await ref.read(appSettingsProvider.notifier).update(
        settings.copyWith(clearHomeBackgroundPath: true),
      );
  showAppSnackBar('已清除首页背景');
}

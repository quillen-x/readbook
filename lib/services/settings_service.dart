import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _settingsFileName = 'settings.json';
  static const _homeBackgroundBaseName = 'home_background';

  static const _allowedImageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  Future<AppSettings> load() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return const AppSettings();
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(json);
      final backgroundPath = settings.homeBackgroundPath;
      if (backgroundPath != null && !File(backgroundPath).existsSync()) {
        return settings.copyWith(clearHomeBackgroundPath: true);
      }
      return settings;
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<String> saveHomeBackground(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    if (!_allowedImageExtensions.contains(extension)) {
      throw Exception('仅支持 JPG、PNG、WebP 图片');
    }

    final appDir = await getApplicationSupportDirectory();
    for (final ext in _allowedImageExtensions) {
      final existing = File(p.join(appDir.path, '$_homeBackgroundBaseName$ext'));
      if (await existing.exists()) {
        await existing.delete();
      }
    }

    final destPath = p.join(appDir.path, '$_homeBackgroundBaseName$extension');
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  Future<void> clearHomeBackground(String? currentPath) async {
    if (currentPath != null) {
      final file = File(currentPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final appDir = await getApplicationSupportDirectory();
    for (final ext in _allowedImageExtensions) {
      final file = File(p.join(appDir.path, '$_homeBackgroundBaseName$ext'));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<File> _settingsFile() async {
    final appDir = await getApplicationSupportDirectory();
    return File(p.join(appDir.path, _settingsFileName));
  }
}

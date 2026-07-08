import 'dart:io';

import 'package:path/path.dart' as p;

class DownloadBooksPaths {
  DownloadBooksPaths._();

  static const String rootFolderName = 'download_books';
  static const String importFolderName = '导入';

  /// macOS 沙盒内 HOME 指向容器；用 USER 解析真实主目录。
  static String? realUserHomePath() {
    final user = Platform.environment['USER'] ?? Platform.environment['LOGNAME'];

    if (Platform.isMacOS) {
      if (user != null && user.isNotEmpty) {
        return '/Users/$user';
      }
    }
    if (Platform.isLinux) {
      if (user != null && user.isNotEmpty) {
        return '/home/$user';
      }
    }
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return profile;
      }
    }

    return Platform.environment['HOME'];
  }

  static Directory? rootDirectory() {
    final home = realUserHomePath();
    if (home == null || home.isEmpty) return null;
    return Directory(p.join(home, rootFolderName));
  }

  static bool isUnderRoot(String filePath) {
    final root = rootDirectory();
    if (root == null) return false;
    return p.isWithin(p.normalize(root.path), p.normalize(filePath));
  }

  static String sanitizePathComponent(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'book' : cleaned;
  }

  static Future<Directory> ensureDirectory([String subFolder = '']) async {
    final safeSubFolder = subFolder.trim().isEmpty
        ? ''
        : sanitizePathComponent(subFolder);

    final root = rootDirectory();
    if (root == null) {
      throw Exception('无法解析用户主目录，download_books 路径不可用');
    }

    final dir = safeSubFolder.isEmpty
        ? root
        : Directory(p.join(root.path, safeSubFolder));

    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final probe = File(p.join(dir.path, '.write_probe'));
      probe.writeAsStringSync('ok', flush: true);
      if (probe.existsSync()) {
        probe.deleteSync();
      }
      return dir;
    } catch (error) {
      throw Exception('无法写入 ${dir.path}：$error');
    }
  }

  static Future<Directory> importDirectory() =>
      ensureDirectory(importFolderName);
}

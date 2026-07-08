import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_messenger.dart';
import '../providers/app_providers.dart';
import '../services/import_exceptions.dart';
import '../utils/download_books_paths.dart';

Future<void> importBooksFromPicker(WidgetRef ref) async {
  final root = await DownloadBooksPaths.ensureDirectory();
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub', 'mobi', 'azw', 'azw3'],
    allowMultiple: true,
    dialogTitle: '选择电子书',
    initialDirectory: root.path,
  );

  if (result == null || result.files.isEmpty) return;

  final service = ref.read(bookServiceProvider);
  var imported = 0;
  var skipped = 0;

  for (final file in result.files) {
    final path = file.path;
    if (path == null) continue;
    try {
      await service.importBook(path);
      imported++;
    } on DuplicateBookException catch (error) {
      skipped++;
      showAppSnackBar('《${error.existing.title}》已在书架中');
    } catch (error) {
      showAppSnackBar('导入失败: ${file.name}\n$error');
    }
  }

  ref.invalidate(libraryInitProvider);
  ref.invalidate(booksProvider);

  if (imported == 0 && skipped == 0) return;
  if (imported > 0) {
    showAppSnackBar(
      skipped > 0 ? '成功导入 $imported 本，跳过 $skipped 本重复' : '成功导入 $imported 本书',
    );
  }
}

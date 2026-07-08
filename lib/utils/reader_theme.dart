import 'package:katbook_epub_reader/katbook_epub_reader.dart';

import '../models/app_settings.dart';

ReaderTheme readerThemeFromMode(ReaderThemeMode mode) {
  switch (mode) {
    case ReaderThemeMode.light:
      return ReaderTheme.light;
    case ReaderThemeMode.sepia:
      return ReaderTheme.sepia;
    case ReaderThemeMode.dark:
      return ReaderTheme.dark;
  }
}

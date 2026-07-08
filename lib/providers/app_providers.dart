import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/book_item.dart';
import '../services/book_service.dart';
import '../services/settings_service.dart';

final bookServiceProvider = Provider<BookService>((ref) {
  return BookService.instance;
});

final libraryInitProvider = FutureProvider<void>((ref) async {
  await ref.read(bookServiceProvider).initialize();
});

final booksProvider = Provider<List<BookItem>>((ref) {
  ref.watch(libraryInitProvider);
  return ref.read(bookServiceProvider).books;
});

final activeBookProvider =
    NotifierProvider<ActiveBookNotifier, BookItem?>(ActiveBookNotifier.new);

class ActiveBookNotifier extends Notifier<BookItem?> {
  @override
  BookItem? build() => null;

  void open(BookItem book) => state = book;

  void close() => state = null;
}

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    Future.microtask(() async {
      final settings = await SettingsService.instance.load();
      if (!ref.mounted) return;
      state = settings;
    });
    return const AppSettings();
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await SettingsService.instance.save(settings);
  }
}

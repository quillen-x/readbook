import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'books_page.dart';
import 'reader/reader_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBook = ref.watch(activeBookProvider);

    if (activeBook != null) {
      return Scaffold(
        body: ReaderScreen(
          key: ValueKey(activeBook.id),
          book: activeBook,
          onClose: () {
            ref.read(activeBookProvider.notifier).close();
            ref.invalidate(libraryInitProvider);
          },
        ),
      );
    }

    return const Scaffold(
      body: BooksPage(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/book_item.dart';
import '../models/sidebar_section.dart';
import '../providers/app_providers.dart';
import '../widgets/book_cover_card.dart';
import '../widgets/home_background.dart';
import '../widgets/home_flip_view.dart';
import '../widgets/hover_download_fab.dart';
import '../widgets/hover_settings_fab.dart';
import 'downloads_page.dart';
import 'settings_page.dart';

class BooksPage extends ConsumerStatefulWidget {
  const BooksPage({super.key});

  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  bool _showDownloads = false;

  void _toggleDownloads() {
    setState(() => _showDownloads = !_showDownloads);
  }

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(libraryInitProvider);
    final settings = ref.watch(appSettingsProvider);

    return HomeBackground(
      backgroundPath: settings.homeBackgroundPath,
      backgroundOpacity: settings.homeBackgroundOpacity,
      child: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (_) {
          final books =
              ref.read(bookServiceProvider).sortedBooks(BookSort.lastRead);

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: HomeFlipView(
                  showDownloads: _showDownloads,
                  books: _buildBooksGrid(
                    context,
                    ref,
                    books,
                    settings.bookCardBackgroundOpacity,
                  ),
                  downloads: const DownloadsPage(),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: HoverDownloadFab(
                  icon: _showDownloads
                      ? Icons.grid_view_rounded
                      : Icons.download_outlined,
                  tooltip: _showDownloads ? '返回书架' : '下载',
                  onPressed: _toggleDownloads,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: HoverSettingsFab(
                  onPressed: () => showSettingsDialog(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBooksGrid(
    BuildContext context,
    WidgetRef ref,
    List<BookItem> books,
    double cardBackgroundOpacity,
  ) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 48.sp),
            SizedBox(height: 12.h),
            const Text('书架还是空的'),
            SizedBox(height: 8.h),
            Text(
              '右下角悬停打开设置，导入电子书',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 36.h),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: gridBookCoverMaxExtentScaled(),
        mainAxisSpacing: 14.h,
        crossAxisSpacing: 14.w,
        childAspectRatio: bookCoverGridChildAspectRatio(
          gridBookCoverMaxExtentScaled(),
        ),
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCoverCard(
          book: book,
          cardBackgroundOpacity: cardBackgroundOpacity,
          onTap: () => ref.read(activeBookProvider.notifier).open(book),
          onLongPress: () => _confirmDeleteBook(context, ref, book),
        );
      },
    );
  }
}

Future<void> _confirmDeleteBook(
  BuildContext context,
  WidgetRef ref,
  BookItem book,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除书籍'),
      content: Text('确定要删除《${book.displayTitle}》吗？此操作不可恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await ref.read(bookServiceProvider).deleteBook(book.id);
  ref.invalidate(libraryInitProvider);
}

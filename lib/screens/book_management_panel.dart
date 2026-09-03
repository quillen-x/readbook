import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/book_item.dart';
import '../models/sidebar_section.dart';
import '../providers/app_providers.dart';
import '../widgets/book_cover_card.dart';

class BookManagementPanel extends ConsumerWidget {
  const BookManagementPanel({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final init = ref.watch(libraryInitProvider);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 8.h),
            child: Row(
              children: [
                Text('电子书管理', style: textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '关闭',
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: init.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('加载失败: $error')),
              data: (_) {
                final books = ref
                    .read(bookServiceProvider)
                    .sortedBooks(BookSort.progress);

                if (books.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无已导入的电子书',
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(24.w, 12.h, 16.w, 24.h),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return _BookManagementTile(
                      book: book,
                      onDelete: () => _confirmDeleteBook(context, ref, book),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookManagementTile extends StatelessWidget {
  const _BookManagementTile({
    required this.book,
    required this.onDelete,
  });

  final BookItem book;
  final VoidCallback onDelete;

  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = book.progressPercent.round();

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8.r),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(8.r),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 4.w, 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ManagementBookCover(book: book),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '导入 ${_dateFormat.format(book.addedAt)}  ·  进度 $progress%',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20.sp,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementBookCover extends StatelessWidget {
  const _ManagementBookCover({required this.book});

  final BookItem book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverFile =
        book.coverPath != null ? File(book.coverPath!) : null;
    final hasCover = coverFile != null && coverFile.existsSync();
    const coverWidth = 44.0;
    const coverHeight = coverWidth / kBookCoverAspectRatio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6.r),
      child: SizedBox(
        width: coverWidth.w,
        height: coverHeight.h,
        child: hasCover
            ? Image.file(coverFile, fit: BoxFit.cover)
            : ColoredBox(
                color: colorScheme.primaryContainer,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 22.sp,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
      ),
    );
  }
}

Future<void> _confirmDeleteBook(
  BuildContext context,
  WidgetRef ref,
  BookItem book,
) async {
  final hasProgress = book.progressPercent.round() > 0;

  if (hasProgress) {
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
  }

  final activeBook = ref.read(activeBookProvider);
  if (activeBook?.id == book.id) {
    ref.read(activeBookProvider.notifier).close();
  }

  await ref.read(bookServiceProvider).deleteBook(book.id);
  ref.invalidate(libraryInitProvider);
}

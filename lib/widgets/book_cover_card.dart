import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/book_item.dart';

/// 书籍封面标准比例（宽 : 高 = 2 : 3）
const double kBookCoverAspectRatio = 2 / 3;

/// 网格封面最大宽度（设计稿像素）
const double kGridBookCoverMaxExtent = 132;

double gridBookCoverMaxExtentScaled() => kGridBookCoverMaxExtent.w;

double bookCoverGridChildAspectRatio(double cellWidth) {
  return kBookCoverAspectRatio;
}

class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.cardBackgroundOpacity = 0.5,
  });

  final BookItem book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double cardBackgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Material(
      color: surfaceColor.withValues(
        alpha: cardBackgroundOpacity.clamp(0.0, 1.0),
      ),
      borderRadius: BorderRadius.circular(10.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: BookCoverThumbnail(book: book),
      ),
    );
  }
}

class BookCoverThumbnail extends StatelessWidget {
  const BookCoverThumbnail({
    super.key,
    required this.book,
  });

  final BookItem book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coverFile =
        book.coverPath != null ? File(book.coverPath!) : null;
    final hasCover = coverFile != null && coverFile.existsSync();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;

        var width = maxWidth;
        var height = width / kBookCoverAspectRatio;

        if (maxHeight.isFinite && height > maxHeight) {
          height = maxHeight;
          width = height * kBookCoverAspectRatio;
        }

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: _buildCoverContent(
              context,
              colorScheme: colorScheme,
              coverFile: coverFile,
              hasCover: hasCover,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverContent(
    BuildContext context, {
    required ColorScheme colorScheme,
    required File? coverFile,
    required bool hasCover,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        gradient: hasCover
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.file(
              coverFile!,
              fit: BoxFit.cover,
            )
          else
            Center(
              child: Icon(
                Icons.menu_book_outlined,
                size: 28.sp,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          Positioned(
            top: 6.h,
            right: 6.w,
            child: _CoverBadge(
              label: '${book.progressPercent.round()}%',
            ),
          ),
          Positioned(
            top: 6.h,
            left: 6.w,
            child: _CoverBadge(label: book.format.label),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CoverTitleOverlay(title: book.displayTitle),
          ),
        ],
      ),
    );
  }
}

class RemoteBookCoverCard extends StatelessWidget {
  const RemoteBookCoverCard({
    super.key,
    required this.title,
    required this.onTap,
    this.coverUrl,
    this.downloaded = false,
    this.cardBackgroundOpacity = 0.5,
  });

  final String title;
  final VoidCallback onTap;
  final String? coverUrl;
  final bool downloaded;
  final double cardBackgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Material(
      color: surfaceColor.withValues(
        alpha: cardBackgroundOpacity.clamp(0.0, 1.0),
      ),
      borderRadius: BorderRadius.circular(10.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;

            var width = maxWidth;
            var height = width / kBookCoverAspectRatio;

            if (maxHeight.isFinite && height > maxHeight) {
              height = maxHeight;
              width = height * kBookCoverAspectRatio;
            }

            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: height,
                child: _RemoteCoverContent(
                  title: title,
                  coverUrl: coverUrl,
                  downloaded: downloaded,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RemoteCoverContent extends StatelessWidget {
  const _RemoteCoverContent({
    required this.title,
    this.coverUrl,
    required this.downloaded,
  });

  final String title;
  final String? coverUrl;
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = (coverUrl ?? '').trim();
    final hasCover = url.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        gradient: hasCover
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasCover)
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 28.sp,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            Center(
              child: Icon(
                Icons.menu_book_outlined,
                size: 28.sp,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          if (downloaded)
            Positioned(
              top: 6.h,
              right: 6.w,
              child: const _CoverBadge(label: '已下载'),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CoverTitleOverlay(title: displayBookTitle(title)),
          ),
        ],
      ),
    );
  }
}

class _CoverTitleOverlay extends StatelessWidget {
  const _CoverTitleOverlay({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 8.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black38,
            Colors.black54,
          ],
        ),
      ),
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          height: 1.2,
          shadows: const [
            Shadow(
              color: Colors.black45,
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverBadge extends StatelessWidget {
  const _CoverBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 9.sp),
      ),
    );
  }
}

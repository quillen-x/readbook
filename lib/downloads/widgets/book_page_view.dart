import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../theme/app_text_styles.dart';
import '../../widgets/book_cover_card.dart';


class BookPageView extends StatelessWidget {
  const BookPageView({
    super.key,
    required this.passwordController,
    required this.isLoading,
    required this.isBookLoading,
    required this.isDownloading,
    required this.isBatchDownloading,
    required this.tags,
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedPage,
    required this.lastDownloadTrace,
    required this.batchTotal,
    required this.batchDone,
    required this.batchSuccess,
    required this.batchFailed,
    required this.batchSkipped,
    required this.batchCurrentTitle,
    required this.batchLogs,
    required this.errorText,
    required this.catalog,
    required this.onTagTap,
    required this.onTagLongPress,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onDownloadCurrentPage,
    required this.onOpenBook,
    this.onRetry,
    this.cardBackgroundOpacity = 0.5,
    this.batchLabel = '批量下载',
  });

  final TextEditingController passwordController;
  final bool isLoading;
  final bool isBookLoading;
  final bool isDownloading;
  final bool isBatchDownloading;
  final List<Map<String, String>> tags;
  final String? selectedCategory;
  final String selectedType;
  final int selectedPage;
  final List<String> lastDownloadTrace;
  final int batchTotal;
  final int batchDone;
  final int batchSuccess;
  final int batchFailed;
  final int batchSkipped;
  final String batchCurrentTitle;
  final List<String> batchLogs;
  final String? errorText;
  final List<Map<String, String>> catalog;
  final ValueChanged<Map<String, String>> onTagTap;
  final ValueChanged<Map<String, String>> onTagLongPress;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final VoidCallback onDownloadCurrentPage;
  final ValueChanged<Map<String, String>> onOpenBook;
  final VoidCallback? onRetry;
  final double cardBackgroundOpacity;
  final String batchLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSidebar(context),
                VerticalDivider(
                  width: 1.w,
                  thickness: 1.w,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: _buildMainPanel(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    return SizedBox(
      width: 120.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading || isBookLoading || isDownloading || isBatchDownloading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
              child: LinearProgressIndicator(
                minHeight: 3.h,
                color: colorScheme.primary,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          Expanded(
            child: tags.isEmpty
                ? Center(
                    child: Text('暂无分类', style: textStyles.sidebarEmpty),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 20.h),
                    itemCount: tags.length,
                    separatorBuilder: (_, __) => SizedBox(height: 4.h),
                    itemBuilder: (_, i) {
                      final tag = tags[i];
                      final slug = tag['slug'] ?? '';
                      final title = tag['title'] ?? slug;
                      final selected = slug == selectedCategory && (tag['type'] ?? 'category') == selectedType;
                      return Material(
                        color: selected ? colorScheme.primaryContainer.withValues(alpha: 0.55) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8.r),
                          onTap: () {
                            if (isLoading) return;
                            onTagTap(tag);
                          },
                          onLongPress: () {
                            if (isLoading || isBatchDownloading || isDownloading) {
                              return;
                            }
                            onTagLongPress(tag);
                          },
                          onSecondaryTap: () {
                            if (isLoading || isBatchDownloading || isDownloading) {
                              return;
                            }
                            onTagLongPress(tag);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: selected ? colorScheme.primary.withValues(alpha: 0.35) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: selected ? textStyles.sidebarTagSelected : textStyles.sidebarTag,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnreachableState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48.sp,
            color: colorScheme.outline,
          ),
          SizedBox(height: 12.h),
          Text(
            '读书派暂时无法访问',
            style: textStyles.sidebarTagSelected.copyWith(
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            '请检查网络、切换线路或代理后重试',
            style: textStyles.sidebarEmpty,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16.h),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('重新加载'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorText != null)
          Material(
            color: colorScheme.errorContainer.withValues(alpha: 0.45),
            child: InkWell(
              onTap: isLoading ? null : onRetry,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Text(
                  onRetry == null ? errorText! : '$errorText\n点击此处重试',
                  style: textStyles.errorBanner,
                ),
              ),
            ),
          ),
        Expanded(
          child: catalog.isEmpty
              ? Center(
                  child: isLoading
                      ? CircularProgressIndicator(
                          strokeWidth: 2.w,
                          color: colorScheme.primary,
                        )
                      : errorText != null
                          ? _buildUnreachableState(context)
                          : Text('暂无数据', style: textStyles.sidebarEmpty),
                )
              : GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 36.h),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: gridBookCoverMaxExtentScaled(),
                    mainAxisSpacing: 14.h,
                    crossAxisSpacing: 14.w,
                    childAspectRatio: bookCoverGridChildAspectRatio(
                      gridBookCoverMaxExtentScaled(),
                    ),
                  ),
                  itemCount: catalog.length,
                  itemBuilder: (_, i) => _buildBookCard(catalog[i]),
                ),
        ),
        if (isBatchDownloading || batchDone > 0) _buildBatchProgress(context),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildBookCard(Map<String, String> book) {
    final downloaded = (book['downloaded'] ?? '0') == '1';
    return RemoteBookCoverCard(
      title: book['title'] ?? '',
      coverUrl: book['cover'],
      downloaded: downloaded,
      cardBackgroundOpacity: cardBackgroundOpacity,
      onTap: () => onOpenBook(book),
    );
  }

  Widget _buildBatchProgress(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBatchDownloading)
            LinearProgressIndicator(
              minHeight: 4.h,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          if (isBatchDownloading) SizedBox(height: 6.h),
          Text(
            '$batchLabel：$batchDone/$batchTotal，成功 $batchSuccess，失败 $batchFailed，跳过 $batchSkipped'
            '${batchCurrentTitle.isNotEmpty ? '，当前：$batchCurrentTitle' : ''}',
            style: textStyles.batchProgress,
          ),
          if (batchLogs.isNotEmpty)
            SizedBox(
              height: 56.h,
              child: ListView(
                children: batchLogs.take(6).toList().reversed.map((e) => Text(e, style: textStyles.batchLog)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;
    final canPrev = !isLoading && selectedPage > 1;
    final canNext = !isLoading && catalog.isNotEmpty;
    final canBatch = !isLoading &&
        !isBatchDownloading &&
        !isDownloading &&
        catalog.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: canBatch ? onDownloadCurrentPage : null,
            icon: Icon(
              isBatchDownloading
                  ? Icons.hourglass_top_rounded
                  : Icons.download_rounded,
              size: 16.sp,
            ),
            label: Text(
              isBatchDownloading ? '下载中...' : '下载本页',
              style: textStyles.bottomBarMeta.copyWith(
                color: canBatch
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface.withValues(alpha: 0.38),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              minimumSize: Size(0, 32.h),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const Spacer(),
          _buildPager(context, canPrev: canPrev, canNext: canNext),
        ],
      ),
    );
  }

  Widget _buildPager(
    BuildContext context, {
    required bool canPrev,
    required bool canNext,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(20.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pagerIconButton(
              context: context,
              icon: Icons.chevron_left_rounded,
              tooltip: '上一页',
              enabled: canPrev,
              onPressed: onPrevPage,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 56.w),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Text(
                  '$selectedPage',
                  textAlign: TextAlign.center,
                  style: textStyles.bottomBarPage.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            _pagerIconButton(
              context: context,
              icon: Icons.chevron_right_rounded,
              tooltip: '下一页',
              enabled: canNext,
              onPressed: onNextPage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pagerIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: enabled ? onPressed : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 20.sp),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: 32.w, height: 32.h),
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.28),
        hoverColor: colorScheme.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
      ),
    );
  }
}

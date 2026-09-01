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

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12.w,
        runSpacing: 8.h,
        children: [
          _barButton(
            context: context,
            label: isBatchDownloading ? '批量下载中...' : '下载当前页',
            onPressed: isLoading || isBatchDownloading || isDownloading || catalog.isEmpty
                ? null
                : onDownloadCurrentPage,
          ),
          _barButton(
            context: context,
            label: '上一页',
            onPressed: isLoading || selectedPage <= 1 ? null : onPrevPage,
          ),
          Text('第 $selectedPage 页', style: textStyles.bottomBarPage),
          _barButton(
            context: context,
            label: '下一页',
            onPressed: isLoading ? null : onNextPage,
          ),
        ],
      ),
    );
  }

  Widget _barButton({
    required BuildContext context,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(8.r);

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: enabled
                ? colorScheme.outline
                : colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: context.appText.bottomBarMeta.copyWith(
            color: enabled
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
      ),
    );
  }
}

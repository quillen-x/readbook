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
    this.isBatchPaused = false,
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
    required this.downloadTitle,
    required this.downloadReceived,
    this.downloadTotal,
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
    this.selectedSource = 'dushupai',
    this.onSourceChanged,
    this.canTagLongPress = true,
  });

  final TextEditingController passwordController;
  final bool isLoading;
  final bool isBookLoading;
  final bool isDownloading;
  final bool isBatchDownloading;
  final bool isBatchPaused;
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
  final String downloadTitle;
  final int downloadReceived;
  final int? downloadTotal;
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
  final String selectedSource;
  final ValueChanged<String>? onSourceChanged;
  final bool canTagLongPress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildMainPanel(context),
    );
  }

  String _tagDisplayName(Map<String, String> tag) {
    final raw = (tag['title'] ?? tag['slug'] ?? '分类').trim();
    return raw.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim();
  }

  String get _selectedCategoryName {
    for (final tag in tags) {
      if ((tag['slug'] ?? '') == selectedCategory &&
          (tag['type'] ?? 'category') == selectedType) {
        return _tagDisplayName(tag);
      }
    }
    return '分类';
  }

  Future<void> _openCategoryDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        final textStyles = dialogContext.appText;
        return AlertDialog(
          title: const Text('选择分类'),
          content: SizedBox(
            width: 520.w,
            child: tags.isEmpty
                ? Text('暂无分类', style: textStyles.sidebarEmpty)
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 4.w,
                      runSpacing: 4.h,
                      children: [
                        for (final tag in tags)
                          _CategoryTagChip(
                            tag: tag,
                            selected: (tag['slug'] ?? '') == selectedCategory &&
                                (tag['type'] ?? 'category') == selectedType,
                            enabled: !isLoading,
                            canLongPress: canTagLongPress &&
                                !isLoading &&
                                !isBatchDownloading &&
                                !isDownloading,
                            onTap: (selected) {
                              Navigator.of(dialogContext).pop();
                              onTagTap(selected);
                            },
                            onLongPress: (selected) {
                              Navigator.of(dialogContext).pop();
                              onTagLongPress(selected);
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '关闭',
                style: textStyles.bottomBarMeta.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSourceTabs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;

    Widget tab(String id, String label) {
      final selected = selectedSource == id;
      return Expanded(
        child: InkWell(
          onTap: onSourceChanged == null || selected
              ? null
              : () => onSourceChanged!(id),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  width: selected ? 2 : 1,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Text(
              label,
              style: selected
                  ? textStyles.sidebarTagSelected
                  : textStyles.sidebarTag,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('dushupai', '读书派'),
        tab('sobooks', 'SoBooks'),
      ],
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
            selectedSource == 'sobooks' ? 'SoBooks 暂时无法访问' : '读书派暂时无法访问',
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
        _buildSourceTabs(context),
        if (isLoading || isBookLoading)
          LinearProgressIndicator(
            minHeight: 2.h,
            color: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
          ),
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
                  padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 20.h),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: kBookCoverAspectRatio,
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
    final showCurrentProgress =
        (isBatchDownloading || isBatchPaused) && batchCurrentTitle.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      constraints: BoxConstraints(minHeight: 120.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBatchPaused
                ? '$batchLabel 已暂停：$batchDone/$batchTotal，成功 $batchSuccess，失败 $batchFailed，跳过 $batchSkipped'
                : '$batchLabel：$batchDone/$batchTotal，成功 $batchSuccess，失败 $batchFailed，跳过 $batchSkipped',
            style: textStyles.batchProgress,
          ),
          if (showCurrentProgress) ...[
            SizedBox(height: 10.h),
            Text(
              _downloadProgressText(
                title: isBatchPaused
                    ? '已暂停 · $batchCurrentTitle'
                    : batchCurrentTitle,
                received: downloadReceived,
                total: downloadTotal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyles.bottomBarMeta.copyWith(height: 1.35),
            ),
          ],
          if (batchLogs.isNotEmpty) ...[
            SizedBox(height: 10.h),
            SizedBox(
              height: 96.h,
              child: ListView(
                children: batchLogs
                    .take(8)
                    .toList()
                    .reversed
                    .map((e) => Padding(
                          padding: EdgeInsets.only(bottom: 4.h),
                          child: Text(e, style: textStyles.batchLog),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;
    final canPrev = !isLoading && selectedPage > 1;
    final canNext = !isLoading && catalog.isNotEmpty;
    final isCatalogSync = batchLabel == '同步封面';
    final downloading =
        !isCatalogSync && ((isBatchDownloading && !isBatchPaused) || isDownloading);
    final canPressDownload = !isLoading &&
        !isCatalogSync &&
        (downloading || isBatchPaused || catalog.isNotEmpty);
    final showDownloadProgress = isDownloading && !isBatchDownloading;
    final downloadIcon = isCatalogSync
        ? Icons.hourglass_top_rounded
        : isBatchPaused
            ? Icons.play_arrow_rounded
            : downloading
                ? Icons.pause_rounded
                : Icons.download_rounded;
    final downloadLabel = isCatalogSync
        ? '同步中...'
        : isBatchPaused
            ? '继续'
            : downloading
                ? '暂停'
                : catalog.isEmpty
                    ? '下载本页'
                    : '下载本页（${catalog.length}）';

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDownloadProgress) ...[
            Text(
              _downloadProgressText(
                title: downloadTitle,
                received: downloadReceived,
                total: downloadTotal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyles.bottomBarMeta,
            ),
            SizedBox(height: 8.h),
          ],
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: canPressDownload ? onDownloadCurrentPage : null,
                icon: Icon(downloadIcon, size: 16.sp),
                label: Text(
                  downloadLabel,
                  style: textStyles.bottomBarMeta.copyWith(
                    color: canPressDownload
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
              SizedBox(width: 8.w),
              FilledButton.tonalIcon(
                onPressed: () => _openCategoryDialog(context),
                icon: Icon(Icons.category_outlined, size: 16.sp),
                label: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 120.w),
                  child: Text(
                    _selectedCategoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyles.bottomBarMeta.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
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
        ],
      ),
    );
  }

  String _downloadProgressText({
    required String title,
    required int received,
    required int? total,
  }) {
    final sizeText = total != null && total > 0
        ? '${_formatByteSize(received)} / ${_formatByteSize(total)}'
        : _formatByteSize(received);
    if (total != null && total > 0) {
      final pct = ((received / total) * 100).clamp(0, 100).toStringAsFixed(0);
      final name = title.isNotEmpty ? title : '下载中';
      return '$name · $pct% · $sizeText';
    }
    final name = title.isNotEmpty ? title : '下载中';
    return received > 0 ? '$name · $sizeText' : name;
  }

  String _formatByteSize(int n) {
    if (n >= 1024 * 1024) {
      return '${(n / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    if (n >= 1024) {
      return '${(n / 1024).toStringAsFixed(0)}KB';
    }
    return '${n}B';
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

class _CategoryTagChip extends StatefulWidget {
  const _CategoryTagChip({
    required this.tag,
    required this.selected,
    required this.enabled,
    required this.canLongPress,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, String> tag;
  final bool selected;
  final bool enabled;
  final bool canLongPress;
  final ValueChanged<Map<String, String>> onTap;
  final ValueChanged<Map<String, String>> onLongPress;

  @override
  State<_CategoryTagChip> createState() => _CategoryTagChipState();
}

class _CategoryTagChipState extends State<_CategoryTagChip> {
  static final _countSuffix = RegExp(r'\s*\((\d+)\)\s*$');

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.appText;
    final slug = widget.tag['slug'] ?? '';
    final rawTitle = (widget.tag['title'] ?? slug).trim();
    final countMatch = _countSuffix.firstMatch(rawTitle);
    final name = countMatch == null
        ? rawTitle
        : rawTitle.substring(0, countMatch.start).trim();
    final count = countMatch?.group(1);
    final showCount = _hovered && count != null;
    final radius = BorderRadius.circular(6.r);

    return Material(
      color: widget.selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onHover: (value) {
          if (_hovered == value) return;
          setState(() => _hovered = value);
        },
        onTap: widget.enabled ? () => widget.onTap(widget.tag) : null,
        onLongPress:
            widget.canLongPress ? () => widget.onLongPress(widget.tag) : null,
        onSecondaryTap:
            widget.canLongPress ? () => widget.onLongPress(widget.tag) : null,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          alignment: Alignment.centerLeft,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: widget.selected
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name),
                  if (showCount)
                    TextSpan(
                      text: '($count)',
                      style: textStyles.sidebarEmpty,
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: widget.selected
                  ? textStyles.sidebarTagSelected
                  : textStyles.sidebarTag,
            ),
          ),
        ),
      ),
    );
  }
}



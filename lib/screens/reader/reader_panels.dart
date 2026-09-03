import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:katbook_epub_reader/katbook_epub_reader.dart';

import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';

class ReaderBottomProgressBar extends StatelessWidget {
  const ReaderBottomProgressBar({
    super.key,
    required this.progress,
    required this.themeData,
  });

  final double progress;
  final ReaderThemeData themeData;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final barHeight = 2.h.clamp(2, 3).toDouble();
    final trackColor = themeData.textColor.withValues(alpha: 0.22);
    final fillColor = themeData.accentColor;

    return IgnorePointer(
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: trackColor,
                    border: Border(
                      top: BorderSide(
                        color: themeData.textColor.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                if (value > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth * value,
                      height: barHeight,
                      child: ColoredBox(color: fillColor),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ReaderHoverTitleBar extends StatefulWidget {
  const ReaderHoverTitleBar({
    super.key,
    required this.title,
    required this.themeData,
    this.onClose,
  });

  final String title;
  final ReaderThemeData themeData;
  final VoidCallback? onClose;

  @override
  State<ReaderHoverTitleBar> createState() => _ReaderHoverTitleBarState();
}

class _ReaderHoverTitleBarState extends State<ReaderHoverTitleBar> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: SizedBox(
          height: 64.h,
          child: AnimatedOpacity(
            opacity: _hovering ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: widget.onClose != null
                    ? Tooltip(
                        message: '',
                        child: _TitleBarContent(
                          title: widget.title,
                          themeData: widget.themeData,
                          onTap: widget.onClose,
                        ),
                      )
                    : _TitleBarContent(
                        title: widget.title,
                        themeData: widget.themeData,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBarContent extends StatelessWidget {
  const _TitleBarContent({
    required this.title,
    required this.themeData,
    this.onTap,
  });

  final String title;
  final ReaderThemeData themeData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Ink(
          decoration: BoxDecoration(
            color: themeData.backgroundColor.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: themeData.textColor.withValues(alpha: 0.14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560.w),
              child: Text(
                title,
                style: TextStyle(
                  color: themeData.textColor,
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w100,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderTocToggleButton extends StatelessWidget {
  const ReaderTocToggleButton({
    super.key,
    required this.expanded,
    required this.themeData,
    required this.onToggle,
  });

  final bool expanded;
  final ReaderThemeData themeData;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      shadowColor: Colors.black26,
      color: themeData.backgroundColor,
      shape: CircleBorder(
        side: BorderSide(
          color: themeData.textColor.withValues(alpha: 0.18),
        ),
      ),
      child: Tooltip(
        message: expanded ? '收起目录' : '展开目录',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onToggle,
          child: SizedBox(
            width: 22.w,
            height: 22.w,
            child: Icon(
              expanded ? Icons.chevron_left : Icons.chevron_right,
              size: 16.sp,
              color: themeData.secondaryTextColor,
            ),
          ),
        ),
      ),
    );
  }
}

class ReaderTocPanel extends ConsumerWidget {
  const ReaderTocPanel({
    super.key,
    required this.chapters,
    required this.currentParagraphIndex,
    required this.themeData,
    required this.onChapterTap,
    this.bookTitle,
    this.bookAuthor,
  });

  final List<ChapterNode> chapters;
  final int currentParagraphIndex;
  final ReaderThemeData themeData;
  final ValueChanged<ChapterNode> onChapterTap;
  final String? bookTitle;
  final String? bookAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final fontFamily = settings.fontFamily.familyName;

    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      color: themeData.backgroundColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12.r)),
      ),
      child: SizedBox(
        width: 220.w,
        child: TableOfContentsWidget(
          chapters: chapters,
          currentParagraphIndex: currentParagraphIndex,
          themeData: themeData,
          onChapterTap: onChapterTap,
          bookTitle: bookTitle,
          bookAuthor: bookAuthor,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamily == null
              ? const ['PingFang SC', 'Heiti SC', 'Songti SC']
              : null,
          fontSize: settings.fontSize,
          lineHeight: settings.lineHeight,
          fontWeight: settings.fontWeight.weight,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:katbook_epub_reader/katbook_epub_reader.dart';

import '../../models/app_settings.dart';
import '../../models/book_item.dart';
import '../../providers/app_providers.dart';
import '../../services/book_service.dart';
import '../../utils/reader_theme.dart';
import 'reader_panels.dart';
import 'reader_quick_settings.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    required this.onClose,
  });

  final BookItem book;
  final VoidCallback onClose;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final KatbookEpubController _controller = KatbookEpubController();
  final GlobalKey<KatbookEpubReaderState> _readerKey =
      GlobalKey<KatbookEpubReaderState>();

  bool _isLoading = true;
  String? _error;
  bool _showQuickSettings = false;
  ReadingPosition? _lastSavedPosition;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes =
          await BookService.instance.loadEpubBytes(widget.book.epubPath);
      final success = await _controller.openBook(bytes);
      if (!success) {
        throw Exception(_controller.loadingError ?? '无法解析 EPUB 文件');
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProgress(ReadingPosition position) async {
    if (_lastSavedPosition == position) return;
    _lastSavedPosition = position;
    setState(() => _progress = position.progressPercent / 100);
    await BookService.instance.updateProgress(
      id: widget.book.id,
      position: position,
    );
    ref.invalidate(libraryInitProvider);
  }

  String? _readerFontFamily(ReaderFontFamily family) {
    return family.familyName;
  }

  Widget _buildParagraph(
    BuildContext context,
    ParagraphElement paragraph,
    ReaderThemeData theme,
    double fontSize,
  ) {
    final settings = ref.watch(appSettingsProvider);
    final fontFamily = _readerFontFamily(settings.fontFamily);

    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamily == null
            ? const ['PingFang SC', 'Heiti SC', 'Songti SC']
            : null,
        fontSize: fontSize,
        height: settings.lineHeight,
        fontWeight: settings.fontWeight.weight,
        color: theme.textColor,
      ),
      child: EpubContentRenderer(
        paragraph: paragraph,
        themeData: theme,
        fontSize: fontSize,
        lineHeight: settings.lineHeight,
        baseFontWeight: settings.fontWeight.weight,
        imageData: _controller.imageData,
        cssParser: _controller.cssParser,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error'),
            SizedBox(height: 12.h),
            FilledButton(onPressed: _loadBook, child: const Text('重试')),
          ],
        ),
      );
    }

    final settings = ref.watch(appSettingsProvider);
    final readerTheme = readerThemeFromMode(settings.themeMode);

    ref.listen(
      appSettingsProvider.select((s) => s.themeMode),
      (previous, next) {
        if (previous == next) return;
        _readerKey.currentState?.setTheme(readerThemeFromMode(next));
      },
    );

    ref.listen(
      appSettingsProvider.select((s) => s.fontSize),
      (previous, next) {
        if (previous == next) return;
        _readerKey.currentState?.setFontSize(next);
      },
    );

    final showToc = settings.showTocPanel;
    final themeData = ReaderThemeData.fromTheme(readerTheme);
    final currentParagraphIndex =
        _controller.currentPosition?.paragraphIndex ?? -1;
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRect(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  width: showToc ? 200.w : 0,
                  child: SizedBox(
                    width: 200.w,
                    child: ReaderTocPanel(
                      chapters: _controller.tableOfContents,
                      currentParagraphIndex: currentParagraphIndex,
                      themeData: themeData,
                      bookTitle: _controller.title,
                      bookAuthor: _controller.author,
                      onChapterTap: (chapter) {
                        _readerKey.currentState?.jumpToChapter(chapter);
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                child: KatbookEpubReader(
                  key: _readerKey,
                  controller: _controller,
                  showAppBar: false,
                  initialTheme: readerTheme,
                  initialFontSize: settings.fontSize,
                  initialReadingMode: ReadingMode.scroll,
                  contentWidthPercent: settings.readerContentWidthPercent
                      .clamp(0.55, 1.0),
                  initialPosition: widget.book.readingPosition,
                  onPositionChanged: _saveProgress,
                  onProgressChanged: (value) {
                    setState(() => _progress = value);
                  },
                  paragraphBuilder: _buildParagraph,
                ),
              ),
            ],
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            left: (showToc ? 200.w : 0) - 11.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: ReaderTocToggleButton(
                expanded: showToc,
                themeData: themeData,
                onToggle: () {
                  ref.read(appSettingsProvider.notifier).update(
                        settings.copyWith(showTocPanel: !showToc),
                      );
                },
              ),
            ),
          ),
          ReaderHoverTitleBar(
            title: widget.book.displayTitle,
            themeData: themeData,
            onClose: widget.onClose,
          ),
          if (_showQuickSettings)
            Positioned(
              right: 12.w,
              bottom: 88.h,
              width: screenSize.width * 0.5,
              height: screenSize.height * 0.5,
              child: ReaderQuickSettingsPanel(
                onClose: () => setState(() => _showQuickSettings = false),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: ReaderCornerControls(
              progress: _progress,
              settingsActive: _showQuickSettings,
              onToggleSettings: () {
                setState(() => _showQuickSettings = !_showQuickSettings);
              },
            ),
          ),
        ],
    );
  }
}

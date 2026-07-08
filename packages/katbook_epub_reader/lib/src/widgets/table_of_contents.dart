import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chapter_node.dart';
import '../models/reader_theme.dart';

/// Widget for displaying the table of contents in a drawer.
class TableOfContentsWidget extends StatelessWidget {
  /// Creates a new table of contents widget.
  const TableOfContentsWidget({
    super.key,
    required this.chapters,
    required this.themeData,
    required this.onChapterTap,
    this.currentParagraphIndex = -1,
    this.bookTitle,
    this.bookAuthor,
    this.coverImage,
    this.fontFamily,
    this.fontFamilyFallback,
    this.fontSize = 18,
    this.lineHeight = 1.65,
    this.fontWeight = FontWeight.normal,
  });

  /// List of chapters in the book.
  final List<ChapterNode> chapters;

  /// The current theme data.
  final ReaderThemeData themeData;

  /// Callback when a chapter is tapped.
  final void Function(ChapterNode chapter) onChapterTap;

  /// Index of the current paragraph being read (for highlighting active chapter).
  final int currentParagraphIndex;

  /// Title of the book.
  final String? bookTitle;

  /// Author of the book.
  final String? bookAuthor;

  /// Cover image data.
  final Uint8List? coverImage;

  /// Base font family for TOC text.
  final String? fontFamily;

  /// Fallback font families when [fontFamily] is null.
  final List<String>? fontFamilyFallback;

  /// Base font size (chapter titles use this minus a small offset).
  final double fontSize;

  /// Line height multiplier.
  final double lineHeight;

  /// Base font weight.
  final FontWeight fontWeight;

  TextStyle _baseStyle({Color? color, FontWeight? weight}) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: weight ?? fontWeight,
      color: color ?? themeData.textColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final flatChapters = _flattenChapters(chapters);
    final activeChapter = _activeChapter(flatChapters);

    return DefaultTextStyle(
      style: _baseStyle(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: _buildChaptersList(
          chapters,
          activeChapter: activeChapter,
        ),
      ),
    );
  }

  List<ChapterNode> _flattenChapters(List<ChapterNode> nodes) {
    final flat = <ChapterNode>[];
    for (final node in nodes) {
      flat.add(node);
      flat.addAll(_flattenChapters(node.children));
    }
    return flat;
  }

  ChapterNode? _activeChapter(List<ChapterNode> flatChapters) {
    if (currentParagraphIndex < 0) return null;

    ChapterNode? active;
    for (final chapter in flatChapters) {
      if (chapter.startIndex <= currentParagraphIndex) {
        active = chapter;
      } else {
        break;
      }
    }
    return active;
  }

  List<Widget> _buildChaptersList(
    List<ChapterNode> chapters, {
    required ChapterNode? activeChapter,
    int depth = 0,
  }) {
    final widgets = <Widget>[];

    for (final chapter in chapters) {
      widgets.add(
        _buildChapterTile(
          chapter,
          depth,
          isCurrentChapter: identical(chapter, activeChapter),
        ),
      );

      if (chapter.children.isNotEmpty) {
        widgets.addAll(
          _buildChaptersList(
            chapter.children,
            activeChapter: activeChapter,
            depth: depth + 1,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildChapterTile(
    ChapterNode chapter,
    int depth, {
    required bool isCurrentChapter,
  }) {
    final indentLevel = depth * 16.0;

    return Material(
      color: isCurrentChapter ? themeData.accentColor.withValues(alpha: 0.1) : Colors.transparent,
      child: InkWell(
        onTap: () => onChapterTap(chapter),
        child: Container(
          padding: EdgeInsets.only(
            left: 16.0 + indentLevel,
            right: 16.0,
            top: 12.0,
            bottom: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.title,
                style: _baseStyle(
                  color: isCurrentChapter ? themeData.accentColor : themeData.textColor,
                  weight: isCurrentChapter ? FontWeight.w600 : fontWeight,
                ).copyWith(
                  fontSize: fontSize - 4 - (depth * 1.0).clamp(0, 2),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (chapter.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '${chapter.children.length} sections',
                    style: _baseStyle(
                      color: themeData.secondaryTextColor,
                    ).copyWith(fontSize: fontSize - 6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

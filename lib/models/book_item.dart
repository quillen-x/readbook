import 'package:katbook_epub_reader/katbook_epub_reader.dart';

enum BookFormat { epub, mobi, azw, azw3, pdf, txt, markdown }

extension BookFormatX on BookFormat {
  String get label {
    switch (this) {
      case BookFormat.epub:
        return 'EPUB';
      case BookFormat.mobi:
        return 'MOBI';
      case BookFormat.azw:
        return 'AZW';
      case BookFormat.azw3:
        return 'AZW3';
      case BookFormat.pdf:
        return 'PDF';
      case BookFormat.txt:
        return 'TXT';
      case BookFormat.markdown:
        return 'MD';
    }
  }

  bool get isSupportedNow =>
      this == BookFormat.epub ||
      this == BookFormat.mobi ||
      this == BookFormat.azw ||
      this == BookFormat.azw3;
}

BookFormat? bookFormatFromExtension(String extension) {
  switch (extension.toLowerCase()) {
    case 'epub':
      return BookFormat.epub;
    case 'mobi':
      return BookFormat.mobi;
    case 'azw':
      return BookFormat.azw;
    case 'azw3':
      return BookFormat.azw3;
    case 'pdf':
      return BookFormat.pdf;
    case 'txt':
      return BookFormat.txt;
    case 'md':
    case 'markdown':
      return BookFormat.markdown;
    default:
      return null;
  }
}

/// 书架展示用书名，仅保留半角/全角左括号之前的内容。
String displayBookTitle(String title) {
  final halfIndex = title.indexOf('(');
  if (halfIndex != -1) {
    return title.substring(0, halfIndex).trim();
  }
  final fullIndex = title.indexOf('（');
  if (fullIndex != -1) {
    return title.substring(0, fullIndex).trim();
  }
  return title.trim();
}

class BookItem {
  const BookItem({
    required this.id,
    required this.title,
    this.author,
    required this.format,
    required this.originalPath,
    required this.epubPath,
    required this.addedAt,
    this.lastOpenedAt,
    this.readingPosition,
    this.progressPercent = 0,
    this.isFavorite = false,
    this.tags = const [],
    this.fileSizeBytes = 0,
    this.coverPath,
    this.contentHash,
  });

  final String id;
  final String title;
  final String? author;
  final BookFormat format;
  final String originalPath;
  final String epubPath;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final ReadingPosition? readingPosition;
  final double progressPercent;
  final bool isFavorite;
  final List<String> tags;
  final int fileSizeBytes;
  final String? coverPath;
  final String? contentHash;

  bool get isFinished => progressPercent >= 99.5;

  /// 书架展示用书名，仅保留半角/全角左括号之前的内容。
  String get displayTitle => displayBookTitle(title);

  BookItem copyWith({
    String? title,
    String? author,
    DateTime? lastOpenedAt,
    ReadingPosition? readingPosition,
    double? progressPercent,
    bool? isFavorite,
    List<String>? tags,
    int? fileSizeBytes,
    String? coverPath,
    String? contentHash,
  }) {
    return BookItem(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      originalPath: originalPath,
      epubPath: epubPath,
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      readingPosition: readingPosition ?? this.readingPosition,
      progressPercent: progressPercent ?? this.progressPercent,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      coverPath: coverPath ?? this.coverPath,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'format': format.name,
      'originalPath': originalPath,
      'epubPath': epubPath,
      'addedAt': addedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'readingPosition': readingPosition?.toJson(),
      'progressPercent': progressPercent,
      'isFavorite': isFavorite,
      'tags': tags,
      'fileSizeBytes': fileSizeBytes,
      'coverPath': coverPath,
      'contentHash': contentHash,
    };
  }

  factory BookItem.fromJson(Map<String, dynamic> json) {
    return BookItem(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String?,
      format: BookFormat.values.byName(json['format'] as String),
      originalPath: json['originalPath'] as String,
      epubPath: json['epubPath'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.parse(json['lastOpenedAt'] as String)
          : null,
      readingPosition: json['readingPosition'] != null
          ? ReadingPosition.fromJson(
              json['readingPosition'] as Map<String, dynamic>,
            )
          : null,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      coverPath: json['coverPath'] as String?,
      contentHash: json['contentHash'] as String?,
    );
  }
}

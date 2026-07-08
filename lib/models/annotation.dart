enum HighlightColor { yellow, green, blue, pink, purple }

enum AnnotationType { highlight, underline, strikethrough, bookmark }

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String bookId;
  final String chapterTitle;
  final int paragraphIndex;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterTitle': chapterTitle,
        'paragraphIndex': paragraphIndex,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        chapterTitle: json['chapterTitle'] as String,
        paragraphIndex: json['paragraphIndex'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String?,
      );
}

class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.text,
    required this.chapterTitle,
    required this.paragraphIndex,
    required this.color,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String bookId;
  final String text;
  final String chapterTitle;
  final int paragraphIndex;
  final HighlightColor color;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'text': text,
        'chapterTitle': chapterTitle,
        'paragraphIndex': paragraphIndex,
        'color': color.name,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        text: json['text'] as String,
        chapterTitle: json['chapterTitle'] as String,
        paragraphIndex: json['paragraphIndex'] as int,
        color: HighlightColor.values.byName(json['color'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String?,
      );
}

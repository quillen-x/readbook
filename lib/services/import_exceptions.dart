import '../models/book_item.dart';

class DuplicateBookException implements Exception {
  const DuplicateBookException(this.existing);

  final BookItem existing;

  @override
  String toString() => '书籍已在书架中：${existing.title}';
}

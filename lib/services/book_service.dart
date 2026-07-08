import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:katbook_epub_reader/katbook_epub_reader.dart';
import 'package:kindle_unpack/kindle_unpack.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/annotation.dart';
import '../models/book_item.dart';
import '../models/sidebar_section.dart';
import '../utils/download_books_paths.dart';
import 'import_exceptions.dart';

class BookService {
  BookService._();

  static final BookService instance = BookService._();

  static const _libraryFileName = 'library.json';
  static const _annotationsFileName = 'annotations.json';

  List<BookItem> _books = [];
  final Map<String, List<Bookmark>> _bookmarks = {};
  final Map<String, List<Highlight>> _highlights = {};
  bool _initialized = false;

  List<BookItem> get books => List.unmodifiable(_books);

  Future<void> initialize() async {
    if (_initialized) return;

    final libraryFile = await _libraryFile();
    if (await libraryFile.exists()) {
      final content = await libraryFile.readAsString();
      final data = jsonDecode(content) as List<dynamic>;
      _books = data
          .map((item) => BookItem.fromJson(item as Map<String, dynamic>))
          .where((book) => File(book.epubPath).existsSync())
          .toList();
    }

    await _loadAnnotations();
    _initialized = true;
  }

  Future<BookItem> importBook(String sourcePath) async {
    await initialize();

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('文件不存在: $sourcePath');
    }

    final extension = p.extension(sourcePath).replaceFirst('.', '');
    final format = bookFormatFromExtension(extension);
    if (format == null) {
      throw Exception('不支持的格式: .$extension');
    }
    if (!format.isSupportedNow) {
      throw Exception('${format.label} 格式即将支持，当前仅支持 EPUB / MOBI');
    }

    final bytes = await sourceFile.readAsBytes();
    final contentHash = sha256.convert(bytes).toString();
    final duplicate = _findByContentHash(contentHash);
    if (duplicate != null) {
      throw DuplicateBookException(duplicate);
    }

    final id = const Uuid().v4();
    final fileSizeBytes = bytes.length;
    final useSourceInPlace =
        format == BookFormat.epub && DownloadBooksPaths.isUnderRoot(sourcePath);

    late Uint8List epubBytes;
    late EpubBook epub;
    String title;
    String? author;

    if (format == BookFormat.epub) {
      epubBytes = bytes;
      epub = await EpubReader.readBook(epubBytes);
      title = epub.Title?.trim().isNotEmpty == true
          ? epub.Title!.trim()
          : p.basenameWithoutExtension(sourcePath);
      author = epub.Author?.trim().isNotEmpty == true ? epub.Author!.trim() : null;
    } else {
      final kindleBook = KindleBook.fromBytes(bytes);
      title = kindleBook.title.trim().isNotEmpty
          ? kindleBook.title.trim()
          : p.basenameWithoutExtension(sourcePath);
      author = kindleBook.exth?.authors.isNotEmpty == true
          ? kindleBook.exth!.authors.join('、')
          : null;
      epubBytes = kindleBook.toEpub();
      epub = await EpubReader.readBook(epubBytes);
    }

    late final String epubPath;
    if (useSourceInPlace) {
      epubPath = sourcePath;
    } else {
      final targetDir = DownloadBooksPaths.isUnderRoot(sourcePath)
          ? File(sourcePath).parent
          : await DownloadBooksPaths.importDirectory();
      final fileName =
          '${DownloadBooksPaths.sanitizePathComponent(title)}.epub';
      epubPath = p.join(targetDir.path, fileName);
      await File(epubPath).writeAsBytes(epubBytes);
    }

    final coverPath = await _saveCoverImage(epubPath, epub.CoverImage);

    final book = BookItem(
      id: id,
      title: title,
      author: author,
      format: format,
      originalPath: sourcePath,
      epubPath: epubPath,
      addedAt: DateTime.now(),
      fileSizeBytes: fileSizeBytes,
      coverPath: coverPath,
      contentHash: contentHash,
    );

    _books.insert(0, book);
    await _saveLibrary();
    return book;
  }

  BookItem? _findByContentHash(String contentHash) {
    for (final book in _books) {
      if (book.contentHash == contentHash) return book;
    }
    return null;
  }

  Future<String?> _saveCoverImage(
    String epubPath,
    img.Image? coverImage,
  ) async {
    if (coverImage == null) return null;

    final coverPath = p.join(
      p.dirname(epubPath),
      '${p.basenameWithoutExtension(epubPath)}.cover.jpg',
    );
    await File(coverPath).writeAsBytes(img.encodeJpg(coverImage, quality: 85));
    return coverPath;
  }

  Future<void> deleteBook(String id) async {
    await initialize();

    final index = _books.indexWhere((book) => book.id == id);
    if (index == -1) return;

    final book = _books.removeAt(index);
    final keepDownloadedFile = DownloadBooksPaths.isUnderRoot(book.epubPath);
    if (!keepDownloadedFile) {
      final epubFile = File(book.epubPath);
      if (await epubFile.exists()) {
        await epubFile.delete();
      }
      if (book.coverPath != null) {
        final coverFile = File(book.coverPath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
    }

    _bookmarks.remove(id);
    _highlights.remove(id);
    await _saveLibrary();
    await _saveAnnotations();
  }

  Future<void> updateProgress({
    required String id,
    required ReadingPosition position,
  }) async {
    await initialize();

    final index = _books.indexWhere((book) => book.id == id);
    if (index == -1) return;

    _books[index] = _books[index].copyWith(
      readingPosition: position,
      progressPercent: position.progressPercent,
      lastOpenedAt: DateTime.now(),
    );

    await _saveLibrary();
  }

  List<BookItem> sortedBooks(BookSort sort) {
    final list = List<BookItem>.from(_books);
    switch (sort) {
      case BookSort.lastRead:
        list.sort((a, b) {
          final aTime = a.lastOpenedAt ?? a.addedAt;
          final bTime = b.lastOpenedAt ?? b.addedAt;
          return bTime.compareTo(aTime);
        });
        break;
      case BookSort.lastAdded:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case BookSort.author:
        list.sort((a, b) => (a.author ?? '').compareTo(b.author ?? ''));
        break;
      case BookSort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case BookSort.progress:
        list.sort((a, b) => b.progressPercent.compareTo(a.progressPercent));
        break;
      case BookSort.fileSize:
        list.sort((a, b) => b.fileSizeBytes.compareTo(a.fileSizeBytes));
    }
    return list;
  }

  Future<Uint8List> loadEpubBytes(String epubPath) async {
    return File(epubPath).readAsBytes();
  }

  Future<void> _loadAnnotations() async {
    final file = await _annotationsFile();
    if (!await file.exists()) return;

    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _bookmarks
      ..clear()
      ..addAll(_decodeMap(data['bookmarks'], Bookmark.fromJson));
    _highlights
      ..clear()
      ..addAll(_decodeMap(data['highlights'], Highlight.fromJson));
  }

  Map<String, List<T>> _decodeMap<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw is! Map<String, dynamic>) return {};
    return raw.map((bookId, items) {
      final list = (items as List<dynamic>)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
      return MapEntry(bookId, list);
    });
  }

  Future<File> _libraryFile() async {
    final appDir = await getApplicationSupportDirectory();
    return File(p.join(appDir.path, _libraryFileName));
  }

  Future<File> _annotationsFile() async {
    final appDir = await getApplicationSupportDirectory();
    return File(p.join(appDir.path, _annotationsFileName));
  }

  Future<void> _saveLibrary() async {
    final libraryFile = await _libraryFile();
    final content = jsonEncode(_books.map((book) => book.toJson()).toList());
    await libraryFile.writeAsString(content);
  }

  Future<void> _saveAnnotations() async {
    final file = await _annotationsFile();
    final content = jsonEncode({
      'bookmarks': _bookmarks.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
      'highlights': _highlights.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
    });
    await file.writeAsString(content);
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes 字节';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

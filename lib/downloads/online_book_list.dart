import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'services/online_book_service.dart';
import 'widgets/book_detail_dialog.dart';
import 'widgets/book_page_view.dart';

class OnlineBookList extends ConsumerStatefulWidget {
  const OnlineBookList({super.key});

  @override
  ConsumerState<OnlineBookList> createState() => _OnlineBookListState();
}

class _OnlineBookListState extends ConsumerState<OnlineBookList> {
  final TextEditingController _passwordController =
      TextEditingController(text: '8866');
  final OnlineBookService _bookService = OnlineBookService();

  bool _isLoading = false;
  bool _isBookLoading = false;
  bool _isDownloading = false;
  bool _isBatchDownloading = false;
  String? _error;
  List<String> _lastDownloadTrace = [];
  int _batchTotal = 0;
  int _batchDone = 0;
  int _batchSuccess = 0;
  int _batchFailed = 0;
  int _batchSkipped = 0;
  String _batchCurrentTitle = '';
  List<String> _batchLogs = [];
  Set<String> _downloadedBookKeys = <String>{};
  static const String _tracePrefix = '[BookScraperTrace]';

  List<Map<String, String>> _catalog = [];
  List<Map<String, String>> _dushupaiTags = [];
  String? _selectedDushupaiCategory;
  String _selectedDushupaiType = 'category';
  String? _selectedDushupaiTagUrl;
  int _selectedDushupaiPage = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectedDushupaiCategory = 'xiaoshuo';
      _selectedDushupaiType = 'category';
      _selectedDushupaiTagUrl =
          'https://www.dushupai.com/book-category-xiaoshuo.html';
      _selectedDushupaiPage = 1;
      _fetchDushupaiBooks(refreshTags: true);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchDushupaiBooks({bool refreshTags = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _bookService.fetchDushupaiBooks(
        category: (_selectedDushupaiCategory ?? 'xiaoshuo').trim(),
        type: _selectedDushupaiType,
        page: _selectedDushupaiPage,
        sourceUrl: _selectedDushupaiTagUrl,
        includeTags: refreshTags,
      );

      setState(() {
        if (refreshTags && result.tags.isNotEmpty) {
          _dushupaiTags = result.tags;
          if (!_dushupaiTags
              .any((e) => e['slug'] == _selectedDushupaiCategory)) {
            _selectedDushupaiCategory = _dushupaiTags.first['slug'];
            _selectedDushupaiType = _dushupaiTags.first['type'] ?? 'category';
            _selectedDushupaiTagUrl = _dushupaiTags.first['url'];
          }
        }
        _catalog = result.catalog;
      });
      await _refreshDownloadedMarks();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openBookDetail(Map<String, String> book) async {
    setState(() => _isBookLoading = true);
    final downloadStatus = ValueNotifier<String?>(null);
    var downloadStatusActive = true;
    void updateDownloadStatus(String? status) {
      if (!downloadStatusActive) return;
      downloadStatus.value = status;
    }
    try {
      final url = book['url'] ?? '';
      final detail = await _bookService.fetchBookDetail(url);
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => BookDetailDialog(
          fallbackTitle: book['title'] ?? '书籍详情',
          detail: detail,
          downloadStatusListenable: downloadStatus,
          onDownload: (u) => _downloadFile(
            u,
            preferredBookTitle: (book['title'] ?? '').trim().isNotEmpty
                ? (book['title'] ?? '').trim()
                : detail.title.trim(),
            onStatusChange: updateDownloadStatus,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('详情获取失败：$e')),
      );
    } finally {
      downloadStatusActive = false;
      downloadStatus.dispose();
      if (mounted) {
        setState(() => _isBookLoading = false);
      }
    }
  }

  Future<void> _downloadFile(
    String url, {
    String? preferredBookTitle,
    ValueChanged<String?>? onStatusChange,
  }) async {
    if (_isDownloading || _isBatchDownloading) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在下载中，请稍候...')),
        );
      }
      return;
    }
    final title = (preferredBookTitle ?? '').trim();
    if (title.isNotEmpty && _isBookDownloadedByTitle(title)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已存在：$title')),
        );
      }
      return;
    }

    setState(() => _isDownloading = true);
    onStatusChange?.call('正在解析下载链接...');
    try {
      debugPrint('$_tracePrefix start download: $url');
      final categoryDirName = _bookService.currentCategoryFolderName(
        tags: _dushupaiTags,
        selectedCategory: _selectedDushupaiCategory,
        selectedType: _selectedDushupaiType,
      );
      onStatusChange?.call('正在下载文件，请稍候...');
      final result = await _bookService.downloadFile(
        url: url,
        password: _passwordController.text.trim(),
        categoryFolderName: categoryDirName,
        preferredBookTitle: preferredBookTitle,
        keepOriginalZip: false,
      );

      if (!mounted) return;
      setState(() {
        _lastDownloadTrace = result.trace;
      });
      await _refreshDownloadedMarks();
      _printTrace(result.trace);
      debugPrint('$_tracePrefix 下载源地址: $url');
      debugPrint('$_tracePrefix 本地保存地址: ${result.filePath}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载完成：${result.filePath}')),
      );
    } catch (e) {
      onStatusChange?.call('下载失败');
      if (!mounted) return;
      _printTrace(_lastDownloadTrace);
      debugPrint('$_tracePrefix failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载失败：$e')),
      );
    } finally {
      onStatusChange?.call(null);
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _downloadCurrentPageBooks() async {
    if (_isBatchDownloading || _isDownloading || _catalog.isEmpty) return;
    final books = List<Map<String, String>>.from(_catalog);
    final categoryDirName = _bookService.currentCategoryFolderName(
      tags: _dushupaiTags,
      selectedCategory: _selectedDushupaiCategory,
      selectedType: _selectedDushupaiType,
    );
    setState(() {
      _isBatchDownloading = true;
      _batchTotal = books.length;
      _batchDone = 0;
      _batchSuccess = 0;
      _batchFailed = 0;
      _batchSkipped = 0;
      _batchCurrentTitle = '';
      _batchLogs = [];
    });

    for (var i = 0; i < books.length; i++) {
      final book = books[i];
      final title = (book['title'] ?? '未命名').trim();
      final url = (book['url'] ?? '').trim();
      setState(() {
        _batchCurrentTitle = title;
      });

      if (_isBookDownloadedByTitle(title)) {
        if (!mounted) return;
        setState(() {
          _batchDone += 1;
          _batchSkipped += 1;
          _batchLogs.add('${i + 1}. 跳过：$title（已存在）');
        });
        continue;
      }

      var success = false;
      Object? lastError;
      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          if (url.isEmpty) {
            throw Exception('链接为空');
          }
          debugPrint(
            '$_tracePrefix batch item ${i + 1}/${books.length} attempt $attempt: $url',
          );
          final result = await _bookService.downloadFile(
            url: url,
            password: _passwordController.text.trim(),
            categoryFolderName: categoryDirName,
            preferredBookTitle: title,
            keepOriginalZip: false,
          );
          if (!mounted) return;
          _printTrace(result.trace);
          debugPrint('$_tracePrefix 下载源地址: $url');
          debugPrint('$_tracePrefix 本地保存地址: ${result.filePath}');
          setState(() {
            _lastDownloadTrace = result.trace;
          });
          success = true;
          break;
        } catch (e) {
          lastError = e;
          debugPrint(
            '$_tracePrefix batch item ${i + 1}/${books.length} failed at attempt $attempt: $e',
          );
          if (attempt < 2) {
            final retryDelay = _bookService.isCtfileLimitError(e)
                ? const Duration(seconds: 20)
                : const Duration(seconds: 2);
            await Future.delayed(retryDelay);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _batchDone += 1;
        if (success) {
          _batchSuccess += 1;
          _batchLogs.add('${i + 1}. 成功：$title');
        } else {
          _batchFailed += 1;
          _batchLogs.add('${i + 1}. 失败：$title（$lastError）');
        }
      });
      if (success) {
        await _refreshDownloadedMarks();
      }
    }

    if (!mounted) return;
    setState(() {
      _isBatchDownloading = false;
      _batchCurrentTitle = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '本页下载完成：成功 $_batchSuccess，失败 $_batchFailed，跳过 $_batchSkipped',
        ),
      ),
    );
  }

  bool _isBookDownloadedByTitle(String title) {
    final key = _bookService.sanitizePathComponent(
      _bookService.normalizeBookTitle(title.trim()),
    );
    return key.isNotEmpty && _downloadedBookKeys.contains(key);
  }

  Future<void> _refreshDownloadedMarks() async {
    final categoryDirName = _bookService.currentCategoryFolderName(
      tags: _dushupaiTags,
      selectedCategory: _selectedDushupaiCategory,
      selectedType: _selectedDushupaiType,
    );
    final dir = await _bookService.resolveWritableDownloadDir(
      subFolder: categoryDirName,
    );
    final files = dir.existsSync()
        ? dir
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .toList()
        : <String>[];
    final keys = <String>{};
    for (final filePath in files) {
      final base = filePath.split('/').last;
      if (base.startsWith('.')) continue;
      final noExt = base.contains('.')
          ? base.substring(0, base.lastIndexOf('.'))
          : base;
      final key = _bookService.sanitizePathComponent(
        _bookService.normalizeBookTitle(noExt.trim()),
      );
      if (key.isNotEmpty) {
        keys.add(key);
      }
    }
    if (!mounted) return;
    setState(() {
      _downloadedBookKeys = keys;
      _catalog = _catalog.map((book) {
        final title = (book['title'] ?? '').trim();
        final key = _bookService.sanitizePathComponent(
          _bookService.normalizeBookTitle(title),
        );
        return {
          ...book,
          'downloaded': (key.isNotEmpty && keys.contains(key)) ? '1' : '0',
        };
      }).toList();
    });
  }

  void _printTrace(List<String> trace) {
    if (trace.isEmpty) {
      debugPrint('$_tracePrefix (empty trace)');
      return;
    }
    for (final line in trace) {
      debugPrint('$_tracePrefix $line');
    }
  }

  void _onTagTap(Map<String, String> tag) {
    final slug = tag['slug'] ?? '';
    if (slug.isEmpty) return;
    setState(() {
      _selectedDushupaiCategory = slug;
      _selectedDushupaiType = tag['type'] ?? 'category';
      _selectedDushupaiTagUrl = tag['url'];
      _selectedDushupaiPage = 1;
    });
    _fetchDushupaiBooks();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return BookPageView(
      passwordController: _passwordController,
      cardBackgroundOpacity: settings.bookCardBackgroundOpacity,
      isLoading: _isLoading,
      isBookLoading: _isBookLoading,
      isDownloading: _isDownloading,
      isBatchDownloading: _isBatchDownloading,
      tags: _dushupaiTags,
      selectedCategory: _selectedDushupaiCategory,
      selectedType: _selectedDushupaiType,
      selectedPage: _selectedDushupaiPage,
      lastDownloadTrace: _lastDownloadTrace,
      batchTotal: _batchTotal,
      batchDone: _batchDone,
      batchSuccess: _batchSuccess,
      batchFailed: _batchFailed,
      batchSkipped: _batchSkipped,
      batchCurrentTitle: _batchCurrentTitle,
      batchLogs: _batchLogs,
      errorText: _error,
      catalog: _catalog,
      onTagTap: _onTagTap,
      onPrevPage: () {
        setState(() => _selectedDushupaiPage -= 1);
        _fetchDushupaiBooks();
      },
      onNextPage: () {
        setState(() => _selectedDushupaiPage += 1);
        _fetchDushupaiBooks();
      },
      onDownloadCurrentPage: _downloadCurrentPageBooks,
      onOpenBook: _openBookDetail,
    );
  }
}

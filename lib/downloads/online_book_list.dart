import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../utils/download_books_paths.dart';
import 'services/online_book_service.dart';
import 'services/sobooks_service.dart';
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
  final SobooksService _sobooks = SobooksService();
  String _source = 'dushupai';
  final Map<String, _SourceSnapshot> _sourceSnapshots = {};

  bool _isLoading = false;
  bool _isBookLoading = false;
  bool _isDownloading = false;
  bool _isBatchDownloading = false;
  bool _isBatchPaused = false;
  bool _batchLoopRunning = false;
  List<Map<String, String>> _batchBooks = [];
  int _batchIndex = 0;
  String _batchCategoryDirName = '';
  String? _error;
  List<String> _lastDownloadTrace = [];
  int _batchTotal = 0;
  int _batchDone = 0;
  int _batchSuccess = 0;
  int _batchFailed = 0;
  int _batchSkipped = 0;
  String _batchCurrentTitle = '';
  String _downloadTitle = '';
  int _downloadReceived = 0;
  int? _downloadTotal;
  List<String> _batchLogs = [];
  String _batchLabel = '批量下载';
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
      _fetchCurrentBooks(refreshTags: true, selectFirstTag: true);
    });
  }

  @override
  void dispose() {
    _bookService.requestPause();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatFetchError(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : text;
  }

  bool get _isSobooks => _source == 'sobooks';

  void _storeSourceState() {
    _sourceSnapshots[_source] = _SourceSnapshot(
      catalog: List<Map<String, String>>.from(_catalog),
      tags: List<Map<String, String>>.from(_dushupaiTags),
      selectedCategory: _selectedDushupaiCategory,
      selectedType: _selectedDushupaiType,
      selectedTagUrl: _selectedDushupaiTagUrl,
      page: _selectedDushupaiPage,
      error: _error,
    );
  }

  void _restoreSourceState(String source) {
    final snap = _sourceSnapshots[source];
    if (snap == null) {
      _catalog = [];
      _dushupaiTags = source == 'sobooks'
          ? List<Map<String, String>>.from(SobooksService.defaultTags)
          : [];
      _selectedDushupaiCategory = source == 'sobooks' ? 'latest' : 'xiaoshuo';
      _selectedDushupaiType = 'category';
      _selectedDushupaiTagUrl = source == 'sobooks'
          ? '${SobooksService.siteOrigin}/'
          : 'https://www.dushupai.com/book-category-xiaoshuo.html';
      _selectedDushupaiPage = 1;
      _error = null;
      return;
    }
    _catalog = List<Map<String, String>>.from(snap.catalog);
    _dushupaiTags = List<Map<String, String>>.from(snap.tags);
    _selectedDushupaiCategory = snap.selectedCategory;
    _selectedDushupaiType = snap.selectedType;
    _selectedDushupaiTagUrl = snap.selectedTagUrl;
    _selectedDushupaiPage = snap.page;
    _error = snap.error;
  }

  Future<void> _switchSource(String source) async {
    if (source == _source) return;
    _storeSourceState();
    setState(() {
      _source = source;
      _restoreSourceState(source);
    });
    if (_catalog.isEmpty) {
      await _fetchCurrentBooks(
        refreshTags: true,
        selectFirstTag: source == 'sobooks',
      );
    } else {
      await _refreshDownloadedMarks();
    }
  }

  Future<void> _fetchCurrentBooks({
    bool refreshTags = false,
    bool selectFirstTag = false,
  }) async {
    if (_isSobooks) {
      await _fetchSobooksBooks(
        refreshTags: refreshTags,
        selectFirstTag: selectFirstTag,
      );
      return;
    }
    await _fetchDushupaiBooks(
      refreshTags: refreshTags,
      selectFirstTag: selectFirstTag,
    );
  }

  Future<void> _fetchSobooksBooks({
    bool refreshTags = false,
    bool selectFirstTag = false,
  }) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _sobooks.fetchBooks(
        category: (_selectedDushupaiCategory ?? 'latest').trim(),
        page: _selectedDushupaiPage,
        sourceUrl: _selectedDushupaiTagUrl,
        includeTags: refreshTags,
      );

      var reloadFirstTag = false;
      setState(() {
        if (refreshTags && result.tags.isNotEmpty) {
          _dushupaiTags = result.tags;
          final first = _dushupaiTags.first;
          final firstSlug = first['slug'];
          final firstType = first['type'] ?? 'category';
          final firstUrl = first['url'];
          final selectedInTags = _dushupaiTags.any(
            (e) =>
                e['slug'] == _selectedDushupaiCategory &&
                (e['type'] ?? 'category') == _selectedDushupaiType,
          );
          final alreadyFirst = _selectedDushupaiCategory == firstSlug &&
              _selectedDushupaiType == firstType &&
              _selectedDushupaiTagUrl == firstUrl;
          if (selectFirstTag || !selectedInTags) {
            _selectedDushupaiCategory = firstSlug;
            _selectedDushupaiType = firstType;
            _selectedDushupaiTagUrl = firstUrl;
            _selectedDushupaiPage = 1;
            reloadFirstTag = !alreadyFirst;
          }
        }
        if (!reloadFirstTag) {
          _catalog = result.catalog;
        }
      });
      if (reloadFirstTag) {
        await _fetchSobooksBooks();
        return;
      }
      await _refreshDownloadedMarks();
    } catch (e) {
      setState(() => _error = _formatFetchError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchDushupaiBooks({
    bool refreshTags = false,
    bool selectFirstTag = false,
  }) async {
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

      var reloadFirstTag = false;
      setState(() {
        if (refreshTags && result.tags.isNotEmpty) {
          _dushupaiTags = result.tags;
          final first = _dushupaiTags.first;
          final firstSlug = first['slug'];
          final firstType = first['type'] ?? 'category';
          final firstUrl = first['url'];
          final selectedInTags = _dushupaiTags.any(
            (e) =>
                e['slug'] == _selectedDushupaiCategory &&
                (e['type'] ?? 'category') == _selectedDushupaiType,
          );
          final alreadyFirst = _selectedDushupaiCategory == firstSlug &&
              _selectedDushupaiType == firstType &&
              _selectedDushupaiTagUrl == firstUrl;
          if (selectFirstTag || !selectedInTags) {
            _selectedDushupaiCategory = firstSlug;
            _selectedDushupaiType = firstType;
            _selectedDushupaiTagUrl = firstUrl;
            _selectedDushupaiPage = 1;
            reloadFirstTag = !alreadyFirst;
          }
        }
        if (!reloadFirstTag) {
          _catalog = result.catalog;
        }
      });
      if (reloadFirstTag) {
        await _fetchDushupaiBooks();
        return;
      }
      await _refreshDownloadedMarks();
    } catch (e) {
      setState(() => _error = _formatFetchError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onOpenBook(Map<String, String> book) async {
    if ((book['downloaded'] ?? '0') == '1') {
      await _revealDownloadedBook(book);
      return;
    }
    await _openBookDetail(book);
  }

  Future<void> _revealDownloadedBook(Map<String, String> book) async {
    try {
      var localPath = (book['localPath'] ?? '').trim();
      if (localPath.isEmpty || !File(localPath).existsSync()) {
        localPath = await _findDownloadedBookPath(book['title'] ?? '') ?? '';
      }
      if (localPath.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到本地文件')),
        );
        return;
      }
      await DownloadBooksPaths.revealFile(localPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件夹：$e')),
      );
    }
  }

  Future<String?> _findDownloadedBookPath(String title) async {
    final key = _bookService.sanitizePathComponent(
      _bookService.normalizeBookTitle(title.trim()),
    );
    if (key.isEmpty) return null;
    final paths = await _scannedDownloadedBookPaths();
    return paths[key];
  }

  Future<Map<String, String>> _scannedDownloadedBookPaths() async {
    final categoryDirName = _currentFolderName();
    final dir = await _bookService.resolveWritableDownloadDir(
      subFolder: categoryDirName,
    );
    final files = dir.existsSync()
        ? dir.listSync().whereType<File>().map((f) => f.path).toList()
        : <String>[];
    final keyToPath = <String, String>{};
    for (final filePath in files) {
      final base = filePath.split(Platform.pathSeparator).last;
      if (base.startsWith('.')) continue;
      final noExt = base.contains('.')
          ? base.substring(0, base.lastIndexOf('.'))
          : base;
      final key = _bookService.sanitizePathComponent(
        _bookService.normalizeBookTitle(noExt.trim()),
      );
      if (key.isEmpty) continue;
      final existing = keyToPath[key];
      if (existing == null || _isPreferredBookFile(filePath, existing)) {
        keyToPath[key] = filePath;
      }
    }
    return keyToPath;
  }

  bool _isPreferredBookFile(String candidate, String current) {
    const preferred = ['.epub', '.mobi', '.azw3', '.pdf'];
    final next = candidate.toLowerCase();
    final prev = current.toLowerCase();
    final nextPreferred = preferred.any(next.endsWith);
    final prevPreferred = preferred.any(prev.endsWith);
    return nextPreferred && !prevPreferred;
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
      final detail = _sobooks.isSobooksUrl(url)
          ? await _sobooks.fetchBookDetail(url)
          : await _bookService.fetchBookDetail(url);
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

    setState(() {
      _isDownloading = true;
      _downloadTitle = title.isNotEmpty ? title : '下载中';
      _downloadReceived = 0;
      _downloadTotal = null;
    });
    _bookService.clearPause();
    onStatusChange?.call('正在解析下载链接...');
    try {
      debugPrint('$_tracePrefix start download: $url');
      final categoryDirName = _currentFolderName();
      onStatusChange?.call('正在下载文件，请稍候...');
      final target = await _resolveDownloadTarget(url);
      final result = await _bookService.downloadFile(
        url: target.url,
        password: target.password,
        categoryFolderName: categoryDirName,
        preferredBookTitle: preferredBookTitle,
        keepOriginalZip: false,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadReceived = received;
              _downloadTotal = total;
            });
          }
          onStatusChange?.call(
            _downloadProgressLabel(preferredBookTitle ?? '下载中', received, total),
          );
        },
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
      if (_bookService.isDownloadPaused(e)) {
        onStatusChange?.call('已暂停');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已暂停下载')),
        );
      } else if (_bookService.isDownloadSizeSkipped(e)) {
        onStatusChange?.call('已跳过');
        if (!mounted) return;
        _printTrace(_lastDownloadTrace);
        debugPrint('$_tracePrefix skipped oversized file: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      } else {
        onStatusChange?.call('下载失败');
        if (!mounted) return;
        _printTrace(_lastDownloadTrace);
        debugPrint('$_tracePrefix failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    } finally {
      onStatusChange?.call(null);
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadTitle = '';
          _downloadReceived = 0;
          _downloadTotal = null;
        });
      }
    }
  }

  void _pauseActiveDownload() {
    _bookService.requestPause();
    if (!mounted) return;
    if (_isBatchDownloading) {
      setState(() => _isBatchPaused = true);
    }
  }

  Future<void> _onDownloadButtonPressed() async {
    if (_isBatchDownloading && _batchLabel == '同步封面') return;
    if (_isBatchDownloading && !_isBatchPaused) {
      _pauseActiveDownload();
      return;
    }
    if (_isDownloading && !_isBatchDownloading) {
      _pauseActiveDownload();
      return;
    }
    if (_isBatchPaused) {
      await _resumeBatchDownload();
      return;
    }
    await _startBatchDownload();
  }

  Future<void> _startBatchDownload() async {
    if (_isBatchDownloading || _isDownloading || _catalog.isEmpty) return;
    _bookService.clearPause();
    _batchBooks = List<Map<String, String>>.from(_catalog);
    _batchIndex = 0;
    _batchCategoryDirName = _currentFolderName();
    setState(() {
      _isBatchDownloading = true;
      _isBatchPaused = false;
      _batchLabel = '批量下载';
      _batchTotal = _batchBooks.length;
      _batchDone = 0;
      _batchSuccess = 0;
      _batchFailed = 0;
      _batchSkipped = 0;
      _batchCurrentTitle = '';
      _downloadReceived = 0;
      _downloadTotal = null;
      _batchLogs = [];
    });
    await _runBatchDownload();
  }

  Future<void> _resumeBatchDownload() async {
    if (!_isBatchPaused || _batchLoopRunning) return;
    _bookService.clearPause();
    setState(() => _isBatchPaused = false);
    await _runBatchDownload();
  }

  Future<void> _runBatchDownload() async {
    if (_batchLoopRunning) return;
    _batchLoopRunning = true;
    final books = _batchBooks;
    final categoryDirName = _batchCategoryDirName;

    try {
      for (var i = _batchIndex; i < books.length; i++) {
        _batchIndex = i;
        if (!mounted) return;
        if (_bookService.isPauseRequested) {
          setState(() => _isBatchPaused = true);
          return;
        }

        final book = books[i];
        final title = (book['title'] ?? '未命名').trim();
        final url = (book['url'] ?? '').trim();
        setState(() {
          _batchCurrentTitle = title;
          _downloadReceived = 0;
          _downloadTotal = null;
        });

        if (_isBookDownloadedByTitle(title)) {
          setState(() {
            _batchDone += 1;
            _batchSkipped += 1;
            _batchLogs.add('${i + 1}. 跳过：$title（已存在）');
          });
          _batchIndex = i + 1;
          continue;
        }

        var success = false;
        var skippedOversized = false;
        var paused = false;
        Object? lastError;
        for (var attempt = 1; attempt <= 2; attempt++) {
          try {
            if (url.isEmpty) {
              throw Exception('链接为空');
            }
            debugPrint(
              '$_tracePrefix batch item ${i + 1}/${books.length} attempt $attempt: $url',
            );
            final target = await _resolveDownloadTarget(url);
            final result = await _bookService.downloadFile(
              url: target.url,
              password: target.password,
              categoryFolderName: categoryDirName,
              preferredBookTitle: title,
              keepOriginalZip: false,
              onProgress: (received, total) {
                if (!mounted) return;
                setState(() {
                  _batchCurrentTitle = title;
                  _downloadReceived = received;
                  _downloadTotal = total;
                });
              },
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
            if (_bookService.isDownloadPaused(e)) {
              paused = true;
              break;
            }
            if (_bookService.isDownloadSizeSkipped(e)) {
              skippedOversized = true;
              debugPrint(
                '$_tracePrefix batch item ${i + 1}/${books.length} skipped oversized: $e',
              );
              break;
            }
            debugPrint(
              '$_tracePrefix batch item ${i + 1}/${books.length} failed at attempt $attempt: $e',
            );
            if (attempt < 2) {
              final retryDelay = _bookService.isCtfileLimitError(e)
                  ? const Duration(seconds: 20)
                  : const Duration(seconds: 2);
              try {
                await _bookService.delayUnlessPaused(retryDelay);
              } catch (pauseError) {
                if (_bookService.isDownloadPaused(pauseError)) {
                  paused = true;
                  break;
                }
                rethrow;
              }
            }
          }
        }

        if (!mounted) return;
        if (paused) {
          setState(() {
            _isBatchPaused = true;
            _batchLogs.add('${i + 1}. 暂停：$title');
          });
          return;
        }

        setState(() {
          _batchDone += 1;
          if (success) {
            _batchSuccess += 1;
            _batchLogs.add('${i + 1}. 成功：$title');
          } else if (skippedOversized) {
            _batchSkipped += 1;
            _batchLogs.add('${i + 1}. 跳过：$title（文件过大，上限 20MB）');
            _downloadReceived = 0;
            _downloadTotal = null;
          } else {
            _batchFailed += 1;
            _batchLogs.add('${i + 1}. 失败：$title（$lastError）');
          }
        });
        _batchIndex = i + 1;
        if (success) {
          await _refreshDownloadedMarks();
        }
      }

      if (!mounted) return;
      setState(() {
        _isBatchDownloading = false;
        _isBatchPaused = false;
        _batchCurrentTitle = '';
        _downloadReceived = 0;
        _downloadTotal = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '本页下载完成：成功 $_batchSuccess，失败 $_batchFailed，跳过 $_batchSkipped',
          ),
        ),
      );
    } finally {
      _batchLoopRunning = false;
    }
  }

  String _currentFolderName() {
    if (_isSobooks) {
      final tag = _dushupaiTags.cast<Map<String, String>?>().firstWhere(
            (e) =>
                (e?['slug'] ?? '') == (_selectedDushupaiCategory ?? '') &&
                (e?['type'] ?? 'category') == _selectedDushupaiType,
            orElse: () => null,
          );
      final raw = (tag?['title'] ?? _selectedDushupaiCategory ?? '最新').trim();
      final name = _bookService.sanitizePathComponent(
        raw.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim(),
      );
      return name.isEmpty ? 'SoBooks' : 'SoBooks-$name';
    }
    return _bookService.currentCategoryFolderName(
      tags: _dushupaiTags,
      selectedCategory: _selectedDushupaiCategory,
      selectedType: _selectedDushupaiType,
    );
  }

  Future<SobooksResolvedDownload> _resolveDownloadTarget(String url) async {
    final lower = url.toLowerCase();
    if (lower.contains('quark.cn') ||
        lower.contains('pan.baidu.com') ||
        lower.contains('aliyundrive.com') ||
        lower.contains('alipan.com')) {
      throw Exception('暂仅支持城通网盘自动下载，请改用城通链接');
    }
    if (_sobooks.isSobooksUrl(url)) {
      return _sobooks.resolveCtfileDownload(url);
    }
    if (lower.contains('ctfile.com')) {
      final uri = Uri.tryParse(url);
      return SobooksResolvedDownload(
        url: url,
        password: uri?.queryParameters['pwd'] ??
            uri?.queryParameters['p'] ??
            _passwordController.text.trim(),
      );
    }
    return SobooksResolvedDownload(
      url: url,
      password: _passwordController.text.trim(),
    );
  }

  String _downloadProgressLabel(String title, int received, int? total) {
    if (total != null && total > 0) {
      final pct = ((received / total) * 100).clamp(0, 100).toStringAsFixed(0);
      return '$title  $pct%';
    }
    return title;
  }

  bool _isBookDownloadedByTitle(String title) {
    final key = _bookService.sanitizePathComponent(
      _bookService.normalizeBookTitle(title.trim()),
    );
    return key.isNotEmpty && _downloadedBookKeys.contains(key);
  }

  Future<void> _refreshDownloadedMarks() async {
    final keyToPath = await _scannedDownloadedBookPaths();
    if (!mounted) return;
    setState(() {
      _downloadedBookKeys = keyToPath.keys.toSet();
      _catalog = _catalog.map((book) {
        final title = (book['title'] ?? '').trim();
        final key = _bookService.sanitizePathComponent(
          _bookService.normalizeBookTitle(title),
        );
        final localPath = keyToPath[key];
        return {
          ...book,
          'downloaded': localPath != null ? '1' : '0',
          if (localPath != null) 'localPath': localPath,
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
    _fetchCurrentBooks();
  }

  String _tagDisplayName(Map<String, String> tag) {
    final raw = (tag['title'] ?? tag['slug'] ?? '该分类').trim();
    return raw.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim();
  }

  Future<void> _onTagLongPress(Map<String, String> tag) async {
    if (_isSobooks) return;
    if (_isBatchDownloading || _isDownloading || _isLoading) return;
    final name = _tagDisplayName(tag);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载分类目录'),
        content: Text('将下载「$name」下所有书名和封面图，不会下载电子书。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始下载'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _downloadCategoryCatalog(tag);
  }

  Future<void> _downloadCategoryCatalog(Map<String, String> tag) async {
    if (_isBatchDownloading || _isDownloading) return;
    final slug = (tag['slug'] ?? '').trim();
    if (slug.isEmpty) return;
    final type = tag['type'] ?? 'category';
    final name = _tagDisplayName(tag);
    final categoryDirName = _bookService.currentCategoryFolderName(
      tags: _dushupaiTags,
      selectedCategory: slug,
      selectedType: type,
    );

    setState(() {
      _isBatchDownloading = true;
      _batchLabel = '同步封面';
      _batchTotal = 0;
      _batchDone = 0;
      _batchSuccess = 0;
      _batchFailed = 0;
      _batchSkipped = 0;
      _batchCurrentTitle = '正在获取「$name」书目...';
      _batchLogs = [];
    });

    try {
      final result = await _bookService.downloadCategoryNamesAndCovers(
        category: slug,
        type: type,
        sourceUrl: tag['url'],
        categoryFolderName: categoryDirName,
        categoryTitle: name,
        onPage: (page, maxPage, found) {
          if (!mounted) return;
          setState(() {
            _batchTotal = found;
            _batchDone = found;
            _batchCurrentTitle = '正在获取第 $page/$maxPage 页，已找到 $found 本';
          });
        },
        onCover: (done, total, title) {
          if (!mounted) return;
          setState(() {
            _batchTotal = total;
            _batchDone = done;
            _batchCurrentTitle = title;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _batchDone = result.bookCount;
        _batchTotal = result.bookCount;
        _batchSuccess = result.coverSuccess;
        _batchFailed = result.coverFailed;
        _batchSkipped = result.coverSkipped;
        _batchCurrentTitle = '';
        _batchLogs = [
          '书目 ${result.bookCount} 本，已保存到 ${result.catalogPath}',
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '「$name」目录已保存：书名 ${result.bookCount}，封面成功 ${result.coverSuccess}，失败 ${result.coverFailed}，跳过 ${result.coverSkipped}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _batchLogs = ['同步失败：$e'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步分类目录失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBatchDownloading = false;
          _batchCurrentTitle = '';
        });
      }
    }
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
      isBatchPaused: _isBatchPaused,
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
      downloadTitle: _downloadTitle,
      downloadReceived: _downloadReceived,
      downloadTotal: _downloadTotal,
      batchLogs: _batchLogs,
      batchLabel: _batchLabel,
      errorText: _error,
      catalog: _catalog,
      selectedSource: _source,
      onSourceChanged: _switchSource,
      canTagLongPress: !_isSobooks,
      onTagTap: _onTagTap,
      onTagLongPress: _onTagLongPress,
      onPrevPage: () {
        if (_selectedDushupaiPage <= 1) return;
        setState(() => _selectedDushupaiPage -= 1);
        _fetchCurrentBooks();
      },
      onNextPage: () {
        setState(() => _selectedDushupaiPage += 1);
        _fetchCurrentBooks();
      },
      onDownloadCurrentPage: _onDownloadButtonPressed,
      onOpenBook: _onOpenBook,
      onRetry: () => _fetchCurrentBooks(
        refreshTags: _dushupaiTags.isEmpty,
        selectFirstTag: _dushupaiTags.isEmpty,
      ),
    );
  }
}

class _SourceSnapshot {
  const _SourceSnapshot({
    required this.catalog,
    required this.tags,
    required this.selectedCategory,
    required this.selectedType,
    required this.selectedTagUrl,
    required this.page,
    required this.error,
  });

  final List<Map<String, String>> catalog;
  final List<Map<String, String>> tags;
  final String? selectedCategory;
  final String selectedType;
  final String? selectedTagUrl;
  final int page;
  final String? error;
}

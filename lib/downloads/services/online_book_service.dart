import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../utils/download_books_paths.dart';

class FetchBooksResult {
  const FetchBooksResult({
    required this.catalog,
    required this.tags,
  });

  final List<Map<String, String>> catalog;
  final List<Map<String, String>> tags;
}

class BookDetailData {
  const BookDetailData({
    required this.title,
    required this.intro,
    required this.links,
  });

  final String title;
  final String intro;
  final List<String> links;
}

class DownloadResult {
  const DownloadResult({
    required this.filePath,
    required this.trace,
  });

  final String filePath;
  final List<String> trace;
}

class _ResolvedDownloadTarget {
  const _ResolvedDownloadTarget({
    required this.uri,
    required this.response,
    required this.trace,
  });

  final Uri uri;
  final http.Response response;
  final List<String> trace;
}

class OnlineBookService {
  static const String _tracePrefix = '[BookScraperTrace]';

  /// 城通网盘免费账号仅允许单任务下载，需串行并留出释放间隔。
  static Future<void> _ctfileDownloadGate = Future.value();
  static DateTime? _lastCtfileDownloadCompletedAt;
  static const Duration _ctfileMinInterval = Duration(seconds: 15);

  static const String ctfileLimitErrorMessage =
      '城通网盘免费账号仅支持同时 1 个下载任务。'
      '请关闭浏览器或其他客户端中的城通下载，等待约 15 秒后再试。';

  Future<FetchBooksResult> fetchDushupaiBooks({
    required String category,
    required String type,
    required int page,
    String? sourceUrl,
    bool includeTags = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final url = buildDushupaiListUrl(
      type: type,
      category: category.trim(),
      page: safePage,
      sourceUrl: sourceUrl,
    );
    final resp = await http.get(Uri.parse(url), headers: defaultHeaders());
    if (resp.statusCode != 200) {
      throw Exception('读取失败：HTTP ${resp.statusCode}');
    }

    final html = decodeBody(resp);
    return FetchBooksResult(
      catalog: parseBookList(html, Uri.parse(url)),
      tags: includeTags ? parseDushupaiTags(html) : const <Map<String, String>>[],
    );
  }

  Future<BookDetailData> fetchBookDetail(String url) async {
    final resp = await http.get(Uri.parse(url), headers: defaultHeaders());
    if (resp.statusCode != 200) {
      throw Exception('获取书籍详情失败：HTTP ${resp.statusCode}');
    }
    final parsed = parseBookDetail(decodeBody(resp), Uri.parse(url));
    return BookDetailData(
      title: parsed['title']?.toString() ?? '',
      intro: parsed['intro']?.toString() ?? '',
      links: List<String>.from(parsed['links'] as List<String>),
    );
  }

  Future<DownloadResult> downloadFile({
    required String url,
    required String password,
    required String categoryFolderName,
    String? preferredBookTitle,
    bool keepOriginalZip = true,
  }) {
    return _runSerializedCtfileDownload(() async {
      final resolved = await _resolveDownloadTarget(rawUrl: url, password: password);
      final sourceName = extractFileName(
        resolved.uri,
        resolved.response.headers['content-disposition'],
      );
      final fileName = buildDisplayFileName(sourceName, preferredBookTitle);
      final saveDir = await resolveWritableDownloadDir(subFolder: categoryFolderName);
      final zipFile = File(p.join(saveDir.path, fileName));
      await zipFile.writeAsBytes(resolved.response.bodyBytes, flush: true);

      final finalPath = await _extractBookFromZipIfNeeded(
        zipFile: zipFile,
        keepOriginalZip: keepOriginalZip,
        preferredBookTitle: preferredBookTitle,
      );

      return DownloadResult(filePath: finalPath, trace: resolved.trace);
    });
  }

  Future<T> _runSerializedCtfileDownload<T>(Future<T> Function() action) async {
    final previous = _ctfileDownloadGate;
    final release = Completer<void>();
    _ctfileDownloadGate = release.future;
    await previous;

    final lastCompleted = _lastCtfileDownloadCompletedAt;
    if (lastCompleted != null) {
      final elapsed = DateTime.now().difference(lastCompleted);
      final remaining = _ctfileMinInterval - elapsed;
      if (remaining > Duration.zero) {
        debugPrint(
          '$_tracePrefix ctfile slot cooldown: wait ${remaining.inSeconds}s',
        );
        await Future.delayed(remaining);
      }
    }

    try {
      return await action();
    } finally {
      _lastCtfileDownloadCompletedAt = DateTime.now();
      release.complete();
    }
  }

  String buildDushupaiListUrl({
    required String type,
    required String category,
    required int page,
    String? sourceUrl,
  }) {
    final safePage = page < 1 ? 1 : page;
    final src = (sourceUrl ?? '').trim();
    if (src.isNotEmpty) {
      final uri = Uri.parse(src);
      final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (seg.isNotEmpty) {
        final withPage = seg.replaceFirstMapped(
          RegExp(r'-(\d+)\.html$', caseSensitive: false),
          (_) => '-$safePage.html',
        );
        if (withPage != seg) {
          return uri
              .replace(pathSegments: [...uri.pathSegments]..[uri.pathSegments.length - 1] = withPage)
              .toString();
        }
        final noPage = seg.replaceFirstMapped(
          RegExp(r'\.html$', caseSensitive: false),
          (_) => safePage == 1 ? '.html' : '-$safePage.html',
        );
        if (noPage != seg) {
          return uri
              .replace(pathSegments: [...uri.pathSegments]..[uri.pathSegments.length - 1] = noPage)
              .toString();
        }
      }
    }
    if (safePage == 1) {
      return 'https://www.dushupai.com/book-$type-$category.html';
    }
    return 'https://www.dushupai.com/book-$type-$category-$safePage.html';
  }

  List<Map<String, String>> parseDushupaiTags(String html) {
    final anchorRe = RegExp(
      r'''<a[^>]*href\s*=\s*['"]([^'"]+)['"][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final textStrip = RegExp(r'<[^>]+>');
    final result = <Map<String, String>>[];
    final seen = <String>{};

    for (final m in anchorRe.allMatches(html)) {
      final href = (m.group(1) ?? '').trim();
      if (href.isEmpty) continue;

      final dushupaiPath = RegExp(
        r'''/book-(category|tag)-([^-/"']+)-?\d*\.html''',
        caseSensitive: false,
      ).firstMatch(href);
      if (dushupaiPath == null) continue;

      final title = (m.group(2) ?? '').replaceAll(textStrip, '').trim();
      if (title.isEmpty) continue;
      if (!title.contains('(') || !title.contains(')')) continue;

      final type = (dushupaiPath.group(1) ?? 'category').toLowerCase();
      final slug = (dushupaiPath.group(2) ?? '').trim();
      if (slug.isEmpty) continue;

      final key = '$type::$slug';
      if (seen.contains(key)) continue;
      seen.add(key);

      result.add({
        'type': type,
        'slug': slug,
        'title': title,
        'url': href.startsWith('http') ? href : 'https://www.dushupai.com$href',
      });
    }
    return result;
  }

  List<Map<String, String>> parseBookList(String html, Uri baseUri) {
    final anchorRe = RegExp(
      r'''<a[^>]*href\s*=\s*['"]([^'"]+)['"][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final textStrip = RegExp(r'<[^>]+>');
    final seenIds = <String>{};
    final books = <Map<String, String>>[];

    for (final m in anchorRe.allMatches(html)) {
      final href = (m.group(1) ?? '').trim();
      if (href.isEmpty) continue;
      final abs = baseUri.resolve(href).toString();
      final idMatch = RegExp(r'book-content-(\d+)\.html', caseSensitive: false).firstMatch(abs);
      if (idMatch == null) continue;
      final id = idMatch.group(1) ?? '';
      if (id.isEmpty || seenIds.contains(id)) continue;

      String title = (m.group(2) ?? '').replaceAll(textStrip, '').trim();
      final anchorHtml = m.group(0) ?? '';
      final innerHtml = m.group(2) ?? '';
      if (title.isEmpty) {
        final titleAttr = RegExp(r'''title\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false)
            .firstMatch(anchorHtml)
            ?.group(1)
            ?.trim();
        if (titleAttr != null && titleAttr.isNotEmpty) {
          title = titleAttr;
        }
      }
      if (title.isEmpty) continue;
      seenIds.add(id);
      final cover = _extractCoverUrl(anchorHtml: anchorHtml, innerHtml: innerHtml, baseUri: baseUri);

      books.add({
        'title': title,
        'url': 'https://www.dushupai.com/book-content-$id.html',
        if (cover.isNotEmpty) 'cover': cover,
      });
    }
    return books;
  }

  String _extractCoverUrl({
    required String anchorHtml,
    required String innerHtml,
    required Uri baseUri,
  }) {
    final imgTag = RegExp(r'''<img[^>]*>''', caseSensitive: false).firstMatch(innerHtml)?.group(0) ?? '';
    if (imgTag.isEmpty) return '';

    final lazySrc = RegExp(r'''(?:data-original|data-src|data-lazy-src)\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false)
        .firstMatch(imgTag)
        ?.group(1)
        ?.trim();
    final src = RegExp(r'''src\s*=\s*['"]([^'"]+)['"]''', caseSensitive: false)
        .firstMatch(imgTag)
        ?.group(1)
        ?.trim();
    final raw = (lazySrc != null && lazySrc.isNotEmpty) ? lazySrc : (src ?? '');
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:image')) return '';

    final normalized = raw.startsWith('//') ? 'https:$raw' : raw;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return '';
    return uri.hasScheme ? uri.toString() : baseUri.resolveUri(uri).toString();
  }

  Map<String, dynamic> parseBookDetail(String html, Uri baseUri) {
    String stripTags(String s) => s
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final titleMatch = RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false).firstMatch(html);
    final title = titleMatch == null ? '' : stripTags(titleMatch.group(1) ?? '');

    String intro = '';
    final introPatterns = [
      RegExp(r'内容简介[\s\S]{0,500}?<p[^>]*>([\s\S]{20,1200}?)</p>', caseSensitive: false),
      RegExp(r'书籍简介[\s\S]{0,500}?<p[^>]*>([\s\S]{20,1200}?)</p>', caseSensitive: false),
    ];
    for (final ptn in introPatterns) {
      final m = ptn.firstMatch(html);
      if (m != null) {
        intro = stripTags(m.group(1) ?? '');
        if (intro.isNotEmpty) break;
      }
    }

    final links = <String>[];
    final anchorRe = RegExp(
      r'''<a[^>]*href\s*=\s*['"]([^'"]+)['"][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    for (final m in anchorRe.allMatches(html)) {
      final href = (m.group(1) ?? '').trim();
      if (href.isEmpty) continue;
      final txt = stripTags(m.group(2) ?? '').toLowerCase();
      final abs = baseUri.resolve(href).toString();
      final lower = abs.toLowerCase();
      if (txt.contains('下载') ||
          txt.contains('mobi') ||
          txt.contains('epub') ||
          lower.contains('ctfile.com') ||
          lower.contains('download-book')) {
        links.add(abs);
      }
    }
    return {
      'title': title,
      'intro': intro,
      'links': links.toSet().toList(),
    };
  }

  String extractFileName(Uri uri, String? contentDisposition) {
    final cd = contentDisposition ?? '';
    final filenameMatch = RegExp(
      r'''filename\*=UTF-8''([^;]+)|filename="?([^";]+)"?''',
    ).firstMatch(cd);
    String? name;
    if (filenameMatch != null) {
      name = filenameMatch.group(1) ?? filenameMatch.group(2);
      if (name != null) {
        name = Uri.decodeComponent(name);
      }
    }
    name ??= uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    if (name.isEmpty) {
      name = 'book_${DateTime.now().millisecondsSinceEpoch}.bin';
    }
    return name;
  }

  String buildDisplayFileName(String sourceName, String? preferredBookTitle) {
    final normalizedTitle = normalizeBookTitle((preferredBookTitle ?? '').trim());
    final cleanTitle = sanitizePathComponent(normalizedTitle);
    if (cleanTitle.isEmpty) return sourceName;

    final sourceLower = sourceName.toLowerCase();
    final extMatch = RegExp(r'\.([a-z0-9]{1,8})$', caseSensitive: false).firstMatch(sourceLower);
    final ext = extMatch == null ? '' : '.${extMatch.group(1)}';
    return '$cleanTitle$ext';
  }

  String normalizeBookTitle(String raw) {
    if (raw.isEmpty) return raw;
    var t = raw;
    t = t.replaceAll(
      RegExp(
        r'''[\s,，、]*(epub|mobi|azw3|pdf)[\s,，、]*(格式)?[\s,，、]*电子书下载[\s,，、]*(作者[:：].*)?$''',
        caseSensitive: false,
      ),
      '',
    );
    t = t.replaceAll(RegExp(r'''[\s-—_]*读书派$''', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'''[，,\-—_]\s*作者[:：].*$''', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'''[\-—_]\s*.*?(读书派|dushupai).*$''', caseSensitive: false), '');
    return t.trim();
  }

  String currentCategoryFolderName({
    required List<Map<String, String>> tags,
    required String? selectedCategory,
    required String selectedType,
  }) {
    final hit = tags.where((t) {
      return (t['slug'] ?? '') == (selectedCategory ?? '') && (t['type'] ?? 'category') == selectedType;
    }).toList();
    final raw = hit.isNotEmpty ? (hit.first['title'] ?? selectedCategory ?? 'books') : (selectedCategory ?? 'books');
    final noCount = raw.replaceAll(RegExp(r'\s*\(\d+\)\s*'), '').trim();
    final safe = sanitizePathComponent(noCount);
    return safe.isEmpty ? 'books' : safe;
  }

  String sanitizePathComponent(String text) {
    final cleaned = text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'book' : cleaned;
  }

  Future<Directory> resolveWritableDownloadDir({String subFolder = 'books'}) {
    return DownloadBooksPaths.ensureDirectory(subFolder);
  }

  Map<String, String> defaultHeaders() {
    return const {
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/537.36',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
    };
  }

  String decodeBody(http.Response resp) {
    final ct = resp.headers['content-type'] ?? '';
    final m = RegExp(r'charset=([a-zA-Z0-9\-_]+)', caseSensitive: false).firstMatch(ct);
    final charset = (m?.group(1) ?? 'utf-8').toLowerCase();
    if (charset == 'utf-8' || charset == 'utf8') {
      return utf8.decode(resp.bodyBytes, allowMalformed: true);
    }
    try {
      return latin1.decode(resp.bodyBytes, allowInvalid: true);
    } catch (_) {
      return utf8.decode(resp.bodyBytes, allowMalformed: true);
    }
  }

  Future<_ResolvedDownloadTarget> _resolveDownloadTarget({
    required String rawUrl,
    required String password,
  }) async {
    final client = http.Client();
    final trace = <String>[];
    void pushTrace(String message) {
      trace.add(message);
      debugPrint('$_tracePrefix $message');
    }
    try {
      Uri current = Uri.parse(rawUrl);
      Uri? lastCtfileSourceUri;
      int http503Retry = 0;
      int limitPageRetry = 0;
      pushTrace('start: $current');

      if (_isDirectCdnFileUri(current)) {
        pushTrace('[fast-path] direct file url detected -> $current');
        final req = http.Request('GET', current)
          ..headers.addAll({
            ...defaultHeaders(),
            'Accept': '*/*',
          });
        final streamed = await client.send(req);
        final bytes = await streamed.stream.toBytes();
        final resp = http.Response.bytes(
          bytes,
          streamed.statusCode,
          request: streamed.request,
          headers: streamed.headers,
        );
        if (resp.statusCode != 200) {
          pushTrace('[fast-path] http ${resp.statusCode} at ${streamed.request?.url ?? current}');
          throw Exception('HTTP ${resp.statusCode}');
        }
        final requestUri = streamed.request?.url ?? current;
        pushTrace('[fast-path] final file: $requestUri');
        return _ResolvedDownloadTarget(uri: requestUri, response: resp, trace: trace);
      }

      for (int depth = 0; depth < 16; depth++) {
        if (current.host.toLowerCase().contains('ctfile.com')) {
          lastCtfileSourceUri = current;
        }
        final ctfileFastPath = await _resolveCtfileByApi(current, client, password);
        if (ctfileFastPath != null && ctfileFastPath.toString() != current.toString()) {
          pushTrace('[$depth] ctfile api -> $ctfileFastPath');
          current = ctfileFastPath;
        }

        pushTrace('[$depth] request -> $current');
        final headers = <String, String>{
          ...defaultHeaders(),
          'Accept': '*/*',
        };
        final hostLower = current.host.toLowerCase();
        // 仅在站点页面解析阶段携带 Referer，避免 CDN 直链被错误防盗链策略拦截。
        if (hostLower.contains('ctfile.com') || hostLower.contains('dushupai.com')) {
          headers['Referer'] = current.origin;
        }
        final req = http.Request('GET', current)..headers.addAll(headers);
        final streamed = await client.send(req);
        final bytes = await streamed.stream.toBytes();
        final resp = http.Response.bytes(
          bytes,
          streamed.statusCode,
          request: streamed.request,
          headers: streamed.headers,
        );
        if (resp.statusCode != 200) {
          final reqUri = streamed.request?.url ?? current;
          if (resp.statusCode == 503 && lastCtfileSourceUri != null) {
            if (http503Retry < 4) {
              http503Retry += 1;
              final delayMs = <int>[800, 1500, 2500, 4000][http503Retry - 1];
              pushTrace('[$depth] 503 at $reqUri, refresh ctfile downurl (retry $http503Retry/4, wait ${delayMs}ms)');
              final refreshed = await _resolveCtfileByApi(lastCtfileSourceUri, client, password);
              if (refreshed != null) {
                if (refreshed.toString() != reqUri.toString()) {
                  pushTrace('[$depth] refreshed -> $refreshed');
                } else {
                  pushTrace('[$depth] refreshed same url, retry again');
                }
                current = refreshed;
              }
              await Future.delayed(Duration(milliseconds: delayMs));
              continue;
            }
          } else if (resp.statusCode == 503 && http503Retry < 3) {
            http503Retry += 1;
            final delayMs = <int>[800, 1500, 2500][http503Retry - 1];
            pushTrace('[$depth] 503 at $reqUri, retry same url (retry $http503Retry/3, wait ${delayMs}ms)');
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          pushTrace('[$depth] http ${resp.statusCode} at ${streamed.request?.url ?? current}');
          throw Exception('HTTP ${resp.statusCode}');
        }
        http503Retry = 0;

        final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
        final contentDisposition = (resp.headers['content-disposition'] ?? '').toLowerCase();
        final requestUri = streamed.request?.url ?? current;
        trace.add('[$depth] ${requestUri.host} ct=$contentType');
        final looksLikeTextPage = contentType.contains('text/html') ||
            contentType.contains('text/plain') ||
            contentType.contains('javascript') ||
            contentType.contains('json') ||
            contentType.isEmpty;
        final isAttachment = contentDisposition.contains('attachment');
        final looksLikeBookByUrl = _looksLikeBookFileUri(requestUri);
        final looksLikeBookByType = contentType.contains('application/octet-stream') ||
            contentType.contains('application/epub') ||
            contentType.contains('application/x-mobipocket') ||
            contentType.contains('application/pdf') ||
            contentType.contains('application/zip') ||
            contentType.contains('application/x-zip');

        if (!looksLikeTextPage && (isAttachment || looksLikeBookByUrl || looksLikeBookByType)) {
          pushTrace('[$depth] final file: $requestUri');
          return _ResolvedDownloadTarget(uri: requestUri, response: resp, trace: trace);
        }

        final html = decodeBody(resp);
        if (_isCtfileLimitPage(html)) {
          if (lastCtfileSourceUri != null && limitPageRetry < 5) {
            limitPageRetry += 1;
            final delayMs = <int>[10000, 15000, 20000, 25000, 30000][limitPageRetry - 1];
            pushTrace(
              '[$depth] ctfile limit page detected, wait ${delayMs}ms then refresh downurl (retry $limitPageRetry/5)',
            );
            await Future.delayed(Duration(milliseconds: delayMs));
            final refreshed = await _resolveCtfileByApi(lastCtfileSourceUri, client, password);
            if (refreshed != null) {
              pushTrace('[$depth] refreshed by limit page -> $refreshed');
              current = refreshed;
              continue;
            }
          }
          throw Exception(ctfileLimitErrorMessage);
        }

        final unlocked = await _tryUnlockCtfileIfNeeded(
          html: html,
          pageUri: requestUri,
          client: client,
          password: password,
        );
        if (unlocked != null) {
          pushTrace('[$depth] unlocked -> $unlocked');
          current = unlocked;
          continue;
        }
        final next = _extractPossibleDownloadLink(html, requestUri, password);
        if (next == null) {
          pushTrace('[$depth] no next link from intermediate page');
          throw Exception('仍在中间下载页，未解析到真实文件链接（请确认提取码/页面结构）');
        }
        pushTrace('[$depth] next -> $next');
        current = next;
      }
      throw Exception('下载链接解析层级过深，可能需要手动打开网页下载');
    } finally {
      client.close();
    }
  }

  Future<Uri?> _resolveCtfileByApi(Uri uri, http.Client client, String password) async {
    final host = uri.host.toLowerCase();
    if (!host.contains('ctfile.com')) return null;
    if (uri.pathSegments.length < 2) return null;

    final pathType = uri.pathSegments.first.toLowerCase();
    if (pathType != 'f' && pathType != 'd') return null;
    final fileQuery = uri.pathSegments[1];
    if (fileQuery.isEmpty) return null;
    debugPrint('$_tracePrefix ctfile api try: $uri');

    final pwd = (uri.queryParameters['pwd'] ?? password).trim();
    final ts = '${DateTime.now().millisecondsSinceEpoch / 1000}';
    final getFileCandidates = [
      Uri.parse('https://webapi.ctfile.com/getfile.php').replace(
        queryParameters: {
          'path': 'f',
          'f': fileQuery,
          'passcode': pwd,
          'r': ts,
          'ref': '',
          'url': uri.toString(),
        },
      ),
      Uri.parse('https://webapi.ctfile.com/getfile.php').replace(
        queryParameters: {
          'path': 'd',
          'f': fileQuery,
          'passcode': pwd,
          'r': ts,
          'ref': '',
          'url': uri.toString(),
        },
      ),
    ];

    Map<String, dynamic>? getFileJson;
    for (final candidate in getFileCandidates) {
      final resp = await client.get(candidate, headers: defaultHeaders());
      if (resp.statusCode != 200) continue;
      dynamic data;
      try {
        data = jsonDecode(decodeBody(resp));
      } catch (_) {
        continue;
      }
      if (data is Map<String, dynamic>) {
        getFileJson = data;
        final code = data['code'];
        if (code == 200 || code == 423) break;
      }
    }
    if (getFileJson == null) return null;

    final code = getFileJson['code'];
    if (code == 423) {
      debugPrint('$_tracePrefix ctfile api invalid password');
      throw Exception('ctfile 提取码不正确，请检查访问密码');
    }
    if (code != 200) return null;

    final file = getFileJson['file'];
    if (file is! Map) return null;
    final uid = '${file['userid'] ?? ''}'.trim();
    final fid = '${file['file_id'] ?? ''}'.trim();
    final fileChk = '${file['file_chk'] ?? ''}'.trim();
    final startTime = '${file['start_time'] ?? '0'}'.trim();
    final waitSeconds = '${file['wait_seconds'] ?? '0'}'.trim();
    if (uid.isEmpty || fid.isEmpty || fileChk.isEmpty) return null;

    final downApiUri = Uri.parse('https://webapi.ctfile.com/get_down_url.php').replace(
      queryParameters: {
        'uid': uid,
        'fid': fid,
        'file_chk': fileChk,
        'start_time': startTime,
        'wait_seconds': waitSeconds,
        'rd': '${DateTime.now().millisecondsSinceEpoch / 1000}',
      },
    );
    final downResp = await client.get(downApiUri, headers: defaultHeaders());
    if (downResp.statusCode != 200) return null;

    dynamic downJson;
    try {
      downJson = jsonDecode(decodeBody(downResp));
    } catch (_) {
      return null;
    }
    if (downJson is! Map<String, dynamic>) return null;
    if (downJson['code'] != 200) return null;
    final downUrl = (downJson['downurl'] ?? '').toString().trim();
    if (downUrl.isEmpty) return null;
    debugPrint('$_tracePrefix ctfile api downurl ok');
    return Uri.tryParse(downUrl);
  }

  Future<Uri?> _tryUnlockCtfileIfNeeded({
    required String html,
    required Uri pageUri,
    required http.Client client,
    required String password,
  }) async {
    final host = pageUri.host.toLowerCase();
    if (!host.contains('ctfile.com')) return null;
    final needPwd = html.contains('访问密码') || html.toLowerCase().contains('password');
    final pwd = password.trim();
    if (!needPwd || pwd.isEmpty) return null;

    final actionMatch = RegExp(
      r'''<form[^>]*action\s*=\s*['"]([^'"]+)['"][^>]*>''',
      caseSensitive: false,
    ).firstMatch(html);
    final actionUri = actionMatch != null ? pageUri.resolve(actionMatch.group(1) ?? '') : pageUri;

    final hiddenInputs = RegExp(
      r'''<input[^>]*type\s*=\s*['"]hidden['"][^>]*name\s*=\s*['"]([^'"]+)['"][^>]*value\s*=\s*['"]([^'"]*)['"][^>]*>''',
      caseSensitive: false,
    );
    final body = <String, String>{};
    for (final m in hiddenInputs.allMatches(html)) {
      final k = m.group(1) ?? '';
      if (k.isEmpty) continue;
      body[k] = m.group(2) ?? '';
    }
    body['pwd'] = pwd;
    body['password'] = pwd;
    body['pass'] = pwd;
    body['accessCode'] = pwd;

    final resp = await client.post(
      actionUri,
      headers: {
        ...defaultHeaders(),
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': pageUri.toString(),
      },
      body: body,
    );
    if (resp.statusCode != 200) return null;

    final unlockHtml = decodeBody(resp);
    return _extractPossibleDownloadLink(unlockHtml, actionUri, password);
  }

  Uri? _extractPossibleDownloadLink(String html, Uri baseUri, String password) {
    final anchorRe = RegExp(
      r'''<a[^>]*href\s*=\s*['"]([^'"]+)['"][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final textStrip = RegExp(r'<[^>]+>');
    final candidates = <Uri>[];
    for (final m in anchorRe.allMatches(html)) {
      final href = (m.group(1) ?? '').trim();
      if (href.isEmpty || href.startsWith('javascript:') || href.startsWith('#')) continue;
      final txt = (m.group(2) ?? '').replaceAll(textStrip, '').toLowerCase();
      final abs = baseUri.resolve(href);
      final lower = abs.toString().toLowerCase();

      Uri normalized = abs;
      if (lower.contains('ctfile.com') &&
          (lower.contains('/f/') || lower.contains('/d/')) &&
          !lower.contains('pwd=')) {
        final pwd = password.trim();
        if (pwd.isNotEmpty) {
          normalized = abs.replace(queryParameters: {
            ...abs.queryParameters,
            'pwd': pwd,
          });
        }
      }

      final hit = txt.contains('下载') ||
          txt.contains('download') ||
          lower.contains('download') ||
          lower.contains('/down') ||
          lower.contains('/d/') ||
          lower.contains('ctfile.com/f/') ||
          lower.contains('download-book');
      if (hit && !_isStaticAsset(normalized)) {
        candidates.add(normalized);
      }
    }
    if (candidates.isNotEmpty) {
      final strictBookFirst = candidates.where(_looksLikeStrictBookFileUri).toList();
      if (strictBookFirst.isNotEmpty) return strictBookFirst.first;
      final archiveBook = candidates.where(_looksLikeArchiveFileUri).toList();
      if (archiveBook.isNotEmpty) return archiveBook.first;
      return candidates.first;
    }

    final attrCandidates = <Uri>[];
    final attrRe = RegExp(
      r'''(?:onclick|data-url|data-href)\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );
    for (final m in attrRe.allMatches(html)) {
      final raw = (m.group(1) ?? '').trim();
      if (raw.isEmpty) continue;
      final embedded = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false).firstMatch(raw);
      final url = embedded?.group(0) ?? raw;
      final abs = Uri.tryParse(url);
      final resolved = abs ?? baseUri.resolve(url);
      if (_isStaticAsset(resolved)) continue;
      final lower = resolved.toString().toLowerCase();
      if (lower.contains('ctfile.com') ||
          lower.contains('download-book') ||
          lower.contains('/down') ||
          lower.contains('download')) {
        attrCandidates.add(resolved);
      }
    }
    if (attrCandidates.isNotEmpty) {
      final strictBookFirst = attrCandidates.where(_looksLikeStrictBookFileUri).toList();
      if (strictBookFirst.isNotEmpty) return strictBookFirst.first;
      final archiveBook = attrCandidates.where(_looksLikeArchiveFileUri).toList();
      if (archiveBook.isNotEmpty) return archiveBook.first;
      return attrCandidates.first;
    }

    final directUrl = RegExp(r'''https?://[^\s"'<>]+''', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(0) ?? '')
        .where((u) {
      final l = u.toLowerCase();
      return (l.contains('ctfile.com') || l.contains('dushupai.com')) &&
          (l.contains('/f/') || l.contains('/d/') || l.contains('download') || l.contains('download-book')) &&
          !l.endsWith('.js') &&
          !l.endsWith('.css');
    }).toList();
    if (directUrl.isNotEmpty) {
      return Uri.tryParse(directUrl.first);
    }
    return null;
  }

  bool _isStaticAsset(Uri uri) {
    final pth = uri.path.toLowerCase();
    return pth.endsWith('.js') ||
        pth.endsWith('.css') ||
        pth.endsWith('.png') ||
        pth.endsWith('.jpg') ||
        pth.endsWith('.jpeg') ||
        pth.endsWith('.gif') ||
        pth.endsWith('.svg') ||
        pth.endsWith('.webp');
  }

  bool _looksLikeBookFileUri(Uri uri) {
    return _looksLikeStrictBookFileUri(uri) || _looksLikeArchiveFileUri(uri);
  }

  bool _isDirectCdnFileUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (!host.contains('tv002.com')) return false;
    return _looksLikeBookFileUri(uri);
  }

  bool _isCtfileLimitPage(String html) {
    final content = html.toLowerCase();
    return content.contains('超过最大下载任务数') ||
        content.contains('免费会员仅可单任务下载') ||
        content.contains('单任务下载') ||
        content.contains('下载出错了') ||
        content.contains('请稍后再试');
  }

  bool isCtfileLimitError(Object error) {
    final message = error.toString();
    return message.contains('最大下载任务数') ||
        message.contains('单任务下载') ||
        message.contains(ctfileLimitErrorMessage);
  }

  bool _looksLikeStrictBookFileUri(Uri uri) {
    final pth = uri.path.toLowerCase();
    return pth.endsWith('.mobi') ||
        pth.endsWith('.epub') ||
        pth.endsWith('.azw3') ||
        pth.endsWith('.pdf');
  }

  bool _looksLikeArchiveFileUri(Uri uri) {
    final pth = uri.path.toLowerCase();
    return pth.endsWith('.zip') ||
        pth.endsWith('.rar') ||
        pth.endsWith('.7z');
  }

  Future<String> _extractBookFromZipIfNeeded({
    required File zipFile,
    required bool keepOriginalZip,
    String? preferredBookTitle,
  }) async {
    final lowerName = zipFile.path.toLowerCase();
    if (!lowerName.endsWith('.zip')) {
      return zipFile.path;
    }

    Archive archive;
    try {
      final bytes = await zipFile.readAsBytes();
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      return zipFile.path;
    }

    final bookEntries = archive.files.where((f) {
      if (!f.isFile) return false;
      final name = f.name.toLowerCase();
      return name.endsWith('.epub') || name.endsWith('.mobi') || name.endsWith('.azw3') || name.endsWith('.pdf');
    }).toList();
    if (bookEntries.isEmpty) {
      return zipFile.path;
    }

    bookEntries.sort((a, b) => b.size.compareTo(a.size));
    final selected = bookEntries.first;
    final ext = p.extension(selected.name).toLowerCase();
    final rawBase = (preferredBookTitle ?? '').trim().isNotEmpty
        ? (preferredBookTitle ?? '').trim()
        : p.basenameWithoutExtension(selected.name);
    final outputBase = sanitizePathComponent(normalizeBookTitle(rawBase));
    final outputName = outputBase.endsWith(ext) ? outputBase : '$outputBase$ext';
    final outputFile = File(p.join(zipFile.parent.path, outputName));
    await outputFile.writeAsBytes(selected.content as List<int>, flush: true);

    if (!keepOriginalZip) {
      try {
        await zipFile.delete();
      } catch (_) {
        // ignore
      }
    }
    return outputFile.path;
  }
}

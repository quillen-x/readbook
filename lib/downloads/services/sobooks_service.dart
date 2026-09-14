import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'online_book_service.dart';

class SobooksResolvedDownload {
  const SobooksResolvedDownload({
    required this.url,
    required this.password,
  });

  final String url;
  final String password;
}

class SobooksService {
  static const String siteOrigin = 'https://sobooks.cc';
  static const int booksPerView = 100;
  static const int booksPerSourcePage = 40;
  static const Duration _pageFetchTimeout = Duration(seconds: 15);

  static const List<Map<String, String>> defaultTags = [
    {
      'type': 'category',
      'slug': 'latest',
      'title': '最新',
      'url': '$siteOrigin/',
    },
    {
      'type': 'category',
      'slug': 'xiaoshuowenxue',
      'title': '小说文学',
      'url': '$siteOrigin/xiaoshuowenxue',
    },
    {
      'type': 'category',
      'slug': 'lishizhuanji',
      'title': '历史传记',
      'url': '$siteOrigin/lishizhuanji',
    },
    {
      'type': 'category',
      'slug': 'renwensheke',
      'title': '人文社科',
      'url': '$siteOrigin/renwensheke',
    },
    {
      'type': 'category',
      'slug': 'lizhichenggong',
      'title': '励志成功',
      'url': '$siteOrigin/lizhichenggong',
    },
    {
      'type': 'category',
      'slug': 'jingjiguanli',
      'title': '经济管理',
      'url': '$siteOrigin/jingjiguanli',
    },
    {
      'type': 'category',
      'slug': 'xuexijiaoyu',
      'title': '学习教育',
      'url': '$siteOrigin/xuexijiaoyu',
    },
    {
      'type': 'category',
      'slug': 'shenghuoshishang',
      'title': '生活时尚',
      'url': '$siteOrigin/shenghuoshishang',
    },
    {
      'type': 'category',
      'slug': 'manhuahuiben',
      'title': '漫画绘本',
      'url': '$siteOrigin/manhuahuiben',
    },
  ];

  Map<String, String> _headers() => const {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/131.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Referer': '$siteOrigin/',
      };

  String buildListUrl({
    required String slug,
    required int page,
    String? sourceUrl,
  }) {
    final safePage = page < 1 ? 1 : page;
    final src = (sourceUrl ?? '').trim();
    if (src.isNotEmpty) {
      final uri = Uri.parse(src);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      final isHome = uri.path == '/' || uri.path.isEmpty;
      if (isHome) {
        return safePage <= 1 ? '$siteOrigin/' : '$siteOrigin/page/$safePage';
      }
      if (last == 'page' || int.tryParse(last) != null) {
        final baseSegs = [...uri.pathSegments]
          ..removeWhere((e) => e == 'page' || int.tryParse(e) != null);
        final base = baseSegs.isEmpty
            ? siteOrigin
            : '$siteOrigin/${baseSegs.join('/')}';
        return safePage <= 1 ? base : '$base/page/$safePage';
      }
      return safePage <= 1 ? src : '$src/page/$safePage';
    }
    if (slug.isEmpty || slug == 'latest') {
      return safePage <= 1 ? '$siteOrigin/' : '$siteOrigin/page/$safePage';
    }
    return safePage <= 1
        ? '$siteOrigin/$slug'
        : '$siteOrigin/$slug/page/$safePage';
  }

  Future<FetchBooksResult> fetchBooks({
    required String category,
    required int page,
    String? sourceUrl,
    bool includeTags = true,
  }) async {
    final safePage = page < 1 ? 1 : page;
    final sourcePages =
        (booksPerView / booksPerSourcePage).ceil().clamp(1, 6);
    final startSourcePage = (safePage - 1) * sourcePages + 1;
    final catalog = <Map<String, String>>[];
    final seen = <String>{};

    try {
      for (var i = 0; i < sourcePages && catalog.length < booksPerView; i++) {
        final sourcePage = startSourcePage + i;
        final url = buildListUrl(
          slug: category.trim(),
          page: sourcePage,
          sourceUrl: sourceUrl,
        );
        final html = await _getHtml(url);
        if (_isVerifyPage(html)) {
          throw Exception('SoBooks 需要安全验证，请稍后重试');
        }
        final books = parseBookList(html);
        if (books.isEmpty) break;
        for (final book in books) {
          final key = (book['url'] ?? book['title'] ?? '').trim();
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          catalog.add(book);
          if (catalog.length >= booksPerView) break;
        }
        if (i + 1 < sourcePages) {
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }
      return FetchBooksResult(
        catalog: catalog,
        tags: includeTags ? List<Map<String, String>>.from(defaultTags) : const [],
      );
    } on TimeoutException {
      throw Exception('无法连接 SoBooks（请求超时）。请检查网络后重试。');
    } on SocketException catch (e) {
      throw Exception(
        '无法连接 SoBooks：${e.message.isNotEmpty ? e.message : '网络不通'}。请检查网络后重试。',
      );
    } on http.ClientException catch (e) {
      throw Exception('无法连接 SoBooks：${e.message}。请检查网络后重试。');
    }
  }

  Future<BookDetailData> fetchBookDetail(String url) async {
    try {
      final html = await _getHtml(url);
      if (_isVerifyPage(html)) {
        throw Exception('SoBooks 需要安全验证，请稍后重试');
      }
      return parseBookDetail(html);
    } on TimeoutException {
      throw Exception('无法连接 SoBooks（请求超时）。请检查网络后重试。');
    } on SocketException catch (e) {
      throw Exception(
        '无法连接 SoBooks：${e.message.isNotEmpty ? e.message : '网络不通'}。请检查网络后重试。',
      );
    } on http.ClientException catch (e) {
      throw Exception('无法连接 SoBooks：${e.message}。请检查网络后重试。');
    }
  }

  Future<SobooksResolvedDownload> resolveCtfileDownload(String bookUrl) async {
    if (bookUrl.contains('ctfile.com')) {
      return SobooksResolvedDownload(
        url: bookUrl,
        password: _passwordFromUri(Uri.parse(bookUrl)),
      );
    }
    final decoded = decodeGoUrl(bookUrl);
    if (decoded != null) {
      if (!decoded.host.toLowerCase().contains('ctfile.com')) {
        throw Exception('暂仅支持城通网盘自动下载，请改用城通链接');
      }
      return SobooksResolvedDownload(
        url: decoded.toString(),
        password: _passwordFromUri(decoded),
      );
    }

    final detail = await fetchBookDetail(bookUrl);
    final ctfile = detail.links.cast<String?>().firstWhere(
          (u) => (u ?? '').toLowerCase().contains('ctfile.com'),
          orElse: () => null,
        );
    if (ctfile == null || ctfile.isEmpty) {
      throw Exception('未找到城通网盘链接，暂无法自动下载');
    }
    final uri = Uri.parse(ctfile);
    return SobooksResolvedDownload(
      url: ctfile,
      password: _passwordFromUri(uri),
    );
  }

  List<Map<String, String>> parseBookList(String html) {
    final result = <Map<String, String>>[];
    final seen = <String>{};
    final cardRe = RegExp(
      r'''<div class="card col[^"]*">[\s\S]*?<a href="(https?://sobooks\.cc/books/\d+\.html)"[^>]*title="([^"]*)"[\s\S]*?<img class="thumb" src="([^"]+)"''',
      caseSensitive: false,
    );
    for (final m in cardRe.allMatches(html)) {
      final url = (m.group(1) ?? '').trim();
      final title = _stripTags(m.group(2) ?? '').trim();
      var cover = (m.group(3) ?? '').trim();
      if (url.isEmpty || title.isEmpty || seen.contains(url)) continue;
      if (cover.startsWith('/')) {
        cover = '$siteOrigin$cover';
      }
      seen.add(url);
      result.add({
        'title': title,
        'url': url,
        if (cover.isNotEmpty) 'cover': cover,
        'source': 'sobooks',
      });
    }
    return result;
  }

  BookDetailData parseBookDetail(String html) {
    final title = _firstMatch(
          html,
          RegExp(r'<h1 class="post-title-single">([\s\S]*?)</h1>',
              caseSensitive: false),
        ) ??
        _firstMatch(
          html,
          RegExp(r'<title>([\s\S]*?)</title>', caseSensitive: false),
        ) ??
        '';
    final introBlock = _firstMatch(
          html,
          RegExp(r'<div class="post-content">([\s\S]*?)</div>',
              caseSensitive: false),
        ) ??
        '';
    final intro = _stripTags(introBlock)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final links = <String>[];
    final seen = <String>{};
    final goRe = RegExp(
      r'''href="([^"]*go\.html\?url=[^"]+)"''',
      caseSensitive: false,
    );
    for (final m in goRe.allMatches(html)) {
      final decoded = decodeGoUrl(m.group(1) ?? '');
      if (decoded == null) continue;
      final href = decoded.toString();
      if (href.isEmpty || seen.contains(href)) continue;
      seen.add(href);
      links.add(href);
    }
    return BookDetailData(
      title: _stripTags(title).replaceAll(RegExp(r'\s+[–—-].*$'), '').trim(),
      intro: intro,
      links: links,
    );
  }

  Uri? decodeGoUrl(String href) {
    final m = RegExp(
      r'go\.html\?url=([^&]+)',
      caseSensitive: false,
    ).firstMatch(href);
    if (m == null) return null;
    try {
      var raw = Uri.decodeComponent(m.group(1) ?? '').trim();
      if (raw.isEmpty) return null;
      final pad = raw.length % 4;
      if (pad != 0) {
        raw = raw.padRight(raw.length + (4 - pad), '=');
      }
      final decoded = utf8.decode(base64.decode(raw), allowMalformed: true);
      return Uri.parse(decoded);
    } catch (_) {
      return null;
    }
  }

  bool isSobooksUrl(String url) {
    return url.toLowerCase().contains('sobooks.cc');
  }

  String _passwordFromUri(Uri uri) {
    final pwd = uri.queryParameters['pwd'] ?? uri.queryParameters['p'] ?? '';
    return pwd.trim();
  }

  bool _isVerifyPage(String html) {
    return html.contains('SoBooks 安全验证') || html.contains('id="ans"');
  }

  String? _firstMatch(String html, RegExp re) {
    return re.firstMatch(html)?.group(1);
  }

  String _stripTags(String raw) {
    return raw.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
  }

  Future<String> _getHtml(String url) async {
    final resp = await http
        .get(Uri.parse(url), headers: _headers())
        .timeout(_pageFetchTimeout);
    if (resp.statusCode != 200) {
      throw Exception('读取失败：HTTP ${resp.statusCode}');
    }
    return utf8.decode(resp.bodyBytes, allowMalformed: true);
  }
}

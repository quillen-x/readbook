import 'dart:io';

/// macOS / 桌面端系统代理配置，供 [HttpClient.findProxy] 使用。
class SystemProxyConfig {
  const SystemProxyConfig({
    required this.enabled,
    this.httpHost = '',
    this.httpPort = 0,
    this.httpsHost = '',
    this.httpsPort = 0,
    this.bypassHosts = const <String>[],
  });

  final bool enabled;
  final String httpHost;
  final int httpPort;
  final String httpsHost;
  final int httpsPort;
  final List<String> bypassHosts;

  String findProxyFor(Uri uri) {
    if (!enabled) return 'DIRECT';
    if (_shouldBypass(uri)) return 'DIRECT';

    final host = uri.scheme == 'https'
        ? (httpsHost.isNotEmpty ? httpsHost : httpHost)
        : httpHost;
    final port = uri.scheme == 'https'
        ? (httpsPort > 0 ? httpsPort : httpPort)
        : httpPort;

    if (host.isEmpty || port <= 0) return 'DIRECT';
    return 'PROXY $host:$port';
  }

  bool _shouldBypass(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    if (host.endsWith('.local')) return true;

    for (final rule in bypassHosts) {
      final normalized = rule.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (normalized.startsWith('*.')) {
        if (host.endsWith(normalized.substring(1))) return true;
        continue;
      }
      if (normalized.contains('/')) {
        if (_hostInCidr(host, normalized)) return true;
        continue;
      }
      if (host == normalized) return true;
    }
    return false;
  }

  bool _hostInCidr(String host, String cidr) {
    try {
      final parts = cidr.split('/');
      if (parts.length != 2) return false;
      final base = InternetAddress(parts[0]);
      final prefix = int.parse(parts[1]);
      final target = InternetAddress(host);
      if (base.type != target.type) return false;
      final baseBytes = base.rawAddress;
      final targetBytes = target.rawAddress;
      final fullBytes = prefix ~/ 8;
      final remBits = prefix % 8;
      for (var i = 0; i < fullBytes; i++) {
        if (baseBytes[i] != targetBytes[i]) return false;
      }
      if (remBits == 0) return true;
      final mask = (0xFF << (8 - remBits)) & 0xFF;
      return (baseBytes[fullBytes] & mask) == (targetBytes[fullBytes] & mask);
    } catch (_) {
      return false;
    }
  }
}

/// 读取当前系统代理。macOS 优先解析 `scutil --proxy`，否则回退环境变量。
Future<SystemProxyConfig> readSystemProxy() async {
  if (Platform.isMacOS) {
    final fromScutil = await _readMacOsProxy();
    if (fromScutil.enabled) return fromScutil;
  }
  return _readEnvProxy();
}

Future<SystemProxyConfig> _readMacOsProxy() async {
  try {
    final result = await Process.run('scutil', ['--proxy']);
    if (result.exitCode != 0) {
      return const SystemProxyConfig(enabled: false);
    }

    final values = _parseScutilProxyOutput(result.stdout.toString());
    final httpEnabled = values['HTTPEnable'] == '1';
    final httpsEnabled = values['HTTPSEnable'] == '1';
    final httpHost = values['HTTPProxy'] ?? '';
    final httpsHost = values['HTTPSProxy'] ?? '';
    final httpPort = int.tryParse(values['HTTPPort'] ?? '') ?? 0;
    final httpsPort = int.tryParse(values['HTTPSPort'] ?? '') ?? 0;
    final enabled = (httpEnabled && httpHost.isNotEmpty && httpPort > 0) ||
        (httpsEnabled && httpsHost.isNotEmpty && httpsPort > 0);

    return SystemProxyConfig(
      enabled: enabled,
      httpHost: httpHost,
      httpPort: httpPort,
      httpsHost: httpsHost.isNotEmpty ? httpsHost : httpHost,
      httpsPort: httpsPort > 0 ? httpsPort : httpPort,
      bypassHosts: _parseScutilExceptions(values['ExceptionsList']),
    );
  } catch (_) {
    return const SystemProxyConfig(enabled: false);
  }
}

Map<String, String> _parseScutilProxyOutput(String output) {
  final values = <String, String>{};
  final lines = output.split('\n');
  String? currentKey;
  final currentList = <String>[];

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.startsWith('<dictionary>')) continue;

    if (line == '}') {
      if (currentKey == 'ExceptionsList') {
        values[currentKey!] = currentList.join(',');
      }
      currentKey = null;
      currentList.clear();
      continue;
    }

    final colon = line.indexOf(':');
    if (colon <= 0) continue;

    final key = line.substring(0, colon).trim();
    final value = line.substring(colon + 1).trim();

    if (value == '<array> {') {
      currentKey = key;
      currentList.clear();
      continue;
    }
    if (currentKey == 'ExceptionsList') {
      if (value.isNotEmpty) currentList.add(value);
      continue;
    }

    values[key] = value;
  }

  return values;
}

List<String> _parseScutilExceptions(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  return raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

SystemProxyConfig _readEnvProxy() {
  final httpsProxy = Platform.environment['https_proxy'] ??
      Platform.environment['HTTPS_PROXY'] ??
      '';
  final httpProxy = Platform.environment['http_proxy'] ??
      Platform.environment['HTTP_PROXY'] ??
      '';
  final raw = httpsProxy.isNotEmpty ? httpsProxy : httpProxy;
  if (raw.isEmpty) {
    return const SystemProxyConfig(enabled: false);
  }

  final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (uri == null || uri.host.isEmpty) {
    return const SystemProxyConfig(enabled: false);
  }

  final port = uri.hasPort ? uri.port : 8080;
  return SystemProxyConfig(
    enabled: true,
    httpHost: uri.host,
    httpPort: port,
    httpsHost: uri.host,
    httpsPort: port,
  );
}

/// 让 `dart:io` / `package:http` 走系统代理（macOS 上浏览器默认行为）。
class SystemProxyHttpOverrides extends HttpOverrides {
  SystemProxyHttpOverrides(this.config);

  final SystemProxyConfig config;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.autoUncompress = true;
    client.connectionTimeout = const Duration(seconds: 30);
    if (config.enabled) {
      client.findProxy = config.findProxyFor;
    }
    return client;
  }
}

Future<void> applySystemProxyOverrides() async {
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

  final config = await readSystemProxy();
  if (!config.enabled) return;
  HttpOverrides.global = SystemProxyHttpOverrides(config);
}

// 连接「正在运行的官方 DSH」。
//
// 官方 DeepSeek Harness 桌面版会在 127.0.0.1 上开一个 DSH Web 服务（随机端口），
// 并把带一次性 token 的地址交给自己的窗口。令牌只在进程内存里；但会话 cookie 是
// 用 `~/.dsh/.credentials.yaml` 里一把长期密钥签名的（DSH 的 Dart 客户端也文档化了
// 这种 cookie 直连方式）。所以本机客户端可以：
//
//   1. 用 lsof 找到官方 DSH 的本地监听端口；
//   2. 用那把密钥签一个 30 天有效的 `dsh-auth-<authority>` cookie；
//   3. 用 DshClient 直连——和浏览器访问官方 DSH 是同一条路，不经过 SSH / DSH Remote。
//
// cookie 只保存在内存里，重新签一次很便宜。官方 DSH 退出后端口消失，这里会返回 null。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:yaml/yaml.dart';

/// 一个正在运行的官方 DSH。
class OfficialDsh {
  const OfficialDsh({required this.port, required this.version, required this.cookie});

  final int port;

  /// 官方桌面版的版本（`runtime.json` 的 desktopVersion），不知道时为 null。
  final String? version;

  /// 已签好的浏览器会话 cookie（authority = 127.0.0.1:port）。
  final DshCookie cookie;

  Uri get baseUri => Uri.parse('http://127.0.0.1:$port/');
  String get authority => '127.0.0.1:$port';
}

String base64UrlNoPad(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// 用 DSH 的浏览器会话密钥签一个 cookie。
///
/// 格式（与 `@deepseek-ai/dsh-client-connection` 一致）：
///   name  = `dsh-auth-` + base64url(sha256(authority))
///   value = `v1.` + base64url(JSON) + `.` + base64url(HMAC-SHA256(secret, JSON))
DshCookie mintOfficialCookie({
  required String authority,
  required List<int> secret,
  DateTime? now,
  Duration lifetime = const Duration(days: 30),
}) {
  final at = now ?? DateTime.now();
  final expiresAt = at.add(lifetime);
  final payload = <String, Object?>{
    'version': 1,
    'authority': authority,
    'issuedAt': at.millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };
  final body = base64UrlNoPad(utf8.encode(jsonEncode(payload)));
  final mac = Hmac(sha256, secret).convert(utf8.encode(body)).bytes;
  return DshCookie(
    name: 'dsh-auth-${base64UrlNoPad(sha256.convert(utf8.encode(authority)).bytes)}',
    value: 'v1.$body.${base64UrlNoPad(mac)}',
    authority: authority,
    expiresAt: expiresAt,
  );
}

/// 读 `~/.dsh/.credentials.yaml` 里 `client-connection/browser-session` 的密钥；没有就返回 null。
List<int>? readBrowserSessionSecret([String? home]) {
  final root = home ?? Platform.environment['HOME'];
  if (root == null) return null;
  final file = File('$root/.dsh/.credentials.yaml');
  if (!file.existsSync()) return null;
  try {
    final doc = loadYaml(file.readAsStringSync());
    final records = doc is Map ? doc['records'] : null;
    final record = records is Map ? records['client-connection/browser-session'] : null;
    final payload = record is Map ? record['payload'] : null;
    final secret = payload is Map ? payload['secret'] : null;
    if (secret is! String) return null;
    return base64Url.decode(secret.padRight((secret.length + 3) ~/ 4 * 4, '='));
  } catch (_) {
    return null;
  }
}

/// 官方桌面版的版本（`~/.dsh/dsh-runtimes/dsh-primary-runtime/runtime.json`）。
String? readOfficialVersion([String? home]) {
  final root = home ?? Platform.environment['HOME'];
  if (root == null) return null;
  try {
    final file = File('$root/.dsh/dsh-runtimes/dsh-primary-runtime/runtime.json');
    if (!file.existsSync()) return null;
    final data = jsonDecode(file.readAsStringSync());
    return data is Map ? data['desktopVersion'] as String? : null;
  } catch (_) {
    return null;
  }
}

/// 官方 DSH 的本地监听端口：lsof 里命令名为 `DeepSeek`、监听 127.0.0.1 的那一行。
Future<int?> findOfficialDshPort() async {
  try {
    final result = await Process.run('/usr/sbin/lsof', <String>['-nP', '-iTCP', '-sTCP:LISTEN'])
        .timeout(const Duration(seconds: 3));
    if (result.exitCode != 0) return null;
    final line = result.stdout
        .toString()
        .split('\n')
        .where((l) => l.contains('DeepSeek') && l.contains('127.0.0.1:'))
        .firstOrNull;
    if (line == null) return null;
    final match = RegExp(r'127\.0\.0\.1:(\d+)').firstMatch(line);
    final port = match == null ? null : int.tryParse(match.group(1)!);
    return port != null && port > 0 && port < 65536 ? port : null;
  } catch (_) {
    return null;
  }
}

/// 找一个可用的官方 DSH；没有运行、没有密钥或不是这台机器时返回 null。
Future<OfficialDsh?> findOfficialDsh({String? home}) async {
  final port = await findOfficialDshPort();
  if (port == null) return null;
  final secret = readBrowserSessionSecret(home);
  if (secret == null) return null;
  final authority = '127.0.0.1:$port';
  return OfficialDsh(
    port: port,
    version: readOfficialVersion(home),
    cookie: mintOfficialCookie(authority: authority, secret: secret),
  );
}

/// SharedPreferences 里「用官方 DSH」的开关。
const macOfficialDshPref = 'mac.official_dsh';

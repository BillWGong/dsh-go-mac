// ignore_for_file: avoid_print
// 连接「正在运行的官方 DSH」探针（不经过 SSH / DSH Remote）。
//
//   dart run tool/macos_official_probe.dart
//
// 做三件事：找到官方 DSH 的本地端口 → 用 ~/.dsh 里的签名密钥签一个浏览器
// cookie → 用 DshClient 直连并列出对话。成功会打印 OFFICIAL OK。

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:yaml/yaml.dart';

String b64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

DshCookie mintCookie(String authority, List<int> secret, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final payload = <String, Object?>{
    'version': 1,
    'authority': authority,
    'issuedAt': at.millisecondsSinceEpoch,
    'expiresAt': at.add(const Duration(days: 30)).millisecondsSinceEpoch,
  };
  final body = b64Url(utf8.encode(jsonEncode(payload)));
  final mac = Hmac(sha256, secret).convert(utf8.encode(body)).bytes;
  final name = 'dsh-auth-${b64Url(sha256.convert(utf8.encode(authority)).bytes)}';
  return DshCookie(
    name: name,
    value: 'v1.$body.${b64Url(mac)}',
    authority: authority,
    expiresAt: at.add(const Duration(days: 30)),
  );
}

List<int>? readSecret() {
  final file = File('${Platform.environment['HOME']}/.dsh/.credentials.yaml');
  if (!file.existsSync()) return null;
  final doc = loadYaml(file.readAsStringSync());
  final records = doc is Map ? doc['records'] : null;
  final record = records is Map ? records['client-connection/browser-session'] : null;
  final payload = record is Map ? record['payload'] : null;
  final secret = payload is Map ? payload['secret'] : null;
  if (secret is! String) return null;
  return base64Url.decode(secret.padRight((secret.length + 3) ~/ 4 * 4, '='));
}

Future<void> main() async {
  final secret = readSecret();
  if (secret == null) {
    print('OFFICIAL FAIL: no browser-session secret in ~/.dsh/.credentials.yaml');
    exit(1);
  }
  final result = await Process.run('/usr/sbin/lsof', ['-nP', '-iTCP:62680', '-sTCP:LISTEN']);
  print('lsof: ${result.stdout}'.trim());

  const base = 'http://127.0.0.1:62680/';
  final authority = '127.0.0.1:62680';
  final cookie = mintCookie(authority, secret);
  print('cookie: ${cookie.name} for ${cookie.authority}');

  final client = await DshClient.connect(
    baseUri: Uri.parse(base),
    cookie: cookie,
    readyTimeout: const Duration(seconds: 30),
  );
  try {
    final sessions = await client.listSessions();
    print('sessions: ${sessions.length}');
    for (final session in sessions.take(3)) {
      print('  - ${session.title ?? session.sessionId}');
    }
    final models = await client.listModels();
    print('models: ${models.models.length}');
  } finally {
    await client.close();
  }
  print('OFFICIAL OK');
}

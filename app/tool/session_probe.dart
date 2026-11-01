// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:yaml/yaml.dart';

String b64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
DshCookie mint(String authority, List<int> secret) {
  final now = DateTime.now();
  final payload = {'version': 1, 'authority': authority, 'issuedAt': now.millisecondsSinceEpoch, 'expiresAt': now.add(const Duration(days: 30)).millisecondsSinceEpoch};
  final body = b64Url(utf8.encode(jsonEncode(payload)));
  final mac = Hmac(sha256, secret).convert(utf8.encode(body)).bytes;
  return DshCookie(name: 'dsh-auth-${b64Url(sha256.convert(utf8.encode(authority)).bytes)}', value: 'v1.$body.${b64Url(mac)}', authority: authority, expiresAt: now.add(const Duration(days: 30)));
}

Future<void> main() async {
  final doc = loadYaml(File('${Platform.environment['HOME']}/.dsh/.credentials.yaml').readAsStringSync());
  final secretB64 = doc['records']['client-connection/browser-session']['payload']['secret'] as String;
  final secret = base64Url.decode(secretB64.padRight((secretB64.length + 3) ~/ 4 * 4, '='));
  final port = 49287;
  final base = Uri.parse('http://127.0.0.1:$port/');
  final client = await DshClient.connect(baseUri: base, cookie: mint('127.0.0.1:$port', secret));
  for (final cwd in ['/root/workspace', Platform.environment['HOME'], null]) {
    try {
      final s = await client.createSession(cwd: cwd);
      print('OK cwd=$cwd session=${s.sessionId}');
    } catch (e) {
      print('FAIL cwd=$cwd -> $e');
    }
  }
  await client.close();
}

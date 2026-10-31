import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dsh_app/macos/official_dsh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('签出来的 cookie 和 DSH 的格式一致', () {
    final secret = List<int>.generate(32, (i) => i);
    final now = DateTime.fromMillisecondsSinceEpoch(1000);
    final cookie = mintOfficialCookie(authority: '127.0.0.1:62680', secret: secret, now: now);
    expect(cookie.name, startsWith('dsh-auth-'));
    final parts = cookie.value.split('.');
    expect(parts, hasLength(3));
    expect(parts.first, 'v1');
    // 签名可复算：HMAC-SHA256(secret, body)
    final expected = Hmac(sha256, secret).convert(utf8.encode(parts[1])).bytes;
    expect(parts[2], base64UrlNoPad(expected));
    // payload 里是 authority 与 30 天有效期
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
    expect(payload['authority'], '127.0.0.1:62680');
    expect(payload['version'], 1);
    expect(payload['expiresAt'], now.add(const Duration(days: 30)).millisecondsSinceEpoch);
    // 名字是 authority 的 sha256
    expect(cookie.name, 'dsh-auth-${base64UrlNoPad(sha256.convert(utf8.encode('127.0.0.1:62680')).bytes)}');
  });

  test('从 ~/.dsh 读密钥和版本；没有文件时返回 null', () async {
    final home = await Directory.systemTemp.createTemp('dsh-official-');
    addTearDown(() => home.delete(recursive: true));
    expect(readBrowserSessionSecret(home.path), isNull);
    expect(readOfficialVersion(home.path), isNull);

    final dsh = Directory('${home.path}/.dsh')..createSync(recursive: true);
    final secret = base64UrlNoPad(List<int>.filled(32, 7));
    File('${dsh.path}/.credentials.yaml').writeAsStringSync('''
version: 1
records:
  client-connection/browser-session:
    kind: grant
    payload:
      version: 1
      secret: $secret
''');
    expect(readBrowserSessionSecret(home.path), hasLength(32));

    Directory('${dsh.path}/dsh-runtimes/dsh-primary-runtime').createSync(recursive: true);
    File('${dsh.path}/dsh-runtimes/dsh-primary-runtime/runtime.json')
        .writeAsStringSync('{"desktopVersion":"0.2.1-rc.5"}');
    expect(readOfficialVersion(home.path), '0.2.1-rc.5');
  });
}

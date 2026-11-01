// 官方 DSH 手机代理：登录换 cookie、HTTP 注入 cookie、WebSocket 转发。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/macos/official_proxy.dart';

void main() {
  test('official proxy: login, cookie injection and websocket', () async {
    const cookie = DshCookie(
      name: 'dsh-auth-test',
      value: 'v1.payload.signature',
      authority: '127.0.0.1:1',
    );
    final seen = <String>[];
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(socket.add, onDone: socket.close);
        return;
      }
      seen.add('${request.uri.path}|${request.headers.value(HttpHeaders.cookieHeader)}');
      if (request.uri.path == '/api/ping') {
        request.response
          ..statusCode = 200
          ..write('pong');
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    final proxy = OfficialProxy(
      upstream: Uri.parse('http://127.0.0.1:${upstream.port}/'),
      cookie: cookie,
    );
    final started = await proxy.start();
    final base = Uri.parse('http://127.0.0.1:${started.port}/');

    final client = HttpClient();
    try {
      // 登录：代理自己回 303 + dsh-auth cookie，不打扰官方。
      final login = await client.getUrl(base.replace(query: 'token=${started.token}'));
      login.followRedirects = false;
      final loginResponse = await login.close();
      expect(loginResponse.statusCode, 303);
      final setCookie = loginResponse.headers.value(HttpHeaders.setCookieHeader) ?? '';
      expect(setCookie, contains('dsh-auth-test='));
      await loginResponse.drain<void>();

      // 普通请求：注入官方 cookie。
      final ping = await client.getUrl(base.resolve('api/ping'));
      final pingResponse = await ping.close();
      expect(pingResponse.statusCode, 200);
      expect(await utf8.decoder.bind(pingResponse).join(), 'pong');
      expect(seen.last, '/api/ping|${cookie.header}');

      // WebSocket：升级与消息都转发。
      final socket = await WebSocket.connect(base.replace(scheme: 'ws', path: '/api/remote.mux').toString());
      final echoed = socket.first;
      socket.add('hello');
      expect(await echoed, 'hello');
      await socket.close();
    } finally {
      client.close(force: true);
      await proxy.stop();
      await upstream.close(force: true);
    }
  });
}

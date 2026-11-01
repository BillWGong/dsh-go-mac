// 官方 DSH 的手机连接代理。
//
// 手机端只认 `dsh web` 的 token 登录（GET /?token=… → 303 + dsh-auth cookie），
// 而官方桌面版用的是它自己签的浏览器 cookie。这里在 127.0.0.1 上起一个反向代理：
// 手机照常连代理、拿一个本地签的 cookie；代理把每个请求转发到官方端口，并注入
// 官方 cookie（WebSocket 升级也一起转发），Host 自动变成官方 authority。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dsh_client/dsh_client.dart';

class OfficialProxy {
  OfficialProxy({required this.upstream, required this.cookie, this.onLog});

  /// 官方 DSH 的本地地址，例如 `http://127.0.0.1:49287/`。
  final Uri upstream;

  /// 官方浏览器会话 cookie（authority = 官方 host:port）。
  final DshCookie cookie;

  final void Function(String message)? onLog;

  HttpServer? _server;

  Future<({int port, String token})> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    final random = Random.secure();
    final token = base64Url.encode(List<int>.generate(24, (_) => random.nextInt(256))).replaceAll('=', '');
    server.listen((request) => unawaited(_handle(request)));
    onLog?.call('official phone proxy on 127.0.0.1:${server.port} -> ${upstream.authority}');
    return (port: server.port, token: token);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await _proxyWebSocket(request);
      return;
    }
    // 手机的登录请求：不转给官方（它不认这个 token），直接发一个本地 cookie。
    if (request.method == 'GET' && request.uri.path == '/' && request.uri.queryParameters.containsKey('token')) {
      final response = request.response
        ..statusCode = 303
        ..headers.set(HttpHeaders.locationHeader, './')
        ..headers.set(
          HttpHeaders.setCookieHeader,
          '${cookie.name}=${cookie.value}; Path=/; Max-Age=2592000; HttpOnly; SameSite=Strict',
        );
      await response.close();
      return;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final target = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: upstream.port,
        path: request.uri.path,
        query: request.uri.hasQuery ? request.uri.query : null,
      );
      final outgoing = await client.openUrl(request.method, target);
      request.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'host' ||
            lower == 'cookie' ||
            lower == 'content-length' ||
            lower == 'transfer-encoding' ||
            lower == 'connection') {
          return;
        }
        for (final value in values) {
          outgoing.headers.add(name, value);
        }
      });
      outgoing.headers.set(HttpHeaders.cookieHeader, cookie.header);
      await outgoing.addStream(request);
      final incoming = await outgoing.close();
      final response = request.response..statusCode = incoming.statusCode;
      incoming.headers.forEach((name, values) {
        final lower = name.toLowerCase();
        if (lower == 'set-cookie' || lower == 'transfer-encoding' || lower == 'connection') return;
        for (final value in values) {
          response.headers.add(name, value);
        }
      });
      await response.addStream(incoming);
      await response.close();
    } catch (error) {
      onLog?.call('official proxy failed: $error');
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _proxyWebSocket(HttpRequest request) async {
    final client = await WebSocketTransformer.upgrade(request);
    WebSocket? server;
    try {
      final protocols = request.headers['sec-websocket-protocol']
          ?.expand((value) => value.split(','))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      final target = Uri(
        scheme: 'ws',
        host: '127.0.0.1',
        port: upstream.port,
        path: request.uri.path,
        query: request.uri.hasQuery ? request.uri.query : null,
      );
      server = await WebSocket.connect(
        target.toString(),
        headers: <String, Object>{HttpHeaders.cookieHeader: cookie.header},
        protocols: protocols,
      );
      client.listen(server.add, onDone: () => server?.close(), onError: (_) => server?.close());
      server.listen(client.add, onDone: () => client.close(), onError: (_) => client.close());
    } catch (error) {
      onLog?.call('official websocket proxy failed: $error');
      await client.close();
      await server?.close();
    }
  }
}

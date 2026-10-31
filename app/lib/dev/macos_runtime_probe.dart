// ignore_for_file: avoid_print
// macOS 本机引擎探针：不点 UI，直接跑「安装 → 启动 → 换 token → 停止」。
//
//   flutter build macos --release -t lib/dev/macos_runtime_probe.dart
//   ./build/macos/Build/Products/Release/dsh_go.app/Contents/MacOS/dsh_go
//
// 输出走 stdout；退出码 0 表示引擎真的起来了。只用于移植验证，不进正常入口。

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../macos/mac_runtime.dart';
import '../runtime/runtime_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bridge = MacRuntimeBridge();
  final done = Completer<void>();

  bridge.events.listen((event) {
    switch (event) {
      case RuntimeStatusEvent(:final status):
        print('[status] phase=${status.phase.name} error=${status.error ?? '-'} url=${status.baseUrl ?? '-'}');
      case RuntimeProgressEvent(:final step, :final done, :final total):
        if (total > 0 && (done == total || done % (192 * 1024 * 1024 ~/ 8) < 65536)) {
          print('[progress] $step ${(done / total * 100).toStringAsFixed(0)}%');
        }
      case RuntimeLogEvent(:final line, :final stream):
        if (stream == 'stderr' || line.contains('dsh web:') || line.contains('[dsh-go]')) {
          print('[log:$stream] $line');
        }
      case RuntimeNoticeEvent(:final text):
        print('[notice] $text');
    }
  });

  try {
    final before = await bridge.status();
    print('probe: before=${before.phase.name} bundled=${before.bundledVersion} installed=${before.installedVersion}');
    if (before.installedVersion == null) {
      print('probe: installing…');
      await bridge.install();
    }
    final afterInstall = await bridge.status();
    print('probe: installed=${afterInstall.installedVersion} phase=${afterInstall.phase.name}');

    print('probe: starting…');
    await bridge.start();
    RuntimeStatus? running;
    for (var i = 0; i < 120; i++) {
      final status = await bridge.status();
      if (status.isRunning) {
        running = status;
        break;
      }
      if (status.phase == RuntimePhase.error) {
        print('probe: start failed: ${status.error}');
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (running != null) {
      print('probe: RUNNING ${running.baseUrl}');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(Uri.parse('${running.baseUrl}?token=${running.token}'));
        // 303 要自己看：HttpClient 默认会跟随跳转，最后只剩 401。
        request.followRedirects = false;
        final response = await request.close();
        await response.drain<void>();
        print('probe: token exchange HTTP ${response.statusCode} (expect 303)');
        final cookie = response.cookies.where((c) => c.name.startsWith('dsh-auth')).map((c) => '${c.name}=${c.value}').join('; ');
        print('probe: cookie=${cookie.isEmpty ? 'none' : 'yes'}');
        if (cookie.isNotEmpty) {
          final home = await client.getUrl(Uri.parse(running.baseUrl!));
          home.headers.set(HttpHeaders.cookieHeader, cookie);
          final res = await home.close();
          await res.drain<void>();
          print('probe: home HTTP ${res.statusCode} (expect 200)');
        }
      } finally {
        client.close(force: true);
      }
    }
    print('probe: stopping…');
    await bridge.stop();
    print('probe: stopped, phase=${(await bridge.status()).phase.name}');
    print('PROBE OK');
  } catch (error, stack) {
    print('PROBE FAILED: $error');
    print(stack);
  } finally {
    if (!done.isCompleted) done.complete();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(0);
  }
}

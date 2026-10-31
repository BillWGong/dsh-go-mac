// macOS 接入层的入口：把原版里由 Android 原生提供的那几块，换成 Mac 上的实现。
//
// 用法（main.dart）：
//   await startMacSupport();
//   runApp(ProviderScope(overrides: [...], child: const DshApp()));
//
// 非 macOS 时两个函数都不做任何事，返回空列表。

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mac_runtime.dart';
import 'window_mode.dart';

/// 本机引擎的实例：main.dart 创建并通过 ProviderScope 覆盖，界面用它切换模式。
final macRuntimeBridgeProvider = Provider<MacRuntimeBridge>(
  (ref) => throw UnimplementedError('macRuntimeBridgeProvider 只在 macOS 上覆盖'),
);

/// 这个进程是不是 macOS 桌面版。
bool get isMacDesktop => !kIsWeb && Platform.isMacOS;

/// 启动前的准备：窗口版式订阅。失败不影响启动。
Future<void> startMacSupport() async {
  if (!isMacDesktop) return;
  await MacWindow.start();
}


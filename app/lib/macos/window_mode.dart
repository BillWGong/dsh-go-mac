// macOS 窗口版式：自适应 Mac 布局，或锁定成手机竖屏宽度。
//
// 原生侧（macos/Runner/MacHost.swift）持有真正的窗口尺寸和菜单项，这里只是它的镜像：
//   MethodChannel `dsh/window`        getMode / setMode / openSettings / showAbout
//   EventChannel  `dsh/window/events`  {"type":"mode","mode":"phone"|"adaptive"}
//
// 原生缺席时（其他平台、widget 测试）整层是空操作，[MacWindow.mode] 恒为 adaptive。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 窗口版式。
enum MacWindowMode {
  /// 按窗口宽度铺开（宽屏时侧栏常驻，和原版平板/横屏一致）。
  adaptive,

  /// 手机竖屏窗口：内容收成一条，居中显示。
  phone;

  static MacWindowMode? parse(Object? wire) => switch (wire) {
    'phone' => MacWindowMode.phone,
    'adaptive' => MacWindowMode.adaptive,
    _ => null,
  };

  /// 手机版式下内容的宽度：接近 iPhone Pro Max 的 430pt，再留一点余量。
  static const double phoneWidth = 470;
}

/// 原生窗口的 Dart 侧。所有调用都可以安全失败。
class MacWindow {
  MacWindow._();

  static const MethodChannel _methods = MethodChannel('dsh/window');
  static const EventChannel _events = EventChannel('dsh/window/events');

  /// 当前版式；原生菜单和 App 内设置都改它。
  static final ValueNotifier<MacWindowMode> mode = ValueNotifier(MacWindowMode.adaptive);

  static StreamSubscription<Object?>? _subscription;
  static bool _started = false;

  /// 订阅原生事件并读一次当前版式。重复调用无副作用。
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      _subscription = _events.receiveBroadcastStream().listen(
        (raw) {
          if (raw is! Map) return;
          if (raw['type'] != 'mode') return;
          final next = MacWindowMode.parse(raw['mode']);
          if (next != null && next != mode.value) mode.value = next;
        },
        onError: (Object _) {},
      );
    } catch (_) {
      // 没有原生侧：保持默认。
    }
    try {
      final wire = await _methods
          .invokeMethod<String>('getMode')
          .timeout(const Duration(seconds: 2), onTimeout: () => null);
      final next = MacWindowMode.parse(wire);
      if (next != null) mode.value = next;
    } on MissingPluginException {
      // 非 macOS：无窗口版式。
    } on PlatformException {
      // 读不到就按默认。
    }
  }

  /// 切换版式。原生侧会调整窗口尺寸，并记住这个选择。
  static Future<void> setMode(MacWindowMode next) async {
    mode.value = next;
    try {
      await _methods.invokeMethod<void>('setMode', {'mode': next.name});
    } on MissingPluginException {
      // 非 macOS。
    } on PlatformException {
      // 窗口没准备好：下次打开按存储的值恢复。
    }
  }

  /// 打开 App 的「设置 › 界面」页（原生菜单用）。
  static Future<void> openInterfaceSettings() async {
    try {
      await _methods.invokeMethod<void>('openSettings');
    } catch (_) {}
  }

  /// 卸下订阅（测试用）。
  @visibleForTesting
  static Future<void> reset() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    mode.value = MacWindowMode.adaptive;
  }
}

/// macOS 手机版式的内容框：窗口被拉宽时，内容仍是手机那条，居中。
///
/// 不是 macOS 时原样返回 [child]，没有额外布局开销。
class MacWindowFrame extends StatelessWidget {
  const MacWindowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MacWindowMode>(
      valueListenable: MacWindow.mode,
      child: child,
      builder: (context, mode, child) {
        if (mode != MacWindowMode.phone) return child!;
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: MacWindowMode.phoneWidth,
                height: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

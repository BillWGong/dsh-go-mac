import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'dev/frame_probe.dart';
import 'diagnostics/app_error_log.dart';
import 'launch/launch_state.dart';
import 'macos/mac_runtime.dart';
import 'macos/macos_support.dart';
import 'macos/official_dsh.dart';
import 'performance/performance_state.dart';
import 'runtime/runtime_state.dart';
import 'state/locale_state.dart';
import 'ui/common/third_party_licenses.dart';
import 'ui/settings/font_licenses.dart';
import 'ui/theme/theme.dart';

Future<void> main() => runWithFrameProbe(_startApp);

Future<void> _startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  appErrorCapture.install();
  // The first frame is already in the chosen language (设置 → 语言), and is the launch
  // window's own picture (启动画面, lib/launch/launch_state.dart).
  await Future.wait([AppLanguageController.load(), LaunchController.begin()]);
  // MIT / OFL notices must ship with the APK, not just the sources.
  registerThirdPartyLicenses();
  registerFontLicenses();
  // Edge-to-edge with transparent system bars; pages refine the icon brightness
  // through AnnotatedRegion(dshSystemOverlay(...)).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(dshSystemOverlay(PlatformDispatcher.instance.platformBrightness));
  // macOS: 窗口版式。原生缺席时立刻返回。
  await startMacSupport();
  // macOS 的本机引擎换成原生 Node 实现；其他平台保持 Kotlin/Android 原样。
  // 「使用官方 DSH」的开关在启动时读一次（切换时由设置页调用 setOfficial）。
  var officialDsh = false;
  if (isMacDesktop) {
    try {
      officialDsh = (await SharedPreferences.getInstance()).getBool(macOfficialDshPref) ?? false;
    } catch (_) {}
  }
  final macRuntime = isMacDesktop ? MacRuntimeBridge(official: officialDsh) : null;
  if (macRuntime != null) {
    // 关窗/退出时先停引擎，别留下孤儿 Node 进程占着端口。
    // 监听器由 WidgetsBinding 持有，不需要另外保存。
    AppLifecycleListener(
      onExitRequested: () async {
        await macRuntime.stop();
        return AppExitResponse.exit;
      },
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        if (macRuntime != null) runtimeBridgeProvider.overrideWithValue(macRuntime),
        if (macRuntime != null) macRuntimeBridgeProvider.overrideWithValue(macRuntime),
        // Mac 是桌面性能档：别因为拿不到手机的性能快照就把默认判成「轻量」，
        // 那会关掉自动启动和桌宠。
        if (isMacDesktop)
          performanceDefaultsProvider.overrideWith((ref) {
            final prefs = ref.watch(performancePrefsProvider);
            return PerformanceDefaults(
              lightweight: false,
              blur: prefs.blur ?? true,
              reduceMotion: !(prefs.animations ?? true),
              petEnabled: true,
              autoStartLocal: true,
              recommendRemote: false,
            );
          }),
      ],
      child: const DshApp(),
    ),
  );
}

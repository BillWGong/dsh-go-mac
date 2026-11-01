import 'dart:io';

import 'package:dsh_app/macos/mac_runtime.dart';
import 'package:dsh_app/runtime/runtime_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('空目录：报告未安装，并带上随包 runtime 的版本', () async {
    final dir = await Directory.systemTemp.createTemp('dsh-mac-runtime-');
    addTearDown(() => dir.delete(recursive: true));
    final bridge = MacRuntimeBridge(appSupportPath: dir.path);
    final status = await bridge.status();
    expect(status.phase, RuntimePhase.notInstalled);
    expect(status.installedVersion, isNull);
    // 干净 clone 里没有运行时包（manifest 是生成物）；跑过
    // runtime/build-runtime-macos.sh 后才会出现。
    if (status.bundledVersion != null) {
      expect(status.bundledVersion, 'macos-r1');
      expect(status.dshVersion, '0.2.1-rc.4');
    }
  });

  test('Android 专属能力在 Mac 上返回明确的「没有」，不抛异常', () async {
    final dir = await Directory.systemTemp.createTemp('dsh-mac-runtime-');
    addTearDown(() => dir.delete(recursive: true));
    final bridge = MacRuntimeBridge(appSupportPath: dir.path);
    expect(await bridge.batteryExempt(), isNull);
    expect(await bridge.requestBatteryExempt(), isNull);
    expect(await bridge.backgroundSettings(), isNull);
    expect(await bridge.openBackgroundSettings(), isNull);
    expect(await bridge.openVendorSettings('background'), isNull);
    expect(await bridge.openAllFilesAccess(), isTrue);
    final storage = await bridge.storageStatus();
    expect(storage.granted, isTrue);
    expect(await bridge.networkMetered(), isFalse);
    expect(await bridge.lastKnownGood(), isNotNull);
    expect((await bridge.safePreflight()).isEmpty, isTrue);
  });
}

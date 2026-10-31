// 设置 › 本机引擎里的一张卡：用「正在运行的官方 DSH」还是内置运行时。
//
// 打开后本机引擎直接连官方 DeepSeek Harness 暴露在 127.0.0.1 的 DSH 服务：
// 对话、模型、插件都是官方 App 那一份，不需要 SSH / DSH Remote，也不用装 750 MB 运行时。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../runtime/runtime_bridge.dart';
import '../runtime/runtime_state.dart';
import '../ui/settings/settings_widgets.dart';
import 'macos_support.dart';
import 'official_dsh.dart';

class MacOfficialDshSection extends ConsumerStatefulWidget {
  const MacOfficialDshSection({super.key});

  @override
  ConsumerState<MacOfficialDshSection> createState() => _MacOfficialDshSectionState();
}

class _MacOfficialDshSectionState extends ConsumerState<MacOfficialDshSection> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((prefs) {
          if (!mounted) return;
          setState(() {
            _enabled = prefs.getBool(macOfficialDshPref) ?? false;
            _loaded = true;
          });
        })
        .catchError((Object _) {
          if (mounted) setState(() => _loaded = true);
        });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(macOfficialDshPref, value);
    } catch (_) {}
    await ref.read(macRuntimeBridgeProvider).setOfficial(value);
    ref.invalidate(localRuntimeProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (!isMacDesktop || !_loaded) return const SizedBox.shrink();
    final en = AppLocale.isEnglish;
    final status = ref.watch(localRuntimeProvider).status;
    final connected = _enabled && status.official && status.phase == RuntimePhase.running;
    final detail = connected
        ? (en
              ? 'Connected to the running DeepSeek Harness at ${status.baseUrl}'
              : '已连上正在运行的 DeepSeek Harness：${status.baseUrl}')
        : (en
              ? 'Share chats, models and plugins with the DeepSeek Harness app running on this Mac. No SSH, no DSH Remote.'
              : '直接连这台 Mac 上正在运行的 DeepSeek Harness，共享它的对话、模型和插件。不需要 SSH 或 DSH Remote。');

    return SettingsSection(
      title: en ? 'This Mac' : '本机',
      children: [
        SwitchListTile.adaptive(
          value: _enabled,
          onChanged: _toggle,
          title: Text(en ? 'Use the official DSH' : '使用官方 DSH'),
          subtitle: Text(detail),
        ),
        if (_enabled && status.official)
          InfoRow(
            label: en ? 'Engine' : '引擎',
            value: status.baseUrl ?? (en ? 'not running' : '未运行'),
            mono: true,
          ),
      ],
    );
  }
}

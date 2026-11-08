import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/engine_control.dart';
import '../state/hosts_state.dart';
import '../runtime/runtime_bridge.dart';
import '../runtime/runtime_state.dart';
import '../ui/common/list_page_row.dart';
import '../ui/shell/page_frame.dart';
import '../ui/theme/app_icons.dart';
import 'mac_peekaboo.dart';

/// Settings → Mac 操控. Peekaboo only runs on macOS 15+; older systems keep
/// the existing “未就绪” state and never start the helper.
class MacPeekabooPage extends ConsumerStatefulWidget {
  const MacPeekabooPage({super.key});

  @override
  ConsumerState<MacPeekabooPage> createState() => _MacPeekabooPageState();
}

class _MacPeekabooPageState extends ConsumerState<MacPeekabooPage> with WidgetsBindingObserver {
  final _channel = MacPeekabooChannel();
  MacPeekabooStatus? _status;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await _channel.status();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    if (!ref.read(activeHostProvider).isLocal) {
      _flash(AppLocale.isEnglish ? 'Mac control only works on this Mac' : 'Mac 操控只在这台 Mac 上可用');
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      final status = await _channel.setEnabled(value);
      if (!mounted) return;
      setState(() => _status = status);
      final runtime = ref.read(localRuntimeProvider).status;
      if (runtime.phase == RuntimePhase.running ||
          runtime.phase == RuntimePhase.starting ||
          runtime.phase == RuntimePhase.stopping) {
        await EngineControl.restart(ProviderScope.containerOf(context));
      }
      if (!mounted) return;
      _flash(
        value
            ? (AppLocale.isEnglish ? 'Mac control is on' : 'Mac 操控已开启')
            : (AppLocale.isEnglish ? 'Mac control is off' : 'Mac 操控已关闭'),
      );
    } catch (e) {
      if (mounted) _flash(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _permission(String kind) async {
    await _channel.requestPermission(kind);
    await _refresh();
  }

  void _flash(String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _status;
    final english = AppLocale.isEnglish;
    final official = ref.watch(localRuntimeProvider.select((s) => s.status.official));
    return AppPage.list(
      title: l10n.phoneControlTitle,
      subtitle: Text(english ? 'Powered by Peekaboo · macOS 15+' : '由 Peekaboo 提供 · macOS 15+'),
      children: [
        if (_loading)
          const ListPageCard(children: [ListPageRow(title: '…')])
        else if (status == null || !status.supported)
          ListPageCard(
            children: [
              ListPageRow(
                icon: AppIcons.phoneControl,
                title: l10n.phoneControlModuleNotReady,
                subtitle: english
                    ? 'Mac control needs macOS 15. This Mac is running macOS ${status?.osVersion ?? '?'}.'
                    : 'Mac 操控需要 macOS 15，这台 Mac 是 ${status?.osVersion ?? '?'}。',
              ),
            ],
          )
        else if (official)
          ListPageCard(
            children: [
              ListPageRow(
                icon: AppIcons.phoneControl,
                title: english ? 'Switch to the bundled engine first' : '请先切换到内置引擎',
                subtitle: english
                    ? 'Mac control runs through the bundled engine. Official DSH mode does not load the Peekaboo tools.'
                    : 'Mac 操控通过内置引擎运行；官方 DSH 模式不会加载 Peekaboo 工具。',
              ),
            ],
          )
        else ...[
          ListPageCard(
            children: [
              ListPageRow(
                icon: AppIcons.phoneControl,
                title: l10n.phoneControlTitle,
                subtitle: status.enabled
                    ? (english ? 'Peekaboo is running in the background' : 'Peekaboo 正在后台工作')
                    : (english ? 'Let DSH control this Mac through Peekaboo' : '通过 Peekaboo 让 DSH 操作这台 Mac'),
                trailing: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : Switch(value: status.enabled, onChanged: _toggle),
                onTap: _busy ? null : () => _toggle(!status.enabled),
              ),
              if (!status.helperReady || status.error != null)
                ListPageRow(
                  icon: AppIcons.permissionRisky,
                  title: english ? 'Peekaboo helper is not ready' : 'Peekaboo 组件未就绪',
                  subtitle: status.error ?? (english ? 'Reinstall the app or check permissions.' : '请重新安装 App 或检查权限。'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListPageCard(
            title: english ? 'Permissions' : '权限',
            children: [
              _permissionRow(
                icon: AppIcons.phoneControl,
                title: english ? 'Screen Recording' : '屏幕录制',
                granted: status.screenRecording,
                kind: 'screenRecording',
              ),
              _permissionRow(
                icon: AppIcons.accessibility,
                title: english ? 'Accessibility' : '辅助功能',
                granted: status.accessibility,
                kind: 'accessibility',
              ),
              _permissionRow(
                icon: AppIcons.permissions,
                title: english ? 'Event Synthesizing' : '事件合成',
                granted: status.eventSynthesizing,
                kind: 'eventSynthesizing',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListPageCard(
            title: english ? 'What Peekaboo can do' : 'Peekaboo 能做什么',
            children: [
              ListPageRow(
                icon: AppIcons.phoneControl,
                title: english ? 'See and operate apps in the background' : '在后台查看和操作 App',
                subtitle: english
                    ? 'Screen capture, accessibility elements, click, type, scroll, windows and menus.'
                    : '截屏、辅助功能元素、点击、输入、滚动、窗口和菜单。',
              ),
              ListPageRow(
                icon: AppIcons.permissionRisky,
                title: english ? 'No per-action approval' : '不会逐次确认',
                subtitle: english
                    ? 'Peekaboo runs in background-only mode. Shell, browser, dialogs and clipboard are disabled.'
                    : 'Peekaboo 仅后台运行；Shell、浏览器、对话框和剪贴板已禁用。',
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListPageCard(
            children: [
              ListPageRow(
                icon: AppIcons.info,
                title: 'Peekaboo ${status.helperVersion ?? ''}',
                subtitle: english
                    ? 'Permissions are granted to DSH Go Mac (shown as dsh_go), which runs Peekaboo as its helper. Turning this off or restarting the engine removes the tools.'
                    : '权限授予的是 DSH Go Mac（显示为 dsh_go），Peekaboo 作为它的 helper 运行。关闭开关或重启引擎后，工具会移除。',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _permissionRow({required IconData icon, required String title, required bool granted, required String kind}) {
    final english = AppLocale.isEnglish;
    return ListPageRow(
      icon: icon,
      iconColor: granted ? null : Theme.of(context).colorScheme.error,
      title: title,
      subtitle: granted ? (english ? 'Granted' : '已允许') : (english ? 'Not granted' : '未允许'),
      trailing: granted
          ? const Icon(Icons.check, size: 18)
          : TextButton(onPressed: () => _permission(kind), child: Text(english ? 'Open' : '去设置')),
    );
  }
}

// 「手机连接」：把手机 SSH 接管这台 Mac 内置 DSH 所需的信息直接列出来。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../runtime/runtime_bridge.dart';
import '../runtime/runtime_state.dart';
import '../ui/shell/page_frame.dart';
import '../ui/settings/settings_widgets.dart';
import '../ui/theme/app_icons.dart';
import 'phone_link.dart';

class PhoneLinkPage extends ConsumerStatefulWidget {
  const PhoneLinkPage({super.key});

  @override
  ConsumerState<PhoneLinkPage> createState() => _PhoneLinkPageState();
}

class _PhoneLinkPageState extends ConsumerState<PhoneLinkPage> {
  MacPhoneLink? _link;
  bool _attach = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final link = await readMacPhoneLink();
    final attach = await phoneAttachReady();
    if (!mounted) return;
    setState(() {
      _link = link;
      _attach = attach;
    });
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocale.isEnglish ? 'Copied' : '已复制'), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openSharing() => Process.run('/usr/bin/open', <String>[
    'x-apple.systempreferences:com.apple.Sharing-Settings.extension',
  ]);

  @override
  Widget build(BuildContext context) {
    final en = AppLocale.isEnglish;
    final link = _link;
    final status = ref.watch(localRuntimeProvider).status;
    final running = status.phase == RuntimePhase.running && !status.official;
    final theme = Theme.of(context);
    final host = link?.hostSpec;

    return AppPage(
      title: en ? 'Phone link' : '手机连接',
      subtitle: Text(
        en
            ? 'Let DSH Go on your phone use this Mac’s built-in DSH over SSH.'
            : '用手机上的 DSH Go，通过 SSH 使用这台 Mac 的内置 DSH。',
      ),
      actions: [
        GlassIconButton(
          icon: AppIcons.refresh,
          tooltip: en ? 'Refresh' : '刷新',
          onPressed: () => unawaited(_load()),
        ),
      ],
      slivers: [
        SliverList.list(
          children: [
            SettingsSection(
              title: en ? 'Connect from the phone' : '手机端填写',
              children: [
                InfoRow(label: en ? 'Host' : '主机', value: host ?? (en ? 'No LAN address' : '未连接局域网'), mono: true),
                InfoRow(label: en ? 'User' : '用户名', value: link?.user ?? '—', mono: true),
                InfoRow(label: en ? 'Port' : '端口', value: '22', mono: true),
                InfoRow(
                  label: en ? 'LAN address' : '局域网地址',
                  value: link == null || link.addresses.isEmpty ? '—' : link.addresses.join(', '),
                  mono: true,
                ),
                SettingsTile(
                  icon: AppIcons.link,
                  title: en ? 'Copy host' : '复制主机地址',
                  subtitle: host,
                  onTap: host == null ? null : () => unawaited(_copy(host)),
                ),
              ],
            ),
            SettingsSection(
              title: en ? 'Password' : '密码',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SettingsMetrics.inset, 12, SettingsMetrics.inset, 12),
                  child: Text(
                    en
                        ? 'Use the password you type to unlock this Mac — the login password of the account above. '
                              'It is not a DeepSeek API key and not a DSH Go password. '
                              'SSH keys work too and are safer for everyday use.'
                        : '密码就是这台 Mac 的登录密码——你开机、解锁屏幕时输入的那个，属于上面显示的用户。'
                              '它不是 DeepSeek API Key，也不是 DSH Go 的密码。用 SSH 密钥登录也可以，日常更安全。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                  ),
                ),
              ],
            ),
            SettingsSection(
              title: en ? 'Status' : '状态',
              children: [
                InfoRow(
                  label: en ? 'Remote Login' : '远程登录',
                  value: link == null ? '—' : (link.sshEnabled ? (en ? 'On' : '已开启') : (en ? 'Off' : '未开启')),
                ),
                InfoRow(
                  label: en ? 'Built-in engine' : '内置引擎',
                  value: running ? (en ? 'Running' : '运行中') : (en ? 'Stopped' : '未运行'),
                ),
                InfoRow(
                  label: en ? 'Phone handshake' : '手机握手',
                  value: _attach ? (en ? 'Ready' : '已就绪') : (en ? 'Not yet' : '未就绪'),
                ),
                if (link != null && !link.sshEnabled)
                  SettingsTile(
                    icon: AppIcons.configure,
                    title: en ? 'Turn on Remote Login' : '打开「远程登录」',
                    subtitle: en
                        ? 'System Settings › General › Sharing › Remote Login'
                        : '系统设置 › 通用 › 共享 › 远程登录',
                    onTap: () => unawaited(_openSharing()),
                  ),
              ],
            ),
            SettingsSection(
              title: en ? 'How to connect' : '连接步骤',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SettingsMetrics.inset, 12, SettingsMetrics.inset, 12),
                  child: Text(
                    en
                        ? '1. Turn on Remote Login on this Mac.\n'
                              '2. On the phone: Switch host › Add SSH host, fill in the host above, port 22, and the Mac login password.\n'
                              '3. Keep the built-in engine running here. The phone reuses it, so no second DSH is started.\n'
                              '4. The official DeepSeek Harness uses its own data and is never touched by this link.'
                        : '1. 在这台 Mac 上打开「远程登录」。\n'
                              '2. 手机上：切换主机 › 添加 SSH 主机，填上面的主机地址、端口 22、Mac 登录密码。\n'
                              '3. 这里保持内置引擎运行；手机会直接复用它，不会另起一个 DSH。\n'
                              '4. 官方 DeepSeek Harness 用自己那份数据，这条链路永远不会碰它。',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// 菜单栏 Live Activity：把运行状态、待批准和快捷操作放到 macOS 状态栏。
//
// Dart 推状态到原生（running / 待批准 / 主机），原生点按钮回动作
// （stop / newChat / openPending / openWindow）。原生缺失时整段静默跳过。

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/runtime_bridge.dart';
import '../runtime/runtime_state.dart';
import '../state/chat_state.dart';
import '../state/hosts_state.dart';
import '../state/session_attention_state.dart';
import '../state/sessions_state.dart';

class MacMenuBar {
  MacMenuBar(this._container);

  static const _channel = MethodChannel('dsh/menubar');

  final ProviderContainer _container;
  Timer? _ticker;
  Timer? _doneTimer;
  ProviderSubscription<ChatState>? _chat;

  String? _session;
  DateTime? _startedAt;
  bool _running = false;
  bool _done = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler(_onCall);
    _container.listen<String?>(currentSessionProvider, (previous, next) {
      _session = next;
      _watchChat();
      _push();
    }, fireImmediately: true);
    _container.listen<Map<String, PendingKind>>(pendingInteractionsProvider, (previous, next) => _push());
    _container.listen<HostRef>(activeHostProvider, (previous, next) => _push());
    _container.listen<RuntimeStatus>(localRuntimeProvider.select((state) => state.status), (previous, next) => _push());
    _watchChat();
    // 引擎和原生通道可能晚一步就绪，补两次首推。
    Timer(const Duration(seconds: 1), _push);
    Timer(const Duration(seconds: 3), _push);
  }

  void _watchChat() {
    _chat?.close();
    _chat = null;
    _running = false;
    _startedAt = null;
    final session = _session;
    if (session == null) return;
    _chat = _container.listen<ChatState>(chatProvider(session), (previous, next) => _onChat(next), fireImmediately: true);
  }

  void _onChat(ChatState state) {
    final running = state.running;
    if (running && !_running) {
      _startedAt = DateTime.now();
      _doneTimer?.cancel();
      _done = false;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _push());
    } else if (!running && _running) {
      _ticker?.cancel();
      _ticker = null;
      _startedAt = null;
      _done = true;
      _doneTimer?.cancel();
      _doneTimer = Timer(const Duration(seconds: 3), () {
        _done = false;
        _push();
      });
    }
    _running = running;
    _push();
  }

  void _push() {
    final pending = _container.read(pendingInteractionsProvider);
    final host = _container.read(activeHostProvider);
    final official = _container.read(localRuntimeProvider).status.official;
    final label = host.isLocal
        ? (official ? '官方 DSH' : '内置 DSH')
        : host.name?.isNotEmpty == true
        ? host.name!
        : '远程主机';
    final elapsed = _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds;
    final firstPending = pending.keys.isEmpty ? null : pending.keys.first;
    _send({
      'running': _running,
      'elapsed': elapsed,
      'done': _done,
      'pending': pending.length,
      'pendingSession': firstPending,
      'pendingKind': pending[firstPending]?.name,
      'host': label,
      'official': official,
      'session': _session,
    });
  }

  Future<void> _send(Map<String, Object?> state) async {
    try {
      await _channel.invokeMethod<void>('state', state);
    } catch (_) {
      // 原生没装菜单栏：状态栏只是附加功能。
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'action':
        switch (call.arguments) {
          case 'stop':
            final session = _session;
            if (session != null) {
              await _container.read(chatProvider(session).notifier).cancel();
            }
          case 'newChat':
            _container.read(currentSessionProvider.notifier).select(null);
          case 'openPending':
            final pending = _container.read(pendingInteractionsProvider);
            if (pending.isNotEmpty) {
              _container.read(currentSessionProvider.notifier).select(pending.keys.first);
            }
        }
    }
    return null;
  }
}

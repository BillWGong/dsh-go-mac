// Feeds the out-of-app overlay (`dsh/pet_overlay`) every new [PetState].

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'overlay_channel.dart';
import 'pet_overlay_actions.dart';
import 'pet_prefs.dart';
import 'pet_signals.dart';
import 'pet_state.dart';
import 'pet_voice_dialog.dart';

/// Where states go: the overlay's channel (`dsh/pet_overlay`).
final petOverlayPushProvider = Provider<Future<void> Function(PetState state)>(
  (ref) => ref.watch(petOverlayChannelProvider).push,
);

/// Watch it to keep the overlay fed: pushes the state on start and on every
/// change (equal states are not pushed twice). Failures are dropped: no
/// native side in tests, or the overlay is off.
final petOverlayBridgeProvider = Provider<void>((ref) {
  ref.watch(petOverlayActionBridgeProvider);
  // 大小 / 主题这类偏好不一定会改变 mood state，单独补一次推送。
  ref.listen<PetSize>(petPrefsProvider.select((p) => p.size), (previous, next) {
    if (previous == next) return;
    final push = ref.read(petOverlayPushProvider);
    unawaited(() async {
      try {
        await push(ref.read(petStateProvider));
      } catch (_) {}
    }());
  });
  ref.listen<PetState>(petStateProvider, (previous, next) {
    if (previous == next) return;
    final push = ref.read(petOverlayPushProvider);
    unawaited(() async {
      try {
        await push(next);
      } catch (_) {}
    }());
  }, fireImmediately: true);
});

/// Keeps [petOverlayBridgeProvider] alive where it is mounted (the home
/// shell, so the overlay is fed in both 原生 and 网页 modes). Draws nothing.
class PetOverlayBridge extends ConsumerStatefulWidget {
  const PetOverlayBridge({super.key});
  @override
  ConsumerState<PetOverlayBridge> createState() => _PetOverlayBridgeState();
}

class _PetOverlayBridgeState extends ConsumerState<PetOverlayBridge> {
  late final PetOverlayChannel _channel;
  bool _voiceOpen = false;

  @override
  void initState() {
    super.initState();
    _channel = ref.read(petOverlayChannelProvider);
    _channel.voiceFallback = (text) async {
      if (!mounted || _voiceOpen) return text;
      _voiceOpen = true;
      try {
        return await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (_) => PetVoiceDialog(text: text),
            ) ??
            text;
      } finally {
        _voiceOpen = false;
      }
    };
  }

  @override
  void dispose() {
    _channel.voiceFallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(petOverlayBridgeProvider);
    return const SizedBox.shrink();
  }
}

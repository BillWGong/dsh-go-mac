import 'package:flutter/services.dart';

/// Native side of the Mac control settings page. The actual automation tools
/// live in Peekaboo's MCP server; this channel only reports and stores the
/// enable/disable choice, helper availability and permission status.
class MacPeekabooStatus {
  const MacPeekabooStatus({
    this.supported = false,
    this.osVersion = '',
    this.enabled = false,
    this.helperReady = false,
    this.helperVersion,
    this.screenRecording = false,
    this.accessibility = false,
    this.eventSynthesizing = false,
    this.error,
  });

  factory MacPeekabooStatus.fromMap(Map<Object?, Object?> m) {
    final permissions = m['permissions'];
    final p = permissions is Map ? permissions : const {};
    return MacPeekabooStatus(
      supported: m['supported'] == true,
      osVersion: m['osVersion'] is String ? m['osVersion'] as String : '',
      enabled: m['enabled'] == true,
      helperReady: m['helperReady'] == true,
      helperVersion: m['helperVersion'] is String ? m['helperVersion'] as String : null,
      screenRecording: p['screenRecording'] == true,
      accessibility: p['accessibility'] == true,
      eventSynthesizing: p['eventSynthesizing'] == true,
      error: m['error'] is String ? m['error'] as String : null,
    );
  }

  final bool supported;
  final String osVersion;
  final bool enabled;
  final bool helperReady;
  final String? helperVersion;
  final bool screenRecording;
  final bool accessibility;
  final bool eventSynthesizing;
  final String? error;

  bool get permissionsReady => screenRecording && accessibility;
}

class MacPeekabooChannel {
  MacPeekabooChannel({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('dsh/mac_peekaboo');

  final MethodChannel _channel;

  Future<MacPeekabooStatus> status() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('status');
      return map == null ? const MacPeekabooStatus() : MacPeekabooStatus.fromMap(map);
    } on MissingPluginException {
      return const MacPeekabooStatus(error: 'not ready');
    } on PlatformException catch (e) {
      return MacPeekabooStatus(error: e.message);
    }
  }

  Future<MacPeekabooStatus> setEnabled(bool enabled) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('setEnabled', {'enabled': enabled});
    return map == null ? const MacPeekabooStatus() : MacPeekabooStatus.fromMap(map);
  }

  Future<bool> requestPermission(String kind) async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission', {'kind': kind}) ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openSettings(String kind) => _channel.invokeMethod<void>('openSettings', {'kind': kind});
}

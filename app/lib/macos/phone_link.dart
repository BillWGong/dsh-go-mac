// 手机通过 SSH 连接这台 Mac 所需的本地事实：用户名、局域网地址、远程登录状态。
//
// SSH 连上后，手机端 DSH Go 会读 ~/.dsh-app-remote/ 里 App 写好的握手文件，复用
// 内置引擎（见 mac_runtime.dart 的 _publishPhoneAttach），不会另起 DSH，也不会碰官方 DSH。

import 'dart:io';

/// 这台 Mac 的连接信息。
class MacPhoneLink {
  const MacPhoneLink({
    required this.user,
    required this.hostName,
    required this.addresses,
    required this.sshEnabled,
  });

  final String user;
  final String hostName;

  /// 局域网 IPv4，en0 在前。
  final List<String> addresses;

  /// 22 端口在监听（系统设置里开了「远程登录」）。
  final bool sshEnabled;

  String? get primaryAddress => addresses.isEmpty ? null : addresses.first;
  String? get hostSpec => primaryAddress == null ? null : '$user@$primaryAddress';
}

Future<MacPhoneLink> readMacPhoneLink() async {
  final user = Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? '';
  final host = Platform.localHostname;
  final found = <(String, String)>[];
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        if (address.address.startsWith('169.254.')) continue;
        found.add((interface.name, address.address));
      }
    }
  } catch (_) {}
  found.sort((a, b) {
    int rank(String name) => name.startsWith('en') ? 0 : name.startsWith('bridge') ? 2 : 1;
    final byRank = rank(a.$1).compareTo(rank(b.$1));
    return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
  });
  var ssh = false;
  try {
    final socket = await Socket.connect('127.0.0.1', 22, timeout: const Duration(milliseconds: 800));
    socket.destroy();
    ssh = true;
  } catch (_) {}
  return MacPhoneLink(
    user: user,
    hostName: host,
    addresses: [for (final entry in found) entry.$2],
    sshEnabled: ssh,
  );
}

/// `~/.dsh-app-remote` 里的握手文件是否指向一个活着的内置引擎。
Future<bool> phoneAttachReady() async {
  final home = Platform.environment['HOME'];
  if (home == null) return false;
  final pidFile = File('$home/.dsh-app-remote/web.pid');
  if (!pidFile.existsSync()) return false;
  final pid = int.tryParse(pidFile.readAsStringSync().trim());
  if (pid == null || pid <= 0) return false;
  final alive = await Process.run('/bin/kill', <String>['-0', '$pid']);
  return alive.exitCode == 0;
}

import 'dart:io';
import 'package:dsh_client/dsh_client.dart';
Future<void> main() async {
  final line = File('${Platform.environment['HOME']}/.dsh-app-remote/web.log').readAsStringSync();
  final l = DshLaunchUrl.tryParse(line)!;
  final c = await DshClient.connect(baseUri: l.baseUri, token: l.token);
  final s = await c.createSession();
  await c.renameSession(s.sessionId, '做个下载进度条');
  print('SID=${s.sessionId}');
  await c.close();
}

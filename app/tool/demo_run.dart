import 'dart:io';
import 'package:dsh_client/dsh_client.dart';
Future<void> main() async {
  final line = File('${Platform.environment['HOME']}/.dsh-app-remote/web.log').readAsStringSync();
  final l = DshLaunchUrl.tryParse(line)!;
  final c = await DshClient.connect(baseUri: l.baseUri, token: l.token);
  await c.prompt('session-459e65e6-2e90-4663-b690-e9ede0bfdbea',
    '做个下载进度条。先在 /tmp/dsh-demo 下用 Python 写一个 progress.py：每 0.5 秒打印一行带百分比的进度，共 20 行；然后运行它；最后告诉我文件路径和运行结果。不用问我，直接做。');
  print('PROMPT SENT');
  await c.close();
}

// ignore_for_file: avoid_print
import 'dart:io';
import 'package:dsh_client/dsh_client.dart';

Future<void> main() async {
  final line = File('${Platform.environment['HOME']}/.dsh-app-remote/web.log').readAsStringSync();
  final launch = DshLaunchUrl.tryParse(line)!;
  final client = await DshClient.connect(baseUri: launch.baseUri, token: launch.token);
  final sessions = await client.listSessions();
  print('PROXY OK sessions=${sessions.length} base=${launch.baseUri}');
  await client.close();
}

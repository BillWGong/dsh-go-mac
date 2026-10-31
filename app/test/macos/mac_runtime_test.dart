import 'package:dsh_app/macos/mac_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// macOS 本机引擎的启动参数 / overlay：不用真装运行时就该能验证。
void main() {
  const manifest = <String, Object?>{
    'launch': <String, Object?>{
      'argv': <String>[
        '{RUNTIME}/node/bin/node',
        '{RUNTIME}/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js',
        '{DSH_PROFILE_ARGS}',
        '--host',
        '127.0.0.1',
        '--port',
        '{PORT}',
        '--no-open',
      ],
    },
  };

  List<String> expand({bool safe = false}) => expandMacLaunchArgs(
    manifest,
    runtimeDir: '/R',
    home: '/H',
    port: 4123,
    safe: safe,
  );

  test('正常启动：web + 正常 overlay', () {
    expect(expand(), <String>[
      '/R/node/bin/node',
      '/R/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js',
      'web',
      '--patch',
      '/R/etc/dsh-app/dsh-web.patch.yml',
      '--host',
      '127.0.0.1',
      '--port',
      '4123',
      '--no-open',
    ]);
  });

  test('安全模式：救援 profile + 安全 overlay，端口照常', () {
    expect(expand(safe: true), <String>[
      '/R/node/bin/node',
      '/R/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js',
      '--profile',
      'dsh-app-safe',
      '--from-default-profile',
      'web',
      '--patch',
      '/R/etc/dsh-app/safe-mode.patch.yml',
      '--host',
      '127.0.0.1',
      '--port',
      '4123',
      '--no-open',
    ]);
  });

  test('overlay 里是运行时的绝对路径，DSH 才能按路径加载 bridge', () {
    expect(macLaunchOverlay('/R'), contains('name: /R/bridge/lib/index.js'));
    expect(macLaunchOverlay('/R'), contains('- id: plugin-manager'));
    expect(macSafeOverlay, contains('disabled: true'));
    expect(macSafeOverlay, isNot(contains('dsh-go-bridge')));
  });
}

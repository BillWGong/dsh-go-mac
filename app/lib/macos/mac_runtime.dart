// macOS 本机引擎：把 DSH 的原生 Node 运行时跑在这台 Mac 上。
//
// Android 版的 `dsh/runtime` 由 Kotlin 实现，里面是 PRoot + Ubuntu rootfs；macOS 不需要
// 任何 Linux 兼容层——Node 24 有官方 darwin-arm64 构建，DSH 就是普通 npm 包，直接起进程
// 即可。这里实现 `RuntimeBridge` 的同一套契约（同样的状态字段、事件、安全模式语义），
// 所以 `lib/runtime/runtime_state.dart` 及其上的所有界面一行都不用改。
//
// 运行时布局（`~/Library/Application Support/<app>/runtime/`）：
//   node/                 官方 Node 发行版（bin/node）
//   dsh/node_modules/...  npm ci 出来的 DSH 依赖树
//   etc/dsh-app/          启动用的 patch overlay、安全模式 overlay
//   home/                 引擎的 HOME（.dsh、工作区、插件都在里面）
//
// 运行时包由 `runtime/build-runtime-macos.sh` 产出，作为 Flutter asset 打进 App；也可以
// 由 manifest 的 `url` 在首次安装时下载。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../runtime/runtime_bridge.dart';
import 'official_dsh.dart';

/// macOS 上的一条本机引擎。
class MacRuntimeBridge implements RuntimeBridge {
  MacRuntimeBridge({String? appSupportPath, bool official = false})
    : _appSupportOverride = appSupportPath,
      _official = official; // ignore: prefer_initializing_formals

  final String? _appSupportOverride;

  /// 用「正在运行的官方 DSH」而不是内置运行时。
  bool _official;
  bool get official => _official;
  OfficialDsh? _officialNow;
  DateTime? _officialAt;

  static const String _officialNotRunning = '官方 DSH 没有在运行：先打开 DeepSeek Harness，再回到这里。';

  static const String _assetDir = 'assets/runtime-macos';
  static const String _manifestAsset = '$_assetDir/manifest.json';
  static const String _archiveAsset = '$_assetDir/runtime-arm64.tar.gz';

  static final RegExp _tokenLine = RegExp(r'^dsh web: (http://127\.0\.0\.1:[0-9]+/)\?token=([A-Za-z0-9_-]+)');
  static const int _healthyMs = 120000;

  final StreamController<RuntimeEvent> _events = StreamController<RuntimeEvent>.broadcast();
  final List<String> _logs = <String>[];

  Directory? _support;
  Map<String, Object?>? _manifest;

  RuntimePhase _phase = RuntimePhase.notInstalled;
  String? _installedVersion;
  String? _bundledVersion;
  String? _dshVersion;
  String? _nodeVersion;
  String? _baseUrl;
  String? _token;
  String? _error;
  EngineMode _mode = EngineMode.normal;
  SafeModeState _safeState = SafeModeState.off;
  String? _safeReason;
  int _strikes = 0;
  bool _autoSafe = true;
  RuntimeFailure? _failure;
  DateTime? _healthyAt;
  int _generation = 0;

  Process? _process;
  int? _port;
  bool _stopping = false;
  bool _starting = false;
  Timer? _healthTimer;

  @override
  Stream<RuntimeEvent> get events => _events.stream;

  // ---------------------------------------------------------------------------
  // 位置

  Future<Directory> _supportDir() async {
    final cached = _support;
    if (cached != null) return cached;
    // getApplicationSupportDirectory() 在 macOS 上已经是
    // ~/Library/Application Support/<bundle id>/，不用再套一层。
    final base = _appSupportOverride != null
        ? Directory(_appSupportOverride)
        : await getApplicationSupportDirectory();
    await base.create(recursive: true);
    _support = base;
    return base;
  }

  Future<Directory> _runtimeDir() async => Directory('${(await _supportDir()).path}/runtime');
  Future<Directory> _homeDir() async => Directory('${(await _runtimeDir()).path}/home');
  Future<Directory> _dshHome() async => Directory('${(await _homeDir()).path}/.dsh');

  Future<File> _stateFile() async => File('${(await _supportDir()).path}/runtime-state.json');

  // ---------------------------------------------------------------------------
  // 状态

  @override
  Future<RuntimeStatus> status() async {
    if (_official) {
      final found = await _probeOfficial();
      return RuntimeStatus.fromMap(_officialStatusMap(found));
    }
    await _loadInstalledState();
    return RuntimeStatus.fromMap(_statusMap());
  }

  /// 切换「内置运行时 / 官方 DSH」。
  Future<void> setOfficial(bool value) async {
    if (_official == value) return;
    _official = value;
    _officialAt = null;
    _officialNow = null;
    if (value) {
      final found = await _probeOfficial(force: true);
      _emitMap(_officialStatusMap(found));
    } else {
      await _loadInstalledState();
      _emitMap(_statusMap());
    }
  }

  /// 官方 DSH 的本地端口 / 密钥可能每次启动都变，缓存几秒即可。
  Future<OfficialDsh?> _probeOfficial({bool force = false}) async {
    final at = _officialAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(seconds: 3)) {
      return _officialNow;
    }
    final found = await findOfficialDsh();
    _officialAt = DateTime.now();
    _officialNow = found;
    if (found != null) {
      _log('[dsh-go] official DSH at ${found.authority}${found.version == null ? '' : ' (v${found.version})'}');
    }
    return found;
  }

  Map<String, Object?> _officialStatusMap(OfficialDsh? found) => <String, Object?>{
    'phase': found == null ? RuntimePhase.error.name : RuntimePhase.running.name,
    'abi': 'arm64',
    'bundledVersion': found?.version,
    'installedVersion': found?.version,
    'dshVersion': found?.version,
    'nodeVersion': null,
    'baseUrl': found?.baseUri.toString(),
    'token': null,
    'cookie': found == null
        ? null
        : <String, Object?>{
            'name': found.cookie.name,
            'value': found.cookie.value,
            'authority': found.cookie.authority,
            'expiresAt': found.cookie.expiresAt?.millisecondsSinceEpoch,
          },
    'official': true,
    'error': found == null ? _officialNotRunning : null,
    'mode': 'normal',
    'safeState': 'off',
    'safeReason': null,
    'strikes': 0,
    'autoSafe': true,
    'failure': null,
    'mainFailure': null,
    'healthyAt': null,
    'networkBlocked': false,
    'networkBlockedAt': null,
    'directEngineEnabled': false,
    'directEngineAvailable': false,
    'directEngineActive': false,
    'directEngineFallbackReason': null,
    'currentExecutionMode': 'official',
    'launchSelectedMode': 'official',
    'launchSpawned': found != null,
    'launchFailureReason': found == null ? _officialNotRunning : null,
    'tidyingFiles': false,
  };

  void _emitMap(Map<String, Object?> map) {
    if (!_events.isClosed) _events.add(RuntimeStatusEvent(RuntimeStatus.fromMap(map)));
  }

  Map<String, Object?> _statusMap() => <String, Object?>{
    'phase': _phase.name,
    'abi': 'arm64',
    'bundledVersion': _bundledVersion,
    'installedVersion': _installedVersion,
    'dshVersion': _dshVersion,
    'nodeVersion': _nodeVersion,
    'baseUrl': _baseUrl,
    'token': _token,
    'managedSkillGeneration': _generation > 0 ? _generation : null,
    'error': _error,
    'mode': _mode.name,
    'safeState': _safeState.name,
    'safeReason': _safeReason,
    'strikes': _strikes,
    'autoSafe': _autoSafe,
    'failure': _failure == null ? null : _failureToMap(_failure!),
    'mainFailure': null,
    'healthyAt': _healthyAt?.millisecondsSinceEpoch,
    'networkBlocked': false,
    'networkBlockedAt': null,
    'directEngineEnabled': false,
    'directEngineAvailable': false,
    'directEngineActive': false,
    'directEngineFallbackReason': null,
    'currentExecutionMode': 'native',
    'launchSelectedMode': 'native',
    'launchSpawned': _process != null,
    'launchFailureReason': null,
    'tidyingFiles': false,
  };

  static Map<String, Object?> _failureToMap(RuntimeFailure f) => <String, Object?>{
    'kind': f.kind.name,
    'at': f.at.millisecondsSinceEpoch,
    'exitCode': f.exitCode,
    'safeMode': f.safeMode,
    'summary': f.summary,
    'requiredRows': f.requiredRows,
    'suspects': f.suspects,
    'recent': f.recent,
    'diagnostics': f.diagnostics,
    'upSeconds': f.upSeconds,
  };

  void _emit([RuntimeEvent? event]) {
    if (!_events.isClosed) {
      _events.add(event ?? RuntimeStatusEvent(RuntimeStatus.fromMap(_statusMap())));
    }
  }

  void _log(String line, [String stream = 'stdout']) {
    if (line.isEmpty) return;
    _logs.add(line);
    if (_logs.length > 1000) _logs.removeRange(0, _logs.length - 1000);
    _emit(RuntimeLogEvent(line, stream));
  }

  void _progress(String step, int done, int total) =>
      _emit(RuntimeProgressEvent(step: step, done: done, total: total));

  void _notice(String text) => _emit(RuntimeNoticeEvent(text));

  // ---------------------------------------------------------------------------
  // manifest / 已安装状态

  Future<Map<String, Object?>?> _loadManifest() async {
    if (_manifest != null) return _manifest;
    try {
      final raw = await rootBundle.loadString(_manifestAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map) _manifest = decoded.cast<String, Object?>();
      _bundledVersion = (_manifest?['runtimeVersion'] as String?) ?? 'macos';
      _dshVersion = _manifest?['dshVersion'] as String?;
      _nodeVersion = _manifest?['nodeVersion'] as String?;
    } catch (_) {
      _manifest = null;
    }
    return _manifest;
  }

  Future<void> _loadInstalledState() async {
    await _loadManifest();
    final file = await _stateFile();
    final dir = await _runtimeDir();
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _installedVersion = decoded['installedVersion'] as String?;
          _dshVersion = (decoded['dshVersion'] as String?) ?? _dshVersion;
          _nodeVersion = (decoded['nodeVersion'] as String?) ?? _nodeVersion;
          _safeState = SafeStateStateNames.parse(decoded['safeState'] as String?);
          _safeReason = decoded['safeReason'] as String?;
          _strikes = (decoded['strikes'] as num?)?.toInt() ?? 0;
          _autoSafe = decoded['autoSafe'] != false;
          _mode = EngineMode.parse(decoded['mode']);
          _generation = (decoded['managedSkillGeneration'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {
      // 坏掉的 state 文件按未安装处理。
    }
    final nodeBin = File('${dir.path}/node/bin/node');
    if (_installedVersion == null && await nodeBin.exists()) {
      // 没有 state 文件但运行时在：当作已装，版本取 manifest。
      _installedVersion = _bundledVersion;
    }
    if (_installedVersion != null && !await nodeBin.exists()) {
      _installedVersion = null;
    }
    if (_process != null) {
      _phase = RuntimePhase.running;
    } else if (_installedVersion != null) {
      _phase = RuntimePhase.installed;
    } else {
      _phase = RuntimePhase.notInstalled;
    }
  }

  Future<void> _saveState() async {
    try {
      final file = await _stateFile();
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'installedVersion': _installedVersion,
          'dshVersion': _dshVersion,
          'nodeVersion': _nodeVersion,
          'safeState': _safeState.name,
          'safeReason': _safeReason,
          'strikes': _strikes,
          'autoSafe': _autoSafe,
          'mode': _mode.name,
          'managedSkillGeneration': _generation,
        }),
      );
    } catch (_) {
      // 状态存不下来不影响运行。
    }
  }

  // ---------------------------------------------------------------------------
  // 安装

  @override
  Future<void> install({bool dropKept = false}) async {
    if (_official) {
      throw PlatformException(code: 'official', message: '官方 DSH 由它自己管理，不需要安装运行环境。');
    }
    if (_phase == RuntimePhase.installing) {
      throw PlatformException(code: 'install_busy');
    }
    final manifest = await _loadManifest();
    if (manifest == null) {
      _phase = RuntimePhase.error;
      _error = 'install failed: runtime manifest missing ($_manifestAsset)';
      _emit();
      throw PlatformException(code: 'install_failed', message: _error);
    }
    _phase = RuntimePhase.installing;
    _error = null;
    _emit();
    final runtimeDir = await _runtimeDir();
    final staging = Directory('${runtimeDir.path}.staging');
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
      await staging.create(recursive: true);

      final archive = File('${staging.path}/runtime.tar.gz');
      await _materializeArchive(manifest, archive);
      final expected = (manifest['archiveSha256'] as String?) ?? '';
      if (expected.isNotEmpty) {
        _log('[dsh-go] verifying runtime archive');
        final digest = await sha256.bind(archive.openRead()).first;
        if (digest.toString() != expected) {
          throw StateError('archive checksum mismatch');
        }
      }

      final unpack = Directory('${staging.path}/unpack');
      await unpack.create(recursive: true);
      final total = (manifest['uncompressedBytes'] as num?)?.toInt() ?? 0;
      _progress('extract', 0, total);
      final tar = await Process.start('/usr/bin/tar', <String>['-xzf', archive.path, '-C', unpack.path]);
      tar.stdout.transform(utf8.decoder).listen((s) => _log(s, 'stdout'));
      tar.stderr.transform(utf8.decoder).listen((s) => _log(s, 'stderr'));
      Timer? poll;
      if (total > 0) {
        poll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
          try {
            final du = await Process.run('/usr/bin/du', <String>['-sk', unpack.path]);
            final kb = int.tryParse((du.stdout as String).trim().split(RegExp(r'\s+')).first) ?? 0;
            _progress('extract', (kb * 1024).clamp(0, total), total);
          } catch (_) {}
        });
      }
      final code = await tar.exitCode;
      poll?.cancel();
      if (code != 0) throw StateError('tar exited with $code');

      // tar 里有一个顶层目录 runtime/；把它挪成正式的 runtime/。
      final root = Directory('${unpack.path}/runtime');
      final source = await root.exists() ? root : unpack;
      if (await runtimeDir.exists()) await runtimeDir.delete(recursive: true);
      await _moveDirectory(source, runtimeDir);
      _progress('extract', total, total);

      await _ensureRuntimeLayout(runtimeDir, manifest);
      _installedVersion = _bundledVersion ?? (manifest['runtimeVersion'] as String?) ?? 'macos';
      _dshVersion = manifest['dshVersion'] as String?;
      _nodeVersion = manifest['nodeVersion'] as String?;
      _phase = RuntimePhase.installed;
      _safeState = SafeModeState.off;
      _strikes = 0;
      await _saveState();
      _emit();
      _log('[dsh-go] runtime $_installedVersion installed');
    } catch (error) {
      _phase = RuntimePhase.error;
      _error = 'install failed: $error';
      _emit();
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {}
      throw PlatformException(code: 'install_failed', message: '$error');
    }
  }

  /// Flutter 把 asset 放在 .app 里的固定位置；直接拷文件，避免把 200 MB 读进内存。
  Future<File?> _bundledArchiveOnDisk() async {
    if (!Platform.isMacOS) return null;
    final exe = File(Platform.resolvedExecutable).parent.parent; // Contents/MacOS/.. -> Contents
    final candidates = <String>[
      '${exe.path}/Frameworks/App.framework/Resources/flutter_assets/$_archiveAsset',
      '${exe.path}/Resources/flutter_assets/$_archiveAsset',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
  }

  Future<void> _materializeArchive(Map<String, Object?> manifest, File target) async {
    // 优先用 App 里带的包；没有就看 manifest 有没有下载地址。
    final onDisk = await _bundledArchiveOnDisk();
    if (onDisk != null) {
      await onDisk.copy(target.path);
      _log('[dsh-go] using bundled runtime archive (${((await target.length()) / 1048576).toStringAsFixed(1)} MiB)');
      return;
    }
    try {
      final data = await rootBundle.load(_archiveAsset);
      await target.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      _log('[dsh-go] using bundled runtime archive (${(data.lengthInBytes / 1048576).toStringAsFixed(1)} MiB)');
      return;
    } catch (_) {
      // 没有内置包。
    }
    final url = manifest['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('no runtime archive bundled and no download url in manifest');
    }
    _log('[dsh-go] downloading runtime from $url');
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) throw StateError('HTTP ${response.statusCode}');
      final total = response.contentLength > 0 ? response.contentLength : 0;
      var done = 0;
      final sink = target.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        done += chunk.length;
        _progress('download', done, total);
      }
      await sink.close();
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _moveDirectory(Directory from, Directory to) async {
    final code = await Process.run('/bin/mv', <String>[from.path, to.path]);
    if (code.exitCode != 0) {
      throw StateError('mv failed: ${code.stderr}');
    }
  }

  /// 补齐启动需要、但 tar 里可能没有的目录与安全模式 overlay。
  Future<void> _ensureRuntimeLayout(Directory runtimeDir, Map<String, Object?> manifest) async {
    final home = Directory('${runtimeDir.path}/home');
    final dshHome = Directory('${home.path}/.dsh');
    await dshHome.create(recursive: true);
    final etc = Directory('${runtimeDir.path}/etc/dsh-app');
    await etc.create(recursive: true);
    // overlay 里是绝对路径（bridge 在运行时的安装位置），所以每次启动前重写。
    final patch = File('${etc.path}/dsh-web.patch.yml');
    await patch.writeAsString(macLaunchOverlay(runtimeDir.path));
    final safe = File('${etc.path}/safe-mode.patch.yml');
    await safe.writeAsString(macSafeOverlay);
  }

  // ---------------------------------------------------------------------------
  // 启动 / 停止

  @override
  Future<void> start({
    Map<String, String> env = const {},
    bool phoneStorage = false,
    EngineMode? mode,
    bool visualReplies = true,
  }) async {
    if (_official) {
      final found = await _probeOfficial(force: true);
      if (found == null) {
        _emitMap(_officialStatusMap(null));
        throw PlatformException(code: 'official_not_running', message: _officialNotRunning);
      }
      _emitMap(_officialStatusMap(found));
      return;
    }
    if (_starting || _process != null) return;
    await _loadInstalledState();
    if (_installedVersion == null) {
      throw PlatformException(code: 'not_installed', message: 'runtime is not installed');
    }
    if (mode != null) _mode = mode;
    _starting = true;
    _phase = RuntimePhase.starting;
    _error = null;
    _failure = null;
    _baseUrl = null;
    _token = null;
    _emit();
    try {
      final manifest = await _loadManifest();
      if (manifest == null) throw StateError('runtime manifest missing');
      final runtimeDir = await _runtimeDir();
      final home = await _homeDir();
      await home.create(recursive: true);
      // 上次退出没能收掉的引擎（崩溃、强制退出）不能占着端口。
      await _reapStale(runtimeDir);
      final port = await _pickPort();
      _port = port;

      final safe = _safeState != SafeModeState.off;
      final argv = _expandArgs(manifest, runtimeDir: runtimeDir.path, home: home.path, port: port, safe: safe);
      final launchEnv = <String, String>{
        'HOME': home.path,
        'DSH_HOME': '${home.path}/.dsh',
        'USER': Platform.environment['USER'] ?? 'dsh',
        'LOGNAME': Platform.environment['LOGNAME'] ?? 'dsh',
        'PATH': '${runtimeDir.path}/node/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
        'TMPDIR': '${(await _supportDir()).path}/tmp',
        'LANG': 'en_US.UTF-8',
        'TERM': 'xterm-256color',
        'NODE_OPTIONS': '--dns-result-order=ipv4first',
        ...env,
      };
      if (safe) launchEnv['DSH_APP_SAFE_MODE'] = '1';
      final manifestEnv = (manifest['launchEnv'] as Map?) ?? const {};
      for (final entry in manifestEnv.entries) {
        final value = '${entry.value}'
            .replaceAll('{RUNTIME}', runtimeDir.path)
            .replaceAll('{HOME}', home.path);
        launchEnv['${entry.key}'] = value;
      }
      await Directory(launchEnv['TMPDIR']!).create(recursive: true);
      await Process.run('/usr/bin/xattr', <String>['-dr', 'com.apple.quarantine', runtimeDir.path]);

      _log('[dsh-go] starting ${argv.join(' ')}');
      final process = await Process.start(argv.first, argv.sublist(1), environment: launchEnv, workingDirectory: home.path);
      _process = process;
      try {
        await File('${runtimeDir.path}/tmp/dsh-web.pid').writeAsString('${process.pid}');
      } catch (_) {}
      _starting = false;
      _stopping = false;

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) => _onLine(line, 'stdout'),
        onError: (Object e) => _log('[dsh-go] stdout: $e', 'stderr'),
      );
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) => _onLine(line, 'stderr'),
        onError: (Object e) => _log('[dsh-go] stderr: $e', 'stderr'),
      );
      unawaited(process.exitCode.then((code) => _onExit(code)));
    } catch (error) {
      _starting = false;
      _process = null;
      _phase = RuntimePhase.error;
      _error = 'start failed: $error';
      _emit();
      rethrow;
    }
  }

  List<String> _expandArgs(
    Map<String, Object?> manifest, {
    required String runtimeDir,
    required String home,
    required int port,
    required bool safe,
  }) => expandMacLaunchArgs(
    manifest,
    runtimeDir: runtimeDir,
    home: home,
    port: port,
    safe: safe,
  );

  void _onLine(String line, String stream) {
    _log(line, stream);
    if (_token != null) return;
    final match = _tokenLine.firstMatch(line);
    if (match == null) return;
    _baseUrl = match.group(1);
    _token = match.group(2);
    unawaited(_becameReady());
  }

  Future<void> _becameReady() async {
    final port = _port;
    if (port == null) return;
    for (var i = 0; i < 60; i++) {
      try {
        final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 500));
        socket.destroy();
        _healthyAt = DateTime.now();
        _phase = RuntimePhase.running;
        _strikes = 0;
        if (_safeState == SafeModeState.probation) _safeState = SafeModeState.off;
        _emit();
        await _saveState();
        _healthTimer?.cancel();
        _healthTimer = Timer(const Duration(milliseconds: _healthyMs), () {
          _log('[dsh-go] engine stayed healthy for ${_healthyMs ~/ 1000}s');
        });
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    _log('[dsh-go] token seen but port $port never accepted connections', 'stderr');
    await _fail(kind: FailureKind.startupFailed, exitCode: 0, summary: 'engine did not listen');
  }

  Future<void> _onExit(int code) async {
    final expected = _stopping;
    _process = null;
    _healthTimer?.cancel();
    final upSeconds = _healthyAt == null ? null : DateTime.now().difference(_healthyAt!).inSeconds;
    _baseUrl = null;
    _token = null;
    if (expected) {
      _phase = RuntimePhase.installed;
      _emit();
      await _saveState();
      return;
    }
    _log('[dsh-go] engine exited ($code)', 'stderr');
    final kind = switch (code) {
      0 => FailureKind.killed,
      _ => upSeconds != null && upSeconds < 120 ? FailureKind.crashedEarly : FailureKind.crashedLate,
    };
    await _fail(kind: kind, exitCode: code, summary: 'engine exited with $code', upSeconds: upSeconds);
  }

  Future<void> _fail({
    required FailureKind kind,
    required int exitCode,
    String? summary,
    int? upSeconds,
  }) async {
    final safeMode = _safeState != SafeModeState.off;
    final failure = RuntimeFailure(
      kind: kind,
      at: DateTime.now(),
      exitCode: exitCode,
      safeMode: safeMode,
      summary: summary,
      recent: _logs.length > 40 ? _logs.sublist(_logs.length - 40) : List<String>.of(_logs),
      upSeconds: upSeconds,
    );
    _failure = failure;
    _phase = RuntimePhase.error;
    _error = 'engine failed: ${summary ?? kind.name}';
    if (!safeMode && kind.counts) {
      _strikes += 1;
      if (_safeState == SafeModeState.probation) {
        _safeState = SafeModeState.on;
        _safeReason = 'probation';
        _notice('正常模式还是起不来，已回到安全模式。');
      } else if (_strikes >= 2 && _autoSafe) {
        _safeState = SafeModeState.on;
        _safeReason = 'auto';
        _notice('DSH 连续两次启动失败，已用安全模式启动。你的对话都在。');
      }
    }
    _emit();
    await _saveState();
  }

  @override
  Future<void> stop() async {
    if (_official) {
      // 官方 DSH 由它自己的 App 管理，这里只是断开连接。
      _log('[dsh-go] official DSH keeps running; quit DeepSeek Harness to stop it');
      return;
    }
    final process = _process;
    if (process == null) {
      if (_phase != RuntimePhase.notInstalled) _phase = RuntimePhase.installed;
      _emit();
      return;
    }
    _stopping = true;
    _phase = RuntimePhase.stopping;
    _emit();
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _log('[dsh-go] engine did not stop in 8s, killing it', 'stderr');
      process.kill(ProcessSignal.sigkill);
    }
    _stopping = false;
    await _clearPidFile();
  }

  /// 收掉上一次运行残留的引擎（pid 文件里的进程仍是本运行时启动的才动）。
  Future<void> _reapStale(Directory runtimeDir) async {
    final file = File('${runtimeDir.path}/tmp/dsh-web.pid');
    try {
      if (!await file.exists()) return;
      final pid = int.tryParse((await file.readAsString()).trim());
      if (pid == null || pid <= 0) {
        await file.delete();
        return;
      }
      final ps = await Process.run('/bin/ps', <String>['-o', 'command=', '-p', '$pid']);
      final command = ps.exitCode == 0 ? '${ps.stdout}' : '';
      if (command.contains(runtimeDir.path)) {
        await Process.run('/bin/kill', <String>['-TERM', '$pid']);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await Process.run('/bin/kill', <String>['-KILL', '$pid']);
        _log('[dsh-go] reaped stale engine (pid $pid)', 'stderr');
      }
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清不掉就算了，下一次启动还会再试。
    }
  }

  Future<void> _clearPidFile() async {
    try {
      final file = File('${(await _runtimeDir()).path}/tmp/dsh-web.pid');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<int> _pickPort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  // ---------------------------------------------------------------------------
  // 其余契约

  @override
  Future<List<String>> logs({int lines = 500}) async {
    if (_logs.length <= lines) return List<String>.of(_logs);
    return _logs.sublist(_logs.length - lines);
  }

  @override
  Future<void> reset({ResetKeep keep = const ResetKeep()}) async {
    await stop();
    final runtimeDir = await _runtimeDir();
    Directory? stash;
    try {
      final home = Directory('${runtimeDir.path}/home/.dsh');
      if (await home.exists() && (keep.uiAndSkills || keep.pluginsAndSettings)) {
        stash = Directory('${(await _supportDir()).path}/kept');
        if (await stash.exists()) await stash.delete(recursive: true);
        await stash.create(recursive: true);
        if (keep.uiAndSkills) {
          for (final name in <String>['dsh-go', 'skills']) {
            final from = Directory('${home.path}/$name');
            if (await from.exists()) await _copyDirectory(from, Directory('${stash.path}/$name'));
          }
        }
        if (keep.pluginsAndSettings) {
          for (final name in <String>['cordis.patch.yml', '.env', 'plugins', 'package.json']) {
            final from = File('${home.path}/$name');
            final dir = Directory('${home.path}/$name');
            if (await from.exists()) {
              await File('${stash.path}/$name').writeAsBytes(await from.readAsBytes());
            } else if (await dir.exists()) {
              await _copyDirectory(dir, Directory('${stash.path}/$name'));
            }
          }
        }
      }
      if (await runtimeDir.exists()) await runtimeDir.delete(recursive: true);
      final staging = Directory('${runtimeDir.path}.staging');
      if (await staging.exists()) await staging.delete(recursive: true);
    } finally {
      _installedVersion = null;
      _phase = RuntimePhase.notInstalled;
      _baseUrl = null;
      _token = null;
      _failure = null;
      _error = null;
      _strikes = 0;
      _safeState = SafeModeState.off;
      await _saveState();
      _emit();
    }
    if (stash != null && await stash.exists()) {
      try {
        // 放回去：先装好运行时，下一次 install 前恢复。
        // reset 之后 App 会自动重装，这里把保留下来的东西挪到 support 下等 install 取。
        final kept = Directory('${(await _supportDir()).path}/pending-keep');
        if (await kept.exists()) await kept.delete(recursive: true);
        await stash.rename(kept.path);
      } catch (_) {}
    }
  }

  Future<void> _copyDirectory(Directory from, Directory to) async {
    await to.create(recursive: true);
    final result = await Process.run('/bin/cp', <String>['-R', '${from.path}/.', to.path]);
    if (result.exitCode != 0) throw StateError('cp failed: ${result.stderr}');
  }

  @override
  Future<ManagedSkillInstallResponse> installManagedSkill({
    required String requestId,
    required String expectedRoot,
    required String expectedToken,
    required int? expectedGeneration,
    required String name,
    required Map<String, String> files,
  }) async {
    if (expectedToken != 'macos') {
      return const ManagedSkillInstallResponse(result: null, current: false, reason: 'stale');
    }
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty) {
      return const ManagedSkillInstallResponse(result: null, current: false, reason: 'invalid');
    }
    final dir = Directory('${(await _dshHome()).path}/skills/$safe');
    await dir.create(recursive: true);
    for (final entry in files.entries) {
      final path = '${dir.path}/${entry.key}';
      final target = File(path);
      await target.parent.create(recursive: true);
      await target.writeAsString(entry.value);
    }
    _generation += 1;
    await _saveState();
    return ManagedSkillInstallResponse(result: dir.path, current: true);
  }

  @override
  Future<void> cancelManagedSkill(String requestId) async {}

  @override
  Future<LastKnownGood> lastKnownGood() async => const LastKnownGood.none();

  @override
  Future<LastKnownGood> restoreLastKnownGood() async => const LastKnownGood.none();

  @override
  Future<List<SafeHazard>> safePreflight() async => const <SafeHazard>[];

  @override
  Future<List<String>> moveAside(List<String> paths) async => const <String>[];

  @override
  Future<void> clearFailure() async {
    _failure = null;
    if (_phase == RuntimePhase.error) _phase = _installedVersion == null ? RuntimePhase.notInstalled : RuntimePhase.installed;
    _emit();
  }

  @override
  Future<void> setAutoSafe(bool enabled) async {
    _autoSafe = enabled;
    await _saveState();
    _emit();
  }

  @override
  Future<void> setDirectEngine(bool enabled) async {
    // macOS 没有 PRoot / 直启之分，这个开关原样保留但不生效。
  }

  @override
  Future<List<String>> failureLog() async =>
      _failure?.recent ?? (_logs.length > 40 ? _logs.sublist(_logs.length - 40) : List<String>.of(_logs));

  @override
  Future<StorageAccess> storageStatus() async => const StorageAccess(granted: false, permission: false, legacy: false);

  @override
  Future<StorageAccess> requestStorage() async => const StorageAccess(granted: false, permission: false, legacy: false);

  @override
  Future<bool> openAllFilesAccess() async => false;

  @override
  Future<bool?> batteryExempt() async => null;

  @override
  Future<bool?> requestBatteryExempt() async => null;

  @override
  Future<BackgroundSettingsInfo?> backgroundSettings() async => null;

  @override
  Future<String?> openBackgroundSettings() async => null;

  @override
  Future<String?> openVendorSettings(String vendorSwitch) async => null;

  @override
  Future<bool?> networkMetered() async => false;
}

/// 存进 state 文件的安全模式状态名。
abstract final class SafeStateStateNames {
  static SafeModeState parse(String? wire) => switch (wire) {
    'on' => SafeModeState.on,
    'probation' => SafeModeState.probation,
    _ => SafeModeState.off,
  };
}

/// 展开运行时清单里的启动 argv（`{RUNTIME}` / `{HOME}` / `{PORT}` / `{DSH_PROFILE_ARGS}`）。
///
/// 单独拿出来是为了能在 `flutter test` 里验证，不需要真的装一份运行时。
List<String> expandMacLaunchArgs(
  Map<String, Object?> manifest, {
  required String runtimeDir,
  required String home,
  required int port,
  required bool safe,
}) {
  final launch = manifest['launch'];
  final raw = (launch is Map ? launch['argv'] as List? : null)?.cast<Object?>() ?? const <Object?>[];
  final args = <String>[];
  for (final item in raw) {
    var value = '$item'
        .replaceAll('{RUNTIME}', runtimeDir)
        .replaceAll('{HOME}', home)
        .replaceAll('{PORT}', '$port');
    if (value == '{DSH_PROFILE_ARGS}') {
      args.addAll(
        safe
            ? <String>[
                '--profile',
                'dsh-app-safe',
                '--from-default-profile',
                'web',
                '--patch',
                '$runtimeDir/etc/dsh-app/safe-mode.patch.yml',
              ]
            : <String>['web', '--patch', '$runtimeDir/etc/dsh-app/dsh-web.patch.yml'],
      );
      continue;
    }
    if (value == '{SAFE_PATCH}') {
      value = '$runtimeDir/etc/dsh-app/safe-mode.patch.yml';
    }
    args.add(value);
  }
  return args;
}

/// 正常启动的 overlay：插件安装走镜像 + 官方源，并加载 dsh-go-bridge。
String macLaunchOverlay(String runtimeDir) => '''
# dsh-app: overlay for `dsh web`, written by DSH Go for macOS (edits here do not survive a restart).
- id: plugin-manager
  config:
    fallbackRegistries:
      - https://registry.npmmirror.com
      - https://registry.npmjs.org
- insert:
    - id: dsh-go-bridge
      name: $runtimeDir/bridge/lib/index.js
''';

/// 安全模式 overlay：不加载插件管理。
const String macSafeOverlay = '''
# dsh-app safe mode overlay (written by DSH Go for macOS on every safe start).
- id: plugin-manager
  disabled: true
- id: tool-plugin-manager
  disabled: true
''';


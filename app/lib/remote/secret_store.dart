import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where remote-access secrets live: SSH passwords and private keys, relay
/// device credentials. Never SharedPreferences.
///
/// Injectable so state and tests can swap in [MemorySecretStore], and so the
/// relay package (`dsh_remote`) can be handed the same store.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore-backed storage (flutter_secure_storage).
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Every key is namespaced so remote secrets never collide with app settings.
  static String _k(String key) => 'remote.$key';

  @override
  Future<String?> read(String key) => _storage.read(key: _k(key));

  @override
  Future<void> write(String key, String value) => _storage.write(key: _k(key), value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: _k(key));
}

/// In-memory store for tests and previews.
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}


/// macOS fallback for ad-hoc builds: the Keychain needs entitlements this
/// unsigned bundle does not carry (errSecMissingEntitlement, -34018), so SSH
/// secrets go to a 0600 JSON file under Application Support instead.
class FileSecretStore implements SecretStore {
  FileSecretStore({String? path}) : path = path ?? _defaultPath();

  final String path;
  Map<String, String>? _cache;

  static String _defaultPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/Library/Application Support/io.github.billwgong.dshgomac/remote-secrets.json';
  }

  Future<Map<String, String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final file = File(path);
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          return _cache = {
            for (final entry in raw.entries) '${entry.key}': '${entry.value}',
          };
        }
      }
    } catch (_) {}
    return _cache = <String, String>{};
  }

  Future<void> _save(Map<String, String> values) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(values), flush: true);
    await Process.run('/bin/chmod', <String>['600', temp.path]);
    await temp.rename(file.path);
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async {
    final values = await _load();
    values[key] = value;
    await _save(values);
  }

  @override
  Future<void> delete(String key) async {
    final values = await _load();
    values.remove(key);
    await _save(values);
  }
}

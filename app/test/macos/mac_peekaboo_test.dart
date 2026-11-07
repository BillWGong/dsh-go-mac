import 'package:dsh_app/macos/mac_peekaboo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Peekaboo status maps permissions and helper fields', () {
    final status = MacPeekabooStatus.fromMap({
      'supported': true,
      'osVersion': '15.6',
      'enabled': true,
      'helperReady': true,
      'helperVersion': '4.9.8',
      'permissions': {'screenRecording': true, 'accessibility': false, 'eventSynthesizing': true},
    });
    expect(status.supported, isTrue);
    expect(status.osVersion, '15.6');
    expect(status.enabled, isTrue);
    expect(status.helperVersion, '4.9.8');
    expect(status.screenRecording, isTrue);
    expect(status.accessibility, isFalse);
    expect(status.eventSynthesizing, isTrue);
    expect(status.permissionsReady, isFalse);
  });

  test('old macOS reports not supported and no permissions', () {
    final status = MacPeekabooStatus.fromMap({'supported': false, 'osVersion': '14.7'});
    expect(status.supported, isFalse);
    expect(status.enabled, isFalse);
    expect(status.permissionsReady, isFalse);
  });
}

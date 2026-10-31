import 'package:dsh_app/state/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('copyWith 保留 Return 发送开关', () {
    const base = AppSettings();
    expect(base.sendOnEnter, isFalse);
    final on = base.copyWith(sendOnEnter: true);
    expect(on.sendOnEnter, isTrue);
    // 其他字段不受影响
    expect(on.foldCompletedTurns, base.foldCompletedTurns);
    expect(on.copyWith(themeMode: base.themeMode).sendOnEnter, isTrue);
  });
}

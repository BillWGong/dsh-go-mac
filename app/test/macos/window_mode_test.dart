import 'package:dsh_app/macos/window_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('窗口版式只认 phone / adaptive', () {
    expect(MacWindowMode.parse('phone'), MacWindowMode.phone);
    expect(MacWindowMode.parse('adaptive'), MacWindowMode.adaptive);
    expect(MacWindowMode.parse('tablet'), isNull);
    expect(MacWindowMode.parse(null), isNull);
  });

  test('默认是自适应', () {
    expect(MacWindow.mode.value, MacWindowMode.adaptive);
  });
}

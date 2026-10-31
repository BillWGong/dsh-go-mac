import 'package:dsh_app/macos/window_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() async => MacWindow.reset());

  testWidgets('手机版式把内容收成 470pt 宽的一条', (tester) async {
    MacWindow.mode.value = MacWindowMode.phone;
    await tester.pumpWidget(
      MaterialApp(
        home: MacWindowFrame(
          child: Builder(
            builder: (context) {
              return Center(
                child: Text('content', key: const Key('probe')),
              );
            },
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byKey(const Key('probe')));
    expect(size.width, lessThanOrEqualTo(MacWindowMode.phoneWidth));
  });

  testWidgets('自适应版式原样铺开', (tester) async {
    MacWindow.mode.value = MacWindowMode.adaptive;
    await tester.pumpWidget(
      MaterialApp(
        home: MacWindowFrame(
          child: SizedBox.expand(child: Text('wide', key: const Key('probe'))),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('probe'))).width, greaterThan(500));
  });
}

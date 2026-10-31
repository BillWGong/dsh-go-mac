// macOS 窗口与顶栏的合并：隐藏原生标题栏文字，让 Flutter 内容铺到顶部，
// 交通灯浮在内容上；Dart 侧按这里给的常量给顶栏留安全区并支持拖拽。

import 'package:flutter/services.dart';

class MacWindowChrome {
  static const _channel = MethodChannel('dsh/window');

  /// 交通灯占用的左侧宽度（含边距），顶栏控件从这里开始。
  static const trafficLightsInset = 78.0;

  /// 全尺寸内容下，交通灯那条的高度；二级页面用它把内容压下来。
  static const titleBarHeight = 28.0;

  /// 顶栏空白处按下时拖动窗口。原生用 performDrag(with:) 接管。
  static Future<void> drag() async {
    try {
      await _channel.invokeMethod<void>('drag');
    } catch (_) {}
  }
}

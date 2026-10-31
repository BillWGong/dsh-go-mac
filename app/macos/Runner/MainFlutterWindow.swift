import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 桌面窗口：标题、最小尺寸、居中；版式（自适应 / 手机）由 MacHost 决定。
    self.title = "DSH Go Mac"
    self.minSize = NSSize(width: 860, height: 620)
    self.setContentSize(NSSize(width: 1180, height: 820))
    self.center()
    self.isReleasedWhenClosed = false
    self.tabbingMode = .disallowed

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacHost.shared.attach(window: self, controller: flutterViewController)
    MacMenuBar.shared.attach(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

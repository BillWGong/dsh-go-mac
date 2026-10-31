import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 菜单栏按 Mac 习惯重排（原版 Android 没有菜单）。
    dshProbe("applicationDidFinishLaunching")
    MacHost.shared.installMenu()
    super.applicationDidFinishLaunching(notification)
    DispatchQueue.main.async {
      if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
         let controller = window.contentViewController as? FlutterViewController {
        MacMenuBar.shared.attach(messenger: controller.engine.binaryMessenger)
      } else {
        dshProbe("menubar: no FlutterViewController at launch")
      }
      // 主窗口被关掉时（桌宠窗口让 App 继续活着）把文档窗口拉回来。
      if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) {
        dshProbe("main window visible=\(window.isVisible)")
        if !window.isVisible { window.makeKeyAndOrderFront(nil) }
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// `open dshgo://…`、Finder 里「用 DSH Go 打开」、以及分享扩展交给本 App 的 URL。
  override func application(_ application: NSApplication, open urls: [URL]) {
    MacHost.shared.handle(urls: urls)
  }
}

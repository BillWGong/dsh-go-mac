import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    dshProbe("step A: didFinishLaunching")
    MacHost.shared.installMenu()
    dshProbe("step B: menu installed")
    super.applicationDidFinishLaunching(notification)
    dshProbe("step C: super returned")
    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
       let controller = window.contentViewController as? FlutterViewController {
      dshProbe("step D: window found, visible=\(window.isVisible)")
      MacMenuBar.shared.attach(messenger: controller.engine.binaryMessenger)
      if !window.isVisible { window.makeKeyAndOrderFront(nil) }
    } else {
      dshProbe("step D: no MainFlutterWindow")
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
           let controller = window.contentViewController as? FlutterViewController {
          dshProbe("step D2: window found late")
          MacMenuBar.shared.attach(messenger: controller.engine.binaryMessenger)
        } else {
          dshProbe("step D2: still no window")
        }
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

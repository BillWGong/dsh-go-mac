import Cocoa
import FlutterMacOS

/// 窗口版式：自适应 Mac 布局，或手机竖屏。
enum MacWindowMode: String {
  case adaptive
  case phone
}

/// macOS 平台层的主入口：窗口、菜单、深链，以及几个轻量通道。
///
/// 原版里这些由 Kotlin 提供（`dsh/app`、`dsh/links`、`dsh/shortcuts` …）。Mac 上没有
/// Android 的 Activity/Intent，于是这里换成 NSWindow / NSMenu / NSAppleEvent。
final class MacHost: NSObject {
  static let shared = MacHost()

  private static let modeKey = "dsh.windowMode"

  private weak var window: NSWindow?
  private var windowChannel: FlutterMethodChannel?
  private var windowEvents: FlutterEventChannel?
  private var linkChannel: FlutterMethodChannel?
  private var eventSink: FlutterEventSink?

  private var pendingLinks: [String] = []
  private var linksReady = false

  private(set) var mode: MacWindowMode = .adaptive
  private var adaptiveFrame: NSRect?
  private var phoneMenuItem: NSMenuItem?

  // MARK: - 生命周期

  /// 由 MainFlutterWindow 在创建 FlutterViewController 之后调用。
  func attach(window: NSWindow, controller: FlutterViewController) {
    self.window = window
    let messenger = controller.engine.binaryMessenger

    let appChannel = FlutterMethodChannel(name: "dsh/app", binaryMessenger: messenger)
    appChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleApp(call, result: result)
    }

    windowChannel = FlutterMethodChannel(name: "dsh/window", binaryMessenger: messenger)
    windowChannel?.setMethodCallHandler { [weak self] call, result in
      self?.handleWindow(call, result: result)
    }
    windowEvents = FlutterEventChannel(name: "dsh/window/events", binaryMessenger: messenger)
    windowEvents?.setStreamHandler(WindowStreamHandler(host: self))

    linkChannel = FlutterMethodChannel(name: "dsh/links", binaryMessenger: messenger)
    linkChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "ready":
        self.linksReady = true
        let held = self.pendingLinks
        self.pendingLinks.removeAll()
        result(true)
        for uri in held { self.deliver(uri: uri) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    MacNotify.shared.attach(messenger: messenger)
    MacFiles.shared.attach(messenger: messenger)
    MacVoice.shared.attach(messenger: messenger)
    MacPetOverlay.shared.attach(messenger: messenger)
    MacStubs.attach(messenger: messenger)

    mode = MacWindowMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .adaptive
    DispatchQueue.main.async { [weak self] in
      self?.applyMode(self?.mode ?? .adaptive, persist: false)
    }
  }

  // MARK: - 通道

  private func handleApp(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTimeZoneId":
      result(TimeZone.current.identifier)
    case "bringToFront":
      NSApp.activate(ignoringOtherApps: true)
      window?.makeKeyAndOrderFront(nil)
      result(nil)
    case "osVersion":
      result(ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleWindow(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getMode":
      result(mode.rawValue)
    case "setMode":
      guard let args = call.arguments as? [String: Any],
            let raw = args["mode"] as? String,
            let next = MacWindowMode(rawValue: raw) else {
        return result(FlutterError(code: "bad_mode", message: nil, details: nil))
      }
      applyMode(next, persist: true)
      result(nil)
    case "showAbout":
      NSApp.orderFrontStandardAboutPanel(nil)
      result(nil)
    case "toggleFullScreen":
      window?.toggleFullScreen(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 版式

  func applyMode(_ next: MacWindowMode, persist: Bool) {
    guard let window else {
      mode = next
      return
    }
    if next == mode, persist == false {
      // 首次启动：按存的版式摆窗口。
    }
    if mode == .adaptive && next == .phone {
      adaptiveFrame = window.frame
    }
    mode = next
    if persist {
      UserDefaults.standard.set(next.rawValue, forKey: Self.modeKey)
    }
    phoneMenuItem?.state = next == .phone ? .on : .off
    emit(["type": "mode", "mode": next.rawValue])

    switch next {
    case .phone:
      window.minSize = NSSize(width: 380, height: 600)
      window.maxSize = NSSize(width: 620, height: 1600)
      let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
      let height = min(900, visible.height - 80)
      var frame = window.frame
      frame.size = NSSize(width: 440, height: height)
      frame.origin = NSPoint(x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2)
      window.setFrame(frame, display: true, animate: true)
    case .adaptive:
      window.minSize = NSSize(width: 860, height: 620)
      window.maxSize = NSSize(width: 10000, height: 10000)
      if let stored = adaptiveFrame, stored.width >= 860, stored.height >= 620 {
        window.setFrame(stored, display: true, animate: true)
      } else {
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let width = min(1180, visible.width - 80)
        let height = min(820, visible.height - 80)
        let frame = NSRect(
          x: visible.midX - width / 2,
          y: visible.midY - height / 2,
          width: width,
          height: height
        )
        window.setFrame(frame, display: true, animate: true)
      }
    }
  }

  private func emit(_ event: [String: Any]) {
    eventSink?(event)
  }

  fileprivate func setSink(_ sink: FlutterEventSink?) {
    eventSink = sink
    if sink != nil {
      sink?(["type": "mode", "mode": mode.rawValue])
    }
  }

  // MARK: - 深链

  /// `dshgo://…`，或 Finder 里用本 App 打开的文件。
  func deliver(uri: String) {
    if linksReady, let channel = linkChannel {
      channel.invokeMethod("link", arguments: ["uri": uri])
    } else {
      pendingLinks.append(uri)
    }
  }

  func handle(urls: [URL]) {
    for url in urls {
      deliver(uri: url.absoluteString)
    }
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  // MARK: - 菜单

  func installMenu() {
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "DSH Go Mac"
    let main = NSMenu()

    // 应用
    let appItem = NSMenuItem()
    main.addItem(appItem)
    let appMenu = NSMenu()
    appItem.submenu = appMenu
    appMenu.addItem(withTitle: "关于 \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    let phone = NSMenuItem(title: "手机版式", action: #selector(togglePhoneMode(_:)), keyEquivalent: "m")
    phone.keyEquivalentModifierMask = [.command, .shift]
    phone.target = self
    phone.state = mode == .phone ? .on : .off
    phoneMenuItem = phone
    appMenu.addItem(phone)
    appMenu.addItem(.separator())
    let services = NSMenuItem(title: "服务", action: nil, keyEquivalent: "")
    let servicesMenu = NSMenu()
    services.submenu = servicesMenu
    appMenu.addItem(services)
    NSApp.servicesMenu = servicesMenu
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "隐藏 \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    let hideOthers = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    appMenu.addItem(hideOthers)
    appMenu.addItem(withTitle: "全部显示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "退出 \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    // 显示
    let viewItem = NSMenuItem()
    main.addItem(viewItem)
    let view = NSMenu(title: "显示")
    viewItem.submenu = view
    let fullScreen = NSMenuItem(title: "进入全屏", action: #selector(toggleFullScreenAction(_:)), keyEquivalent: "f")
    fullScreen.keyEquivalentModifierMask = [.command, .control]
    fullScreen.target = self
    view.addItem(fullScreen)

    // 窗口
    let windowItem = NSMenuItem()
    main.addItem(windowItem)
    let windowMenu = NSMenu(title: "窗口")
    windowItem.submenu = windowMenu
    windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "缩放", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    NSApp.windowsMenu = windowMenu

    // 帮助
    let helpItem = NSMenuItem()
    main.addItem(helpItem)
    let help = NSMenu(title: "帮助")
    helpItem.submenu = help
    let guide = NSMenuItem(title: "DSH Go 使用指南", action: #selector(openGuide(_:)), keyEquivalent: "?")
    guide.keyEquivalentModifierMask = [.command]
    guide.target = self
    help.addItem(guide)
    NSApp.helpMenu = help

    NSApp.mainMenu = main
  }

  @objc private func togglePhoneMode(_ sender: NSMenuItem) {
    applyMode(mode == .phone ? .adaptive : .phone, persist: true)
  }

  @objc private func toggleFullScreenAction(_ sender: NSMenuItem) {
    window?.toggleFullScreen(nil)
  }

  @objc private func openGuide(_ sender: NSMenuItem) {
    if let url = URL(string: "https://forum.dshtui.com") {
      NSWorkspace.shared.open(url)
    }
  }
}

/// `dsh/window/events`
private final class WindowStreamHandler: NSObject, FlutterStreamHandler {
  weak var host: MacHost?
  init(host: MacHost) { self.host = host }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    host?.setSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    host?.setSink(nil)
    return nil
  }
}

/// Mac 上不适用、但 Dart 会调到的通道：给一个明确的答复，而不是 MissingPluginException。
enum MacStubs {
  static func attach(messenger: FlutterBinaryMessenger) {
    register("dsh/launch", messenger) { call, result in
      switch call.method {
      case "begin", "snapshot":
        result(nil) // 没有 Android 12 的系统启动画面
      case "reveal":
        result(false)
      default:
        result(nil)
      }
    }
    register("dsh/launch_clip", messenger) { _, result in result(nil) }
    register("dsh/share", messenger) { call, result in
      switch call.method {
      case "ready": result(true)
      default: result(nil)
      }
    }
    register("dsh/shortcuts", messenger) { call, result in
      // 桌面图标快捷方式在 Mac 上不存在；记住最近对话只对 Android 桌面有用。
      switch call.method {
      case "ready": result(true)
      default: result(nil)
      }
    }
    register("dsh/launcher_icon", messenger) { _, result in result(nil) }
    register("dsh/picture_shortcut", messenger) { _, result in result(nil) }
    register("dsh/dynamic_color", messenger) { _, result in result(nil) }
    register("dsh/performance", messenger) { _, result in result(nil) }
    register("dsh/islands", messenger) { call, result in
      switch call.method {
      case "device": result(["sdk": 0, "manufacturer": "Apple", "model": "Mac"])
      case "appPss": result(0)
      default: result(nil)
      }
    }
    register("dsh/native-media", messenger) { call, result in
      switch call.method {
      case "capabilities":
        result(["audio": false, "video": false, "overlay": false, "speech": false])
      default:
        result(nil)
      }
    }
    register("dsh/native-files", messenger) { call, result in
      switch call.method {
      case "capabilities":
        result(["files": false])
      default:
        result(nil)
      }
    }
    register("dsh/diagnostics", messenger) { call, result in
      switch call.method {
      case "info":
        result([
          "app": ["version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"],
          "device": ["model": "Mac", "os": "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"],
          "manifest": [:],
          "voice": [:],
        ])
      default:
        result(nil)
      }
    }
    register("dsh/usage", messenger) { call, result in
      switch call.method {
      case "device":
        result([String: Any]())
      default:
        result(nil)
      }
    }
    register("dsh/update", messenger) { call, result in
      switch call.method {
      case "info":
        result([
          "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
          "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
        ])
      case "canRequestInstalls":
        result(false)
      case "openInstallPermission":
        result(false)
      case "openWithSystem":
        if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
          NSWorkspace.shared.open(URL(fileURLWithPath: path))
          result(true)
        } else {
          result(false)
        }
      default:
        result(nil)
      }
    }
  }

  private static func register(
    _ name: String,
    _ messenger: FlutterBinaryMessenger,
    _ handler: @escaping (FlutterMethodCall, @escaping FlutterResult) -> Void
  ) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler(handler)
  }
}

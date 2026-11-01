import Cocoa
import FlutterMacOS
import QuartzCore

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

    window.isMovableByWindowBackground = false
    applyChrome(for: mode)
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
    case "drag":
      if let event = NSApp.currentEvent {
        window?.performDrag(with: event)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 版式

  /// 自适应：内容铺满、标题隐藏，顶栏和交通灯合成一条。
  /// 竖屏：恢复系统标题栏占位（标题仍隐藏），任何内容都不会压到交通灯。
  private func applyChrome(for mode: MacWindowMode) {
    guard let window else { return }
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    if mode == .phone {
      window.styleMask.remove(.fullSizeContentView)
    } else {
      window.styleMask.insert(.fullSizeContentView)
    }
  }

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
    applyChrome(for: next)
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
    let phone = NSMenuItem(title: "竖屏版式", action: #selector(togglePhoneMode(_:)), keyEquivalent: "m")
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


// MARK: - 菜单栏 Live Activity


/// 状态栏胶囊：引擎/回合/待批准的直接映射，点开是 popover。
/// Dart 通过 `dsh/menubar` 推 `state`，这里通过 `action` 回动作。
final class MacMenuBar: NSObject {
  static let shared = MacMenuBar()

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var panel: MacMenuBarPanel?
  private var channel: FlutterMethodChannel?
  private var state: [String: Any] = [:]

  func attach(messenger: FlutterBinaryMessenger) {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = item.button {
      button.image = NSImage(systemSymbolName: "water.waves", accessibilityDescription: "DSH Go")
      button.imagePosition = .imageLeading
      button.target = self
      button.action = #selector(togglePopover)
      button.sendAction(on: [.leftMouseUp])
    }
    statusItem = item

    let panel = MacMenuBarPanel()
    panel.onAction = { [weak self] name in self?.perform(name) }
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = panel
    self.panel = panel
    self.popover = popover

    let channel = FlutterMethodChannel(name: "dsh/menubar", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "state", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.apply(args)
      result(nil)
    }
    self.channel = channel
  }

  private func apply(_ args: [String: Any]) {
    state = args
    guard let button = statusItem?.button else { return }
    let running = args["running"] as? Bool ?? false
    let pending = args["pending"] as? Int ?? 0
    let done = args["done"] as? Bool ?? false
    let elapsed = args["elapsed"] as? Int ?? 0
    let host = args["host"] as? String ?? ""

    let symbol: String
    var tint: NSColor?
    if running {
      symbol = "waveform"
      tint = .controlAccentColor
    } else if pending > 0 {
      symbol = "exclamationmark.circle.fill"
      tint = .systemOrange
    } else if done {
      symbol = "checkmark.circle.fill"
      tint = .systemGreen
    } else {
      symbol = "water.waves"
    }
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DSH Go")
    button.contentTintColor = tint
    button.title = running ? " \(elapsed)s" : (pending > 0 ? " \(pending)" : "")
    statusItem?.length = button.title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
    button.toolTip = running ? "\(host) · 回合进行中 \(elapsed)s" : (pending > 0 ? "\(host) · \(pending) 个待批准" : host)

    updatePulse(pending > 0)
    panel?.apply(args)
  }

  private func updatePulse(_ on: Bool) {
    guard let button = statusItem?.button else { return }
    button.wantsLayer = true
    guard let layer = button.layer else { return }
    if on && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      if layer.animation(forKey: "pulse") != nil { return }
      let animation = CABasicAnimation(keyPath: "opacity")
      animation.fromValue = 1.0
      animation.toValue = 0.45
      animation.duration = 0.9
      animation.autoreverses = true
      animation.repeatCount = .infinity
      layer.add(animation, forKey: "pulse")
    } else {
      layer.removeAnimation(forKey: "pulse")
      layer.opacity = 1
    }
  }

  @objc private func togglePopover() {
    guard let popover, let button = statusItem?.button else { return }
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    panel?.apply(state)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func perform(_ name: String) {
    popover?.performClose(nil)
    showWindow()
    if name != "openWindow" {
      channel?.invokeMethod("action", arguments: name)
    }
  }

  private func showWindow() {
    NSApp.activate(ignoringOtherApps: true)
    let window = NSApp.windows.first { $0 is MainFlutterWindow }
      ?? NSApp.windows.first { $0.contentViewController is FlutterViewController }
    window?.makeKeyAndOrderFront(nil)
  }
}

private final class MacMenuBarPanel: NSViewController {
  var onAction: ((String) -> Void)?

  private let stack = NSStackView()

  override func loadView() {
    let root = NSView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 9
    stack.translatesAutoresizingMaskIntoConstraints = false
    root.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
      stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
      stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
      stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
      root.widthAnchor.constraint(equalToConstant: 272),
    ])
    view = root
  }

  func apply(_ state: [String: Any]) {
    let running = state["running"] as? Bool ?? false
    let pending = state["pending"] as? Int ?? 0
    let elapsed = state["elapsed"] as? Int ?? 0
    let host = state["host"] as? String ?? "DSH Go Mac"
    let kind = state["pendingKind"] as? String

    stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

    stack.addArrangedSubview(label("DSH Go Mac", size: 13, weight: .semibold))
    stack.addArrangedSubview(label(host, size: 11, color: .secondaryLabelColor))

    let status = running
      ? "回合进行中 · \(elapsed)s"
      : pending > 0
      ? "\(pending) 个待批准"
      : "空闲"
    stack.addArrangedSubview(label(status, size: 12, color: running ? .controlAccentColor : (pending > 0 ? .systemOrange : .secondaryLabelColor)))

    if pending > 0 {
      let kindText = kind == "approval" ? "批准" : (kind == "plan" ? "计划" : (kind == "question" ? "提问" : "确认"))
      stack.addArrangedSubview(button("去处理\(kindText)", action: "openPending", prominent: true))
    }

    let row = NSStackView()
    row.orientation = .horizontal
    row.spacing = 8
    if running {
      row.addArrangedSubview(button("停止", action: "stop", prominent: false))
    }
    row.addArrangedSubview(button("新建对话", action: "newChat", prominent: false))
    row.addArrangedSubview(button("打开窗口", action: "openWindow", prominent: false))
    stack.addArrangedSubview(row)

    preferredContentSize = NSSize(width: 272, height: stack.fittingSize.height + 24)
    view.layoutSubtreeIfNeeded()
  }

  private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = NSFont.systemFont(ofSize: size, weight: weight)
    field.textColor = color
    return field
  }

  private func button(_ title: String, action: String, prominent: Bool) -> NSButton {
    let button = NSButton(title: title, target: self, action: #selector(tapped(_:)))
    button.identifier = NSUserInterfaceItemIdentifier(action)
    button.bezelStyle = .rounded
    button.controlSize = .small
    if prominent {
      button.contentTintColor = .systemOrange
    }
    return button
  }

  @objc private func tapped(_ sender: NSButton) {
    guard let name = sender.identifier?.rawValue else { return }
    onAction?(name)
  }
}

import Cocoa
import FlutterMacOS

/// 「App 外显示」：一个浮在桌面上的宠物窗口（`dsh/pet_overlay`）。
///
/// Android 版是 SYSTEM_ALERT_WINDOW 悬浮窗；macOS 用无边框、置顶、不抢焦点的 NSPanel。
/// 状态和气泡完全由 Dart 推过来（`push`），这里只负责画、拖动、右键菜单和「今天不再显示」。
///
/// 与原版的差异（记在 docs/macos/README.md）：气泡上的「允许一次 / 拒绝」不在浮窗里回答，
/// 点气泡会把 App 带到前台；动画按状态每 1.2–2.5 秒换一帧，不做逐像素的桌宠物理。
final class MacPetOverlay: NSObject {
  static let shared = MacPetOverlay()

  private static let enabledKey = "dsh.pet.enabled"
  private static let alwaysKey = "dsh.pet.alwaysShow"
  private static let snoozeKey = "dsh.pet.snoozedUntil"
  private static let frameKey = "dsh.pet.frame"

  private var channel: FlutterMethodChannel?
  private var panel: PetPanel?
  private var view: PetView?
  private var timer: Timer?

  private var enabled = UserDefaults.standard.bool(forKey: MacPetOverlay.enabledKey)
  private var alwaysShow = UserDefaults.standard.bool(forKey: MacPetOverlay.alwaysKey)
  private var snoozedUntil = UserDefaults.standard.object(forKey: MacPetOverlay.snoozeKey) as? Date
  private var state: [String: Any] = [:]
  private var lastStatus = ""

  func attach(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dsh/pet_overlay", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    // 1 秒一次：到点结束「今天不再显示」，并跟随 App 前后台。
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.refresh()
    }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.refresh() }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.refresh() }
  }

  // MARK: - 通道

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "push":
      guard let args = call.arguments as? [String: Any] else { return result(nil) }
      state = args
      view?.apply(args)
      refresh()
      result(nil)
    case "status", "permissionStatus":
      result(statusMap())
    case "setEnabled":
      let args = call.arguments as? [String: Any] ?? [:]
      enabled = args["enabled"] as? Bool ?? false
      UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
      refresh()
      notifyStatus()
      result(statusMap())
    case "setAlwaysShow":
      let args = call.arguments as? [String: Any] ?? [:]
      alwaysShow = args["on"] as? Bool ?? false
      UserDefaults.standard.set(alwaysShow, forKey: Self.alwaysKey)
      refresh()
      notifyStatus()
      result(statusMap())
    case "unsnooze":
      snoozedUntil = nil
      UserDefaults.standard.removeObject(forKey: Self.snoozeKey)
      refresh()
      notifyStatus()
      result(statusMap())
    case "requestPermission":
      // 桌面浮窗不需要系统授权。
      result(true)
    case "openAppDetails":
      result(false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func statusMap() -> [String: Any] {
    [
      "enabled": enabled,
      "alwaysShow": alwaysShow,
      "permission": "granted",
      "snoozed": isSnoozed,
      "showing": panel?.isVisible ?? false,
      "sdk": 0,
      "manufacturer": "Apple",
    ]
  }

  private func notifyStatus() {
    let signature = "\(enabled)|\(alwaysShow)|\(isSnoozed)|\(panel?.isVisible ?? false)"
    guard signature != lastStatus else { return }
    lastStatus = signature
    channel?.invokeMethod("status", arguments: statusMap())
  }

  // MARK: - 显示

  private var isSnoozed: Bool {
    guard let until = snoozedUntil else { return false }
    return until > Date()
  }

  private var packId: String {
    let raw = state["packId"] as? String ?? ""
    return raw.isEmpty || raw == "none" ? "deepy-whale" : raw
  }

  private var active: Bool { state["active"] as? Bool ?? false }

  /// 原版规则：一直显示 → 总在；否则只在该露脸的时候（有任务/气泡）且 App 不在前台。
  private func shouldShow() -> Bool {
    guard enabled, !isSnoozed else { return false }
    if alwaysShow { return true }
    return active && !NSApp.isActive
  }

  private func refresh() {
    if isSnoozed, let until = snoozedUntil, until <= Date() {
      snoozedUntil = nil
      UserDefaults.standard.removeObject(forKey: Self.snoozeKey)
    }
    let show = shouldShow()
    if show {
      showPanel()
    } else {
      panel?.orderOut(nil)
    }
    notifyStatus()
  }

  private func showPanel() {
    let panel = panel ?? makePanel()
    self.panel = panel
    // 不要在这里 apply(state)：refresh 每秒跑一次，会不停重置动画计时器。
    if !panel.isVisible {
      panel.orderFrontRegardless()
    }
  }

  private func makePanel() -> PetPanel {
    let frame = savedFrame() ?? defaultFrame()
    let panel = PetPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    panel.isReleasedWhenClosed = false

    let view = PetView(host: self)
    view.frame = NSRect(origin: .zero, size: frame.size)
    panel.contentView = view
    self.view = view
    view.apply(state)
    return panel
  }

  private func defaultFrame() -> NSRect {
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let size = view?.desiredSize ?? NSSize(width: 180, height: 170)
    return NSRect(x: screen.maxX - size.width - 40, y: screen.minY + 40, width: size.width, height: size.height)
  }

  private func savedFrame() -> NSRect? {
    guard let raw = UserDefaults.standard.string(forKey: Self.frameKey) else { return nil }
    let frame = NSRectFromString(raw)
    return frame.width > 40 && frame.height > 40 ? frame : nil
  }

  fileprivate func saveFrame() {
    guard let panel else { return }
    UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: Self.frameKey)
  }

  /// 气泡让窗口变宽/变高时，保持左下角不动（宠物脚底不跳）。
  fileprivate func resize(to size: NSSize) {
    guard let panel, size != panel.frame.size else { return }
    var frame = panel.frame
    frame.origin.y += frame.height - size.height
    frame.size = size
    panel.setFrame(frame, display: true)
  }

  // MARK: - 菜单

  fileprivate func showMenu(at point: NSPoint) {
    let menu = NSMenu()
    let settings = NSMenuItem(title: "宠物设置", action: #selector(openSettings), keyEquivalent: "")
    settings.target = self
    menu.addItem(settings)
    let snooze = NSMenuItem(title: "今天不再显示", action: #selector(snoozeForToday), keyEquivalent: "")
    snooze.target = self
    menu.addItem(snooze)
    menu.addItem(.separator())
    let off = NSMenuItem(title: "关闭 App 外显示", action: #selector(turnOff), keyEquivalent: "")
    off.target = self
    menu.addItem(off)
    menu.popUp(positioning: nil, at: point, in: view)
  }

  @objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    channel?.invokeMethod("openSettings", arguments: nil)
  }

  @objc private func snoozeForToday() {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: Date())
    snoozedUntil = calendar.date(byAdding: .day, value: 1, to: start)
    UserDefaults.standard.set(snoozedUntil, forKey: Self.snoozeKey)
    refresh()
  }

  @objc private func turnOff() {
    enabled = false
    UserDefaults.standard.set(false, forKey: Self.enabledKey)
    refresh()
    notifyStatus()
  }

  fileprivate func openApp() {
    NSApp.activate(ignoringOtherApps: true)
    channel?.invokeMethod("openSettings", arguments: nil)
  }
}

/// 无边框浮窗：点击不激活 App，但可以拖动。
final class PetPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// 宠物本体 + 气泡。
final class PetView: NSView {
  private weak var host: MacPetOverlay?
  private var sprite = NSImage()
  private var spriteName = "idle"
  private var bubbleText: String?
  private var bubbleIsAsk = false
  private var frameTimer: Timer?
  private var frameIndex = 0
  private var dragOrigin: NSPoint = .zero
  private var dragged = false
  private var lastClick: Date = .distantPast

  init(host: MacPetOverlay) {
    self.host = host
    super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 170))
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  required init?(coder: NSCoder) { fatalError() }

  /// 图片目标高度（和原版 small / medium / large 的观感对齐）。
  private var bodyHeight: CGFloat {
    switch spriteName {
    case _ where spriteName.isEmpty: return 120
    default: return CGFloat(bodyHeights[stateSize] ?? 120)
    }
  }

  private var stateSize = "medium"
  private var packId = "deepy-whale"
  private let bodyHeights: [String: Double] = ["small": 92, "medium": 120, "large": 152]

  var desiredSize: NSSize {
    let body = desiredBodySize()
    let bubble = bubbleLayout(maxWidth: 300).size
    let width = max(body.width, bubble.width) + 24
    let height = body.height + (bubble.height > 0 ? bubble.height + 10 : 0) + 12
    return NSSize(width: max(96, width), height: max(96, height))
  }

  private func desiredBodySize() -> NSSize {
    guard sprite.size.width > 0, sprite.size.height > 0 else { return NSSize(width: 120, height: 120) }
    let scale = bodyHeight / sprite.size.height
    return NSSize(width: max(40, sprite.size.width * scale), height: bodyHeight)
  }

  // MARK: - 状态

  func apply(_ state: [String: Any]) {
    stateSize = state["size"] as? String ?? "medium"
    let next = Self.spriteName(for: state)
    packId = state["packId"] as? String ?? "deepy-whale"
    let pack = packId
    let showed = next != spriteName
    spriteName = next
    if showed || sprite.size.width == 0 {
      loadSprite(pack: pack, name: next)
    }
    if let bubble = state["bubble"] as? [String: Any], state["quiet"] as? Bool != true {
      let text = bubble["text"] as? String
      let title = bubble["title"] as? String
      let count = bubble["count"] as? Int ?? 1
      var line = ""
      if count > 1 {
        line = "\(count) 个对话 · \(text ?? "")"
      } else if let title, !title.isEmpty {
        line = "\(title) · \(text ?? "")"
      } else {
        line = text ?? ""
      }
      if let detail = bubble["detail"] as? String, !detail.isEmpty {
        line += "\n\(detail)"
      }
      bubbleText = line.isEmpty ? nil : line
      bubbleIsAsk = bubble["ask"] != nil
    } else {
      bubbleText = nil
      bubbleIsAsk = false
    }
    scheduleFrames(reduceMotion: state["reduceMotion"] as? Bool ?? false)
    let size = desiredSize
    host?.resize(to: size)
    frame = NSRect(origin: frame.origin, size: size)
    needsDisplay = true
  }

  private static func spriteName(for state: [String: Any]) -> String {
    switch state["state"] as? String {
    case "thinking": return "thinking"
    case "working":
      let tier = state["tier"] as? Int ?? 0
      return tier >= 3 ? "conducting" : "typing"
    case "juggling": return "react-double"
    case "sweeping": return "building"
    case "notification", "attention": return "notification"
    case "error": return "error"
    case "carrying": return "carrying"
    case "sleeping": return "sleeping"
    case "waking": return "waking"
    default: return "idle"
    }
  }

  private func loadSprite(pack: String, name: String) {
    let candidates = [name, "idle"]
    for file in candidates {
      if let image = Self.loadImage(pack: pack, name: file) {
        sprite = image
        return
      }
    }
    sprite = NSImage()
    if let image = NSImage(contentsOfFile: Self.assetRoot + "/assets/pets/deepy-whale/idle.png") {
      sprite = image
    }
  }

  private static var assetRoot: String {
    let executable = Bundle.main.executablePath ?? ""
    let contents = (executable as NSString).deletingLastPathComponent as NSString
    let root = contents.deletingLastPathComponent
    return root + "/Frameworks/App.framework/Resources/flutter_assets"
  }

  private static func loadImage(pack: String, name: String) -> NSImage? {
    let path = "\(assetRoot)/assets/pets/\(pack)/\(name).png"
    return NSImage(contentsOfFile: path)
  }

  /// 状态内的轻微动画：idle 三帧轮换，working 在打字/搭建/指挥之间轮换。
  private func scheduleFrames(reduceMotion: Bool) {
    frameTimer?.invalidate()
    frameTimer = nil
    guard !reduceMotion else { return }
    let sequence: [String]
    switch spriteName {
    case "idle": sequence = ["idle", "idle-look", "idle-spout"]
    case "typing": sequence = ["typing", "building", "conducting"]
    default: return
    }
    frameIndex = 0
    frameTimer = Timer.scheduledTimer(withTimeInterval: sequence == ["idle", "idle-look", "idle-spout"] ? 2.6 : 1.4,
                                      repeats: true) { [weak self] _ in
      guard let self, sequence.count > 1 else { return }
      self.frameIndex = (self.frameIndex + 1) % sequence.count
      if let image = Self.loadImage(pack: self.packId, name: sequence[self.frameIndex]) {
        self.sprite = image
        self.needsDisplay = true
      }
    }
  }

  // MARK: - 画

  override func draw(_ dirtyRect: NSRect) {
    let body = desiredBodySize()
    let bubble = bubbleLayout(maxWidth: max(120, bounds.width - 24))
    var y = bounds.height - 6
    if bubble.size.height > 0 {
      let rect = NSRect(x: (bounds.width - bubble.size.width) / 2, y: y - bubble.size.height,
                        width: bubble.size.width, height: bubble.size.height)
      NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
      let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
      path.fill()
      NSColor.separatorColor.setStroke()
      path.lineWidth = 1
      path.stroke()
      let inset = rect.insetBy(dx: 9, dy: 7)
      bubble.draw(inset)
      y = rect.minY - 6
    }
    let bodyRect = NSRect(x: (bounds.width - body.width) / 2, y: y - body.height,
                          width: body.width, height: body.height)
    sprite.draw(in: bodyRect, from: .zero, operation: .sourceOver, fraction: 1)
    _ = bodyRect
  }

  private func bubbleLayout(maxWidth: CGFloat) -> (size: NSSize, draw: (NSRect) -> Void) {
    guard let text = bubbleText, !text.isEmpty else { return (.zero, { _ in }) }
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12),
      .foregroundColor: NSColor.labelColor,
      .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let bound = attributed.boundingRect(
      with: NSSize(width: maxWidth - 18, height: 200),
      options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let size = NSSize(width: min(maxWidth, ceil(bound.width) + 18), height: ceil(bound.height) + 14)
    let draw: (NSRect) -> Void = { rect in
      attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
    return (size, draw)
  }

  // MARK: - 鼠标

  override func mouseDown(with event: NSEvent) {
    dragged = false
    dragOrigin = event.locationInWindow
    let now = Date()
    if now.timeIntervalSince(lastClick) < 0.4 {
      host?.openApp()
    }
    lastClick = now
  }

  override func mouseDragged(with event: NSEvent) {
    dragged = true
    guard let window = window else { return }
    var origin = window.frame.origin
    origin.x += event.deltaX
    origin.y -= event.deltaY
    window.setFrameOrigin(origin)
  }

  override func mouseUp(with event: NSEvent) {
    host?.saveFrame()
  }

  override func rightMouseDown(with event: NSEvent) {
    host?.showMenu(at: convert(event.locationInWindow, from: nil))
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    host?.showMenu(at: convert(event.locationInWindow, from: nil))
    return nil
  }
}

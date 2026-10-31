import Cocoa
import FlutterMacOS

/// 「App 外显示」：一个浮在桌面上的宠物窗口（`dsh/pet_overlay`）。
///
/// Android 版是 SYSTEM_ALERT_WINDOW 悬浮窗；macOS 用无边框、置顶、不抢焦点的 NSPanel。
/// 状态和气泡完全由 Dart 推过来（`push`），这里只负责画、拖动、右键菜单和「今天不再显示」。
///
/// 素材是序列帧图集（`assets/pets/<pack>/<anim>.png` + `pack.json` 的 frames/cols），
/// 不是单张图：按 pack 的 frameW/H、cols 和每帧 ms 裁切播放；窗口按动画 contentBox
/// 缩放到约 72pt 高的可见内容。
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

  /// 打开开关就显示；「今天不再显示」或关掉才隐藏。桌面上一直有宠物才符合直觉。
  private func shouldShow() -> Bool { enabled && !isSnoozed }

  private func refresh() {
    if isSnoozed, let until = snoozedUntil, until <= Date() {
      snoozedUntil = nil
      UserDefaults.standard.removeObject(forKey: Self.snoozeKey)
    }
    if shouldShow() {
      showPanel()
    } else {
      panel?.orderOut(nil)
    }
    notifyStatus()
  }

  private func showPanel() {
    let panel = panel ?? makePanel()
    self.panel = panel
    if !panel.isVisible {
      panel.orderFrontRegardless()
    }
  }

  private func makePanel() -> PetPanel {
    let frame = Self.clamped(savedFrame() ?? defaultFrame())
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
    return NSRect(
      x: screen.maxX - size.width - 40,
      y: screen.minY + 40,
      width: size.width,
      height: size.height
    )
  }

  private func savedFrame() -> NSRect? {
    guard let raw = UserDefaults.standard.string(forKey: Self.frameKey) else { return nil }
    let frame = NSRectFromString(raw)
    return frame.width > 40 && frame.height > 40 ? frame : nil
  }

  /// 不让宠物跑到屏幕外（之前保存的坐标可能来自更大/不同的屏幕）。
  static func clamped(_ frame: NSRect) -> NSRect {
    let screen = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
    guard let screen else { return frame }
    var f = frame
    f.size.width = min(f.width, screen.width - 16)
    f.size.height = min(f.height, screen.height - 16)
    f.origin.x = min(max(f.minX, screen.minX + 8), screen.maxX - f.width - 8)
    f.origin.y = min(max(f.minY, screen.minY + 8), screen.maxY - f.height - 8)
    return f
  }

  fileprivate func saveFrame() {
    guard let panel else { return }
    let clamped = Self.clamped(panel.frame)
    if clamped != panel.frame { panel.setFrame(clamped, display: true) }
    UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: Self.frameKey)
  }

  /// 气泡让窗口变宽/变高时，保持左下角不动（宠物脚底不跳），并夹在屏幕内。
  fileprivate func resize(to size: NSSize) {
    guard let panel, size != panel.frame.size else { return }
    var frame = panel.frame
    frame.origin.y += frame.height - size.height
    frame.size = size
    panel.setFrame(Self.clamped(frame), display: true)
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

// MARK: - 图集

/// 一个动画：图集里 frameW×frameH 的格子，按 frames 的下标和时长播放。
struct PetAnimation {
  let sheet: String
  let frameW: CGFloat
  let frameH: CGFloat
  let cols: Int
  let box: CGRect
  let loop: Bool
  let frames: [(index: Int, ms: Int)]
}

/// `assets/pets/<id>/pack.json` 里画宠物需要的部分。
struct PetPack {
  let id: String
  /// pack 的画布高度（canvas.h）：图集帧高 / 画布高 = 每个画布单位占多少像素。
  let canvasH: CGFloat
  let animations: [String: PetAnimation]
  let states: [String: String]
  let tiers: [String: [(min: Int, anim: String)]]

  static func load(id: String) -> PetPack? {
    let path = "\(assetRoot)/assets/pets/\(id)/pack.json"
    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    var animations: [String: PetAnimation] = [:]
    if let raw = json["animations"] as? [String: Any] {
      for (name, value) in raw {
        guard let anim = value as? [String: Any],
              let sheet = anim["sheet"] as? String,
              let frameW = (anim["frameW"] as? NSNumber)?.doubleValue,
              let frameH = (anim["frameH"] as? NSNumber)?.doubleValue,
              let cols = (anim["cols"] as? NSNumber)?.intValue else { continue }
        let box = anim["box"] as? [String: Any] ?? [:]
        let rect = CGRect(
          x: (box["x"] as? NSNumber)?.doubleValue ?? 0,
          y: (box["y"] as? NSNumber)?.doubleValue ?? 0,
          width: (box["w"] as? NSNumber)?.doubleValue ?? frameW,
          height: (box["h"] as? NSNumber)?.doubleValue ?? frameH
        )
        let frames: [(Int, Int)] = (anim["frames"] as? [[String: Any]] ?? []).compactMap { frame in
          guard let index = (frame["i"] as? NSNumber)?.intValue else { return nil }
          return (index, (frame["ms"] as? NSNumber)?.intValue ?? 50)
        }
        animations[name] = PetAnimation(
          sheet: sheet,
          frameW: frameW,
          frameH: frameH,
          cols: cols,
          box: rect,
          loop: anim["loop"] as? Bool ?? true,
          frames: frames.isEmpty ? [(0, 100)] : frames
        )
      }
    }
    let states = json["states"] as? [String: String] ?? [:]
    var tiers: [String: [(Int, String)]] = [:]
    if let raw = json["tiers"] as? [String: Any] {
      for (state, value) in raw {
        let list = (value as? [[String: Any]] ?? []).compactMap { entry -> (Int, String)? in
          guard let min = (entry["min"] as? NSNumber)?.intValue,
                let anim = entry["anim"] as? String else { return nil }
          return (min, anim)
        }
        tiers[state] = list
      }
    }
    let canvas = json["canvas"] as? [String: Any] ?? [:]
    let canvasH = (canvas["h"] as? NSNumber)?.doubleValue ?? 52
    return PetPack(id: id, canvasH: canvasH, animations: animations, states: states, tiers: tiers)
  }

  /// pack.json 所在的 flutter_assets 根目录。
  static var assetRoot: String {
    let executable = Bundle.main.executablePath ?? ""
    let contents = (executable as NSString).deletingLastPathComponent as NSString
    let root = contents.deletingLastPathComponent
    return root + "/Frameworks/App.framework/Resources/flutter_assets"
  }

  /// 当前状态该播哪个动画（含 working / juggling 的档位）。
  func animationName(state name: String, tier: Int) -> String {
    if let options = tiers[name] {
      for option in options where tier >= option.min { return option.anim }
    }
    return states[name] ?? states["idle"] ?? "idle"
  }
}

// MARK: - 视图

/// 宠物本体 + 气泡。
final class PetView: NSView {
  private weak var host: MacPetOverlay?

  private var pack: PetPack?
  private var packId = ""
  private var canvasH: CGFloat = 52
  private var animation: PetAnimation?
  private var animationName = ""
  private var frames: [NSImage] = []
  private var frameIndex = 0
  private var frameTimer: Timer?
  private var bubbleText: String?

  private var stateSize = "medium"
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

  /// 可见内容的目标高度：桌面上比手机大一点，但仍然是小宠物。
  private var contentHeight: CGFloat {
    switch stateSize {
    case "small": return 32
    case "large": return 58
    default: return 44
    }
  }

  private var frameScale: CGFloat {
    guard let animation, animation.box.height > 0 else { return 1 }
    // box 是画布单位；换成图集里的像素高度，再缩放到想要的可见高度。
    let pxPerUnit = animation.frameH / max(1, canvasH)
    let contentPx = animation.box.height * pxPerUnit
    return contentPx > 0 ? contentHeight / contentPx : 1
  }

  private var bodySize: NSSize {
    guard let animation else { return NSSize(width: 120, height: 120) }
    return NSSize(width: animation.frameW * frameScale, height: animation.frameH * frameScale)
  }

  var desiredSize: NSSize {
    let body = bodySize
    let bubble = bubbleLayout(maxWidth: 280).size
    let width = max(body.width, bubble.width) + 20
    let height = body.height + (bubble.height > 0 ? bubble.height + 8 : 0) + 10
    return NSSize(width: max(80, width), height: max(80, height))
  }

  // MARK: 状态

  func apply(_ state: [String: Any]) {
    stateSize = state["size"] as? String ?? "medium"
    let nextPack = state["packId"] as? String ?? "deepy-whale"
    if pack == nil || nextPack != packId {
      packId = nextPack
      pack = PetPack.load(id: nextPack) ?? PetPack.load(id: "deepy-whale")
      canvasH = pack?.canvasH ?? 52
      frames = []
      animationName = ""
    }
    if let pack {
      let name = pack.animationName(state: state["state"] as? String ?? "idle", tier: state["tier"] as? Int ?? 0)
      if name != animationName || frames.isEmpty {
        play(name)
      }
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
      if let detail = bubble["detail"] as? String, !detail.isEmpty { line += "\n\(detail)" }
      bubbleText = line.isEmpty ? nil : line
    } else {
      bubbleText = nil
    }
    let size = desiredSize
    host?.resize(to: size)
    frame = NSRect(origin: frame.origin, size: size)
    needsDisplay = true
  }

  private func play(_ name: String) {
    frameTimer?.invalidate()
    frameTimer = nil
    guard let pack, let animation = pack.animations[name] else {
      frames = []
      self.animation = nil
      needsDisplay = true
      return
    }
    self.animation = animation
    animationName = name
    frames = Self.extractFrames(animation: animation, packId: pack.id)
    frameIndex = 0
    guard !frames.isEmpty else {
      needsDisplay = true
      return
    }
    scheduleNext(after: animation.frames[0].ms)
    needsDisplay = true
  }

  private func scheduleNext(after ms: Int) {
    frameTimer?.invalidate()
    frameTimer = Timer.scheduledTimer(withTimeInterval: max(0.02, Double(ms) / 1000), repeats: false) { [weak self] _ in
      guard let self, let animation = self.animation, !self.frames.isEmpty else { return }
      if self.frameIndex + 1 < self.frames.count {
        self.frameIndex += 1
      } else if animation.loop {
        self.frameIndex = 0
      } else {
        return
      }
      self.needsDisplay = true
      self.scheduleNext(after: animation.frames[self.frameIndex].ms)
    }
  }

  /// 按 cols 把图集裁成一帧一张（CGImage 的原点在左上角）。
  private static func extractFrames(animation: PetAnimation, packId: String) -> [NSImage] {
    let path = "\(PetPack.assetRoot)/assets/pets/\(packId)/\(animation.sheet)"
    guard let sheet = NSImage(contentsOfFile: path),
          let cg = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
    var result: [NSImage] = []
    for frame in animation.frames {
      let col = frame.index % max(1, animation.cols)
      let row = frame.index / max(1, animation.cols)
      let rect = CGRect(
        x: CGFloat(col) * animation.frameW,
        y: CGFloat(row) * animation.frameH,
        width: animation.frameW,
        height: animation.frameH
      ).integral
      guard let cropped = cg.cropping(to: rect) else { continue }
      result.append(NSImage(cgImage: cropped, size: NSSize(width: animation.frameW, height: animation.frameH)))
    }
    return result
  }

  // MARK: 画

  override func draw(_ dirtyRect: NSRect) {
    let body = bodySize
    let bubble = bubbleLayout(maxWidth: max(140, bounds.width - 20))
    var y = bounds.height - 4
    if bubble.size.height > 0 {
      let rect = NSRect(
        x: (bounds.width - bubble.size.width) / 2,
        y: y - bubble.size.height,
        width: bubble.size.width,
        height: bubble.size.height
      )
      NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
      let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
      path.fill()
      NSColor.separatorColor.setStroke()
      path.lineWidth = 1
      path.stroke()
      bubble.draw(rect.insetBy(dx: 9, dy: 7))
      y = rect.minY - 6
    }
    if frames.indices.contains(frameIndex) {
      let bodyRect = NSRect(x: (bounds.width - body.width) / 2, y: y - body.height, width: body.width, height: body.height)
      frames[frameIndex].draw(in: bodyRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
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

  // MARK: 鼠标

  override func mouseDown(with event: NSEvent) {
    dragged = false
    dragOrigin = event.locationInWindow
    let now = Date()
    if now.timeIntervalSince(lastClick) < 0.4 { host?.openApp() }
    lastClick = now
  }

  override func mouseDragged(with event: NSEvent) {
    dragged = true
    guard let window else { return }
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

import Cocoa
import FlutterMacOS
import UserNotifications

/// 系统通知：`dsh/notify`（方法）+ `dsh/notify/taps`、`dsh/notify/actions`（事件）。
///
/// Android 版用 NotificationChannel 和 PendingIntent；macOS 用 UNUserNotificationCenter，
/// 语义对齐：每个对话一组（threadIdentifier），「等你确认」的通知带「允许一次 / 拒绝」按钮。
final class MacNotify: NSObject, UNUserNotificationCenterDelegate {
  static let shared = MacNotify()

  static let approvalCategory = "dsh.approval"
  static let allowAction = "dsh.allow-once"
  static let rejectAction = "dsh.reject"

  private var methods: FlutterMethodChannel?
  private var taps: FlutterEventChannel?
  private var actions: FlutterEventChannel?
  private var tapSink: FlutterEventSink?
  private var actionSink: FlutterEventSink?

  func attach(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "dsh/notify", binaryMessenger: messenger)
    methods?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    taps = FlutterEventChannel(name: "dsh/notify/taps", binaryMessenger: messenger)
    taps?.setStreamHandler(EventSinkBox { [weak self] sink in self?.tapSink = sink })
    actions = FlutterEventChannel(name: "dsh/notify/actions", binaryMessenger: messenger)
    actions?.setStreamHandler(EventSinkBox { [weak self] sink in self?.actionSink = sink })

    let center = UNUserNotificationCenter.current()
    center.delegate = self
    registerCategories(center)
  }

  private func registerCategories(_ center: UNUserNotificationCenter) {
    let allow = UNNotificationAction(
      identifier: Self.allowAction,
      title: "允许一次",
      options: [.authenticationRequired]
    )
    let reject = UNNotificationAction(
      identifier: Self.rejectAction,
      title: "拒绝",
      options: [.destructive, .authenticationRequired]
    )
    let approval = UNNotificationCategory(
      identifier: Self.approvalCategory,
      actions: [allow, reject],
      intentIdentifiers: [],
      options: []
    )
    let plain = UNNotificationCategory(identifier: "dsh.plain", actions: [], intentIdentifiers: [], options: [])
    center.setNotificationCategories([approval, plain])
  }

  // MARK: - 通道

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let enabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        DispatchQueue.main.async {
          result(["native": true, "enabled": enabled, "done": true, "attention": true])
        }
      }
    case "show":
      guard let args = call.arguments as? [String: Any] else { return result(false) }
      show(args) { ok in result(ok) }
    case "actionResult":
      // 通知按钮的结果由系统自己收起；这里只需要确认收到。
      result(true)
    case "cancel":
      guard let args = call.arguments as? [String: Any],
            let group = args["group"] as? String, let key = args["key"] as? String else {
        return result(nil)
      }
      let id = Self.identifier(group: group, key: key)
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
      result(nil)
    case "cancelGroup":
      guard let args = call.arguments as? [String: Any], let group = args["group"] as? String else {
        return result(nil)
      }
      let prefix = "\(group)#"
      UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
        let ids = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        DispatchQueue.main.async { result(nil) }
      }
    case "cancelAll":
      UNUserNotificationCenter.current().removeAllDeliveredNotifications()
      UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
      result(nil)
    case "openSettings":
      if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
        NSWorkspace.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func identifier(group: String, key: String) -> String {
    "\(group)#\(key)"
  }

  // MARK: - 发送

  private func show(_ args: [String: Any], completion: @escaping (Bool) -> Void) {
    let group = args["group"] as? String ?? "dsh"
    let key = args["key"] as? String ?? UUID().uuidString
    let title = args["title"] as? String ?? "DSH Go"
    let text = (args["fullText"] as? String) ?? (args["text"] as? String) ?? ""
    let canApprove = args["canApprove"] as? Bool ?? false
    let id = Self.identifier(group: group, key: key)

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = text
    content.threadIdentifier = group
    content.categoryIdentifier = canApprove ? Self.approvalCategory : "dsh.plain"
    content.sound = .default
    content.interruptionLevel = .active
    content.userInfo = [
      "sessionId": args["sessionId"] as? String ?? "",
      "host": args["host"] as? String ?? "",
      "kind": args["kind"] as? String ?? "",
      "eventId": args["eventId"] as? String ?? "",
      "group": group,
      "key": key,
    ]

    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      switch settings.authorizationStatus {
      case .notDetermined:
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          guard granted else {
            DispatchQueue.main.async { completion(false) }
            return
          }
          Self.deliver(id: id, content: content, center: center, completion: completion)
        }
      case .denied:
        DispatchQueue.main.async { completion(false) }
      default:
        Self.deliver(id: id, content: content, center: center, completion: completion)
      }
    }
  }

  private static func deliver(
    id: String,
    content: UNNotificationContent,
    center: UNUserNotificationCenter,
    completion: @escaping (Bool) -> Void
  ) {
    // 同一 key 覆盖旧通知（和 Android 的 notify(tag, id) 一样）。
    center.removeDeliveredNotifications(withIdentifiers: [id])
    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
    center.add(request) { error in
      DispatchQueue.main.async { completion(error == nil) }
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // App 在前台也显示：一轮结束/等你确认是 App 外面的提醒。
    completionHandler([.banner, .sound, .list])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    let sessionId = info["sessionId"] as? String ?? ""
    let host = info["host"] as? String ?? ""
    let kind = info["kind"] as? String ?? ""
    let eventId = info["eventId"] as? String ?? ""
    let group = info["group"] as? String ?? ""
    let key = info["key"] as? String ?? ""

    let decision: String?
    switch response.actionIdentifier {
    case Self.allowAction: decision = "allowed-once"
    case Self.rejectAction: decision = "rejected"
    default: decision = nil
    }

    if let decision, !eventId.isEmpty {
      let payload: [String: Any] = [
        "host": host,
        "group": group,
        "key": key,
        "eventId": eventId,
        "decision": decision,
      ]
      DispatchQueue.main.async { [weak self] in
        self?.actionSink?(payload)
      }
    } else if !sessionId.isEmpty {
      var payload: [String: Any] = [
        "sessionId": sessionId,
        "host": host,
        "kind": kind,
      ]
      if !eventId.isEmpty { payload["eventId"] = eventId }
      DispatchQueue.main.async { [weak self] in
        self?.tapSink?(payload)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    completionHandler()
  }
}

/// 把 FlutterStreamHandler 的两段回调收成 setSink。
final class EventSinkBox: NSObject, FlutterStreamHandler {
  private let onSink: (FlutterEventSink?) -> Void
  init(_ onSink: @escaping (FlutterEventSink?) -> Void) {
    self.onSink = onSink
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onSink(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onSink(nil)
    return nil
  }
}

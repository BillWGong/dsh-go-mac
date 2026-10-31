import Cocoa
import FlutterMacOS
import PDFKit

/// 文件与图片：`dsh/files`、`dsh/media`。
///
/// Android 版走 SAF / MediaStore / content://；macOS 上引擎直接读写磁盘，所以这里
/// 「访客路径」就是真实路径，导出目标换成 Finder 里的 Downloads / Pictures。
final class MacFiles: NSObject {
  static let shared = MacFiles()

  private var files: FlutterMethodChannel?
  private var media: FlutterMethodChannel?
  private var pdfs: [String: PDFDocument] = [:]

  func attach(messenger: FlutterBinaryMessenger) {
    files = FlutterMethodChannel(name: "dsh/files", binaryMessenger: messenger)
    files?.setMethodCallHandler { [weak self] call, result in
      self?.handleFiles(call, result: result)
    }
    media = FlutterMethodChannel(name: "dsh/media", binaryMessenger: messenger)
    media?.setMethodCallHandler { [weak self] call, result in
      self?.handleMedia(call, result: result)
    }
  }

  private static var home: URL {
    FileManager.default.homeDirectoryForCurrentUser
  }

  private static var downloadsDir: URL {
    home.appendingPathComponent("Downloads/DSH-Go", isDirectory: true)
  }

  private static var picturesDir: URL {
    home.appendingPathComponent("Pictures/DSH Go", isDirectory: true)
  }

  // MARK: - dsh/files

  private func handleFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "resolveGuest":
      guard let path = args["path"] as? String, FileManager.default.fileExists(atPath: path) else {
        return result(nil)
      }
      result(path)
    case "listOutputs":
      result([[String: Any]]())
    case "open":
      guard let path = args["path"] as? String else { return result(nil) }
      let url = URL(fileURLWithPath: path)
      guard FileManager.default.fileExists(atPath: path) else {
        return result(FlutterError(code: "missing", message: "no such file", details: path))
      }
      NSWorkspace.shared.open(url)
      result(nil)
    case "saveToDownloads":
      guard let path = args["path"] as? String else { return result(nil) }
      let name = Self.safeName(args["name"] as? String ?? URL(fileURLWithPath: path).lastPathComponent)
      do {
        let target = try copy(path: path, into: Self.downloadsDir, name: name)
        result("Downloads/DSH-Go/\(target.lastPathComponent)")
      } catch {
        result(FlutterError(code: "copy_failed", message: "\(error)", details: nil))
      }
    case "pdfInfo":
      guard let path = args["path"] as? String, let doc = document(path) else { return result([[String: Any]]()) }
      var pages: [[String: Any]] = []
      for index in 0..<doc.pageCount {
        guard let page = doc.page(at: index) else { continue }
        let box = page.bounds(for: .mediaBox)
        pages.append(["width": Int(box.width), "height": Int(box.height)])
      }
      result(pages)
    case "pdfPage":
      guard let path = args["path"] as? String,
            let doc = document(path),
            let index = (args["page"] as? Int).map({ $0 > 0 ? $0 - 1 : 0 }),
            let page = doc.page(at: index) else {
        return result(FlutterStandardTypedData(bytes: Data()))
      }
      let width = (args["width"] as? Int) ?? 1024
      guard let png = render(page: page, width: width) else {
        return result(FlutterStandardTypedData(bytes: Data()))
      }
      result(FlutterStandardTypedData(bytes: png))
    case "pdfClose":
      pdfs.removeAll()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func document(_ path: String) -> PDFDocument? {
    if let cached = pdfs[path] { return cached }
    guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
    pdfs[path] = doc
    return doc
  }

  private func render(page: PDFPage, width: Int) -> Data? {
    let box = page.bounds(for: .mediaBox)
    guard box.width > 0 else { return nil }
    let scale = CGFloat(width) / box.width
    let size = NSSize(width: CGFloat(width), height: box.height * scale)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    if let context = NSGraphicsContext.current?.cgContext {
      context.scaleBy(x: scale, y: scale)
      page.draw(with: .mediaBox, to: context)
    }
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
  }

  // MARK: - dsh/media

  private func handleMedia(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "saveImage":
      guard let data = args["bytes"] as? FlutterStandardTypedData else {
        return result(FlutterError(code: "no_bytes", message: nil, details: nil))
      }
      let name = Self.safeName(args["name"] as? String ?? "image.png")
      let dir = Self.picturesDir
      do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = Self.unique(dir.appendingPathComponent(name))
        try data.data.write(to: target)
        result("Pictures/DSH Go/\(target.lastPathComponent)")
      } catch {
        result(FlutterError(code: "failed", message: "\(error)", details: nil))
      }
    case "openSettings":
      // 没有相册权限这一步；打开「隐私与安全性」让需要的权限可达。
      if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") {
        NSWorkspace.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 工具

  private func copy(path: String, into dir: URL, name: String) throws -> URL {
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let target = Self.unique(dir.appendingPathComponent(name))
    try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: target)
    return target
  }

  private static func unique(_ url: URL) -> URL {
    guard FileManager.default.fileExists(atPath: url.path) else { return url }
    let base = url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension
    for index in 2...999 {
      let candidate = url.deletingLastPathComponent()
        .appendingPathComponent(ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)")
      if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }
    return url
  }

  private static func safeName(_ raw: String) -> String {
    let cleaned = raw
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: "\u{0}", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? "dsh-file" : String(cleaned.prefix(120))
  }
}

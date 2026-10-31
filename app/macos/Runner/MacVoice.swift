import AVFoundation
import Cocoa
import FlutterMacOS
import Speech

/// 语音输入：`dsh/voice`（方法）+ `dsh/voice/events`（事件）。
///
/// 原版（voice/VoicePlugin.kt）用 Android 的 SpeechRecognizer 和 MediaRecorder。macOS 上：
///   - 「系统识别」→ SFSpeechRecognizer（流式部分结果）；
///   - 「录音给引擎识别」→ AVAudioEngine 采集，转 16 kHz 单声道 PCM16，返回 WAV。
/// 事件带 sessionId，Dart 侧只收自己那次会话的。
final class MacVoice: NSObject {
  static let shared = MacVoice()

  private var methods: FlutterMethodChannel?
  private var events: FlutterEventChannel?
  private var sink: FlutterEventSink?

  private let engine = AVAudioEngine()
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var wav: WavWriter?
  private var session = 0
  private var mode: Mode = .idle
  private var limitTimer: Timer?
  private var finalTimer: Timer?

  private enum Mode { case idle, recognizing, recording }

  func attach(messenger: FlutterBinaryMessenger) {
    methods = FlutterMethodChannel(name: "dsh/voice", binaryMessenger: messenger)
    methods?.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    events = FlutterEventChannel(name: "dsh/voice/events", binaryMessenger: messenger)
    events?.setStreamHandler(EventSinkBox { [weak self] sink in self?.sink = sink })
  }

  // MARK: - 通道

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      let recognizerAvailable = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) != nil
      result([
        "recognizer": recognizerAvailable,
        "recorder": true,
        "systemUnreliable": false,
      ])
    case "requestPermission":
      requestPermission { permission in
        result(permission)
      }
    case "openSettings":
      if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone") {
        NSWorkspace.shared.open(url)
      }
      result(nil)
    case "startRecognizer":
      let args = call.arguments as? [String: Any] ?? [:]
      let id = (args["sessionId"] as? Int) ?? 0
      let language = args["language"] as? String
      startRecognizer(session: id, language: language, result: result)
    case "startRecorder":
      let args = call.arguments as? [String: Any] ?? [:]
      let id = (args["sessionId"] as? Int) ?? 0
      let maxSeconds = (args["maxSeconds"] as? Int) ?? 60
      startRecorder(session: id, maxSeconds: maxSeconds, result: result)
    case "stop":
      stop(result: result)
    case "cancel":
      cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(_ completion: @escaping (String) -> Void) {
    let mic = AVCaptureDevice.authorizationStatus(for: .audio)
    let speech = SFSpeechRecognizer.authorizationStatus()

    func finish() {
      let micOK = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
      let speechOK = SFSpeechRecognizer.authorizationStatus() == .authorized
      let blocked = AVCaptureDevice.authorizationStatus(for: .audio) == .denied
        || SFSpeechRecognizer.authorizationStatus() == .denied
      DispatchQueue.main.async { completion(micOK && speechOK ? "granted" : (blocked ? "blocked" : "denied")) }
    }

    if mic == .notDetermined {
      AVCaptureDevice.requestAccess(for: .audio) { _ in
        if speech == .notDetermined {
          SFSpeechRecognizer.requestAuthorization { _ in finish() }
        } else {
          finish()
        }
      }
    } else if speech == .notDetermined {
      SFSpeechRecognizer.requestAuthorization { _ in finish() }
    } else {
      finish()
    }
  }

  // MARK: - 事件

  private func emit(_ type: String, _ extra: [String: Any] = [:]) {
    var payload: [String: Any] = ["type": type, "sessionId": session]
    payload.merge(extra) { _, new in new }
    DispatchQueue.main.async { [weak self] in
      self?.sink?(payload)
    }
  }

  private func emitLevel(_ buffer: AVAudioPCMBuffer) {
    guard let data = buffer.floatChannelData?[0] else { return }
    let count = Int(buffer.frameLength)
    guard count > 0 else { return }
    var sum: Float = 0
    for i in 0..<count {
      let sample = data[i]
      sum += sample * sample
    }
    let rms = sqrt(sum / Float(count))
    // 0…1，和对数听感对齐；和原版的档位大致一致。
    let level = min(1, max(0, (20 * log10(max(rms, 1e-6)) + 60) / 60))
    emit("level", ["value": Double(level)])
  }

  // MARK: - 系统识别

  private func startRecognizer(session id: Int, language: String?, result: @escaping FlutterResult) {
    cancel()
    session = id
    let locale = Locale(identifier: language ?? (Locale.current.identifier.isEmpty ? "zh-CN" : Locale.current.identifier))
    guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
          recognizer.isAvailable else {
      result(FlutterError(code: "unavailable", message: "speech recognizer unavailable", details: nil))
      return
    }
    self.recognizer = recognizer
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.request = request

    do {
      try startEngine { [weak self] buffer in
        request.append(buffer)
        self?.emitLevel(buffer)
      }
    } catch {
      result(FlutterError(code: "audio", message: "\(error)", details: nil))
      return
    }

    mode = .recognizing
    task = recognizer.recognitionTask(with: request) { [weak self] outcome, error in
      guard let self else { return }
      if let outcome {
        if outcome.isFinal {
          let text = outcome.bestTranscription.formattedString
          self.emit("final", ["text": text])
          self.emit("end")
          self.teardown(stopEngine: true)
        } else {
          self.emit("partial", ["text": outcome.bestTranscription.formattedString])
        }
      }
      if error != nil, self.mode == .recognizing {
        self.emit("error", ["code": 7])
        self.emit("end")
        self.teardown(stopEngine: true)
      }
    }
    result(nil)
  }

  // MARK: - 录音（给引擎的识别用）

  private func startRecorder(session id: Int, maxSeconds: Int, result: @escaping FlutterResult) {
    cancel()
    session = id
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("dsh-voice-\(UUID().uuidString).wav")
    do {
      wav = try WavWriter(url: url)
      try startEngine { [weak self] buffer in
        self?.emitLevel(buffer)
        self?.appendPCM(buffer)
      }
    } catch {
      wav = nil
      result(FlutterError(code: "audio", message: "\(error)", details: nil))
      return
    }
    mode = .recording
    limitTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(maxSeconds), repeats: false) { [weak self] _ in
      guard let self, self.mode == .recording else { return }
      self.teardown(stopEngine: true)
      self.emit("limit")
      self.emit("end")
    }
    result(nil)
  }

  private func appendPCM(_ buffer: AVAudioPCMBuffer) {
    guard let wav else { return }
    guard let converted = Self.convertToPCM16(buffer) else { return }
    wav.append(converted)
  }

  /// 引擎要的是 16 kHz 单声道 PCM16。
  private static func convertToPCM16(_ buffer: AVAudioPCMBuffer) -> Data? {
    guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)
    else { return nil }
    guard let converter = AVAudioConverter(from: buffer.format, to: target) else { return nil }
    let ratio = target.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
    guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
    var consumed = false
    var error: NSError?
    converter.convert(to: out, error: &error) { _, status in
      if consumed {
        status.pointee = .noDataNow
        return nil
      }
      consumed = true
      status.pointee = .haveData
      return buffer
    }
    guard error == nil, out.frameLength > 0, let channel = out.int16ChannelData?[0] else { return nil }
    return Data(bytes: channel, count: Int(out.frameLength) * MemoryLayout<Int16>.size)
  }

  // MARK: - 音频引擎

  private func startEngine(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws {
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0 else {
      throw NSError(domain: "dsh.voice", code: 1, userInfo: [NSLocalizedDescriptionKey: "no microphone input"])
    }
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      onBuffer(buffer)
    }
    engine.prepare()
    try engine.start()
  }

  private func teardown(stopEngine: Bool) {
    limitTimer?.invalidate()
    limitTimer = nil
    finalTimer?.invalidate()
    finalTimer = nil
    mode = .idle
    request?.endAudio()
    task?.cancel()
    task = nil
    request = nil
    if stopEngine {
      engine.inputNode.removeTap(onBus: 0)
      if engine.isRunning { engine.stop() }
    }
  }

  private func stop(result: @escaping FlutterResult) {
    switch mode {
    case .recording:
      teardown(stopEngine: true)
      guard let wav else {
        result(nil)
        return
      }
      self.wav = nil
      do {
        try wav.finish()
        let data = try Data(contentsOf: wav.url)
        try? FileManager.default.removeItem(at: wav.url)
        emit("end")
        result(FlutterStandardTypedData(bytes: data))
      } catch {
        result(FlutterError(code: "recorder", message: "\(error)", details: nil))
      }
    case .recognizing:
      // 收尾：等识别器给出 final（最多 2 秒），再结束。
      request?.endAudio()
      finalTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
        self?.teardown(stopEngine: true)
        self?.emit("end")
      }
      result(nil)
    case .idle:
      result(nil)
    }
  }

  private func cancel() {
    limitTimer?.invalidate()
    limitTimer = nil
    finalTimer?.invalidate()
    finalTimer = nil
    mode = .idle
    request?.endAudio()
    task?.cancel()
    task = nil
    request = nil
    engine.inputNode.removeTap(onBus: 0)
    if engine.isRunning { engine.stop() }
    if let wav {
      try? FileManager.default.removeItem(at: wav.url)
      self.wav = nil
    }
  }
}

/// 16 kHz / 单声道 / PCM16 的 WAV 写入器。
final class WavWriter {
  let url: URL
  private var handle: FileHandle?
  private var bytes = 0

  init(url: URL) throws {
    self.url = url
    FileManager.default.createFile(atPath: url.path, contents: nil)
    let handle = try FileHandle(forWritingTo: url)
    self.handle = handle
    handle.write(Data(count: 44))
  }

  func append(_ data: Data) {
    handle?.write(data)
    bytes += data.count
  }

  func finish() throws {
    guard let handle else { return }
    let sampleRate: UInt32 = 16000
    let channels: UInt16 = 1
    let bits: UInt16 = 16
    let byteRate = sampleRate * UInt32(channels) * UInt32(bits / 8)
    let blockAlign = channels * (bits / 8)
    var header = Data()
    func ascii(_ s: String) { header.append(s.data(using: .ascii)!) }
    func u32(_ v: UInt32) { var x = v.littleEndian; header.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; header.append(Data(bytes: &x, count: 2)) }
    ascii("RIFF")
    u32(UInt32(36 + bytes))
    ascii("WAVE")
    ascii("fmt ")
    u32(16)
    u16(1)
    u16(channels)
    u32(sampleRate)
    u32(byteRate)
    u16(blockAlign)
    u16(bits)
    ascii("data")
    u32(UInt32(bytes))
    try handle.seek(toOffset: 0)
    handle.write(header)
    try handle.close()
    self.handle = nil
  }
}

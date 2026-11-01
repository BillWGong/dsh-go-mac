# DSH Go Mac（Apple Silicon）

把 Android 版 DSH Go 移植到 Mac。界面代码一份、功能逐项对齐；Android 专属的几块换成 macOS
上等价的原生实现。

- 目标平台：macOS 13+，Apple Silicon（arm64）。Intel 不在本轮范围内。
- 许可证：与原项目一致，AGPL-3.0（`sdk/`、`examples/` 仍是 MIT）。本机引擎里跑的 DSH 是
  DeepSeek Harness 自己的包，按其许可证分发。

---

## 1. 为什么是这个做法

原版就是 Flutter（`app/lib`，740 个 Dart 文件、约 28 万行），Android 的原生部分全部通过
`MethodChannel` 接进来，Dart 侧对「原生缺席」有完整降级（很多桥接类自己写着 *desktop:
nothing happens*）。所以：

- **界面**：`macos/` 只是新增一个平台目标，`lib/` 一行 UI 都不用重写，滚动、主题、桌宠、
  分享卡、插件面板、网页模式全部同源。
- **外壳**：换成 NSWindow + NSMenu + UNUserNotificationCenter + PDFKit + WKWebView
  （`webview_flutter_wkwebview` 从 3.27 起就带 macOS 实现，网页/插件面板可以直接复用）。
- **本机引擎**：Android 用 PRoot 跑 Ubuntu + Node；macOS 根本不需要 Linux 兼容层——
  官方 Node 24 有 darwin-arm64 构建，DSH 是普通 npm 包，直接起子进程，启动更快、内存更省。
- 没选 Electron/Tauri 重写前端：那会丢掉 28 万行已经打磨过的 Flutter 界面和交互。

```
app/lib/                     Flutter 界面（原样保留，新增 lib/macos/ 接入层）
  lib/macos/window_mode.dart 窗口版式（自适应 / 手机）、MacWindowFrame
  lib/macos/mac_runtime.dart macOS 本机引擎（实现 RuntimeBridge 同一套契约）
  lib/macos/mac_localizations.dart macOS 措辞覆盖（「这台手机」→「这台 Mac」等）
  lib/macos/macos_support.dart 启动接线
app/macos/                   Swift 平台层（Xcode 工程）
  Runner/MacHost.swift        窗口、菜单、深链、不适用通道的明确答复
  Runner/MacNotify.swift      系统通知 + 通知上的「允许一次 / 拒绝」
  Runner/MacFiles.swift       打开/另存/PDF 渲染/保存图片
runtime/build-runtime-macos.sh 生成内置运行时（Node + DSH + pnpm + dsh-go-bridge）
tooling/build-macos.sh        一条命令出 .app / .dmg
```

---

## 2. 平台能力对照

| 原版（Android / Kotlin） | macOS 实现 | 状态 |
| --- | --- | --- |
| 本机引擎：PRoot + Ubuntu + Node + DSH | 原生 Node 24 + DSH npm 树 + `dsh-go-bridge` | ✅ |
| （新增）本机官方 DSH | 发现官方 App 的 127.0.0.1 端口，用 `~/.dsh` 的会话密钥签 cookie 直连 | ✅ 实验 |
| 安装运行环境（进度、校验、解包） | 内置 tar.gz → `tar -xzf`，sha256 校验，进度事件 | ✅ |
| 启动/停止/日志/失败分类/安全模式/连续失败进安全模式 | `lib/macos/mac_runtime.dart`，语义对齐 Kotlin `SafePolicy` | ✅ |
| 远程主机（SSH / DSH Remote） | 纯 Dart（dartssh2 / WebRTC），无需改动 | ✅ |
| 聊天、工具审批、提问、插件面板 | Flutter + `webview_flutter_wkwebview`(macOS) | ✅ |
| 网页模式（内嵌 DSH Web） | 同一个 WKWebView 插件 | ✅ |
| 系统通知（一轮结束 / 等你确认） | UNUserNotificationCenter，分组、按钮、点击回跳 | ✅ |
| 通知权限设置页 | 打开系统「通知」设置 | ✅ |
| 保存图片 / 另存文件 | `~/Pictures/DSH Go`、`~/Downloads/DSH-Go` | ✅ |
| PDF 预览 | PDFKit 渲染 | ✅ |
| 文件选择（插件、附件） | `file_picker` / `image_picker` 的 macOS 实现 | ✅ |
| `dshgo://` 深链、Finder 打开 | Info.plist URL Scheme + `application(_:open:)` | ✅ |
| 窗口版式：手机竖屏 ⇄ Mac 自适应 | NSWindow 尺寸 + 菜单 `⌘⇧M` | ✅ |
| 界面文案里的「这台手机」 | 继承生成的 L10n 覆盖 35 条说法，功能名改「Mac 操控」 | ✅ |
| 菜单栏、快捷键（复制/粘贴/全屏/退出） | 程序化 NSMenu | ✅ |
| Android 桌面图标/快捷方式、Shizuku、电池优化、厂商后台白名单 | 不适用：返回明确的「没有」，界面自动隐藏对应入口 | ✅（按不适用处理） |
| 应用内更新（下载 APK 安装） | Mac 走 DMG；`dsh/update` 返回不可自安装 | ⚠️ 待接入版本检查 |
| 桌宠「App 外显示」 | 无边框置顶 NSPanel：状态贴图、气泡、拖动、右键菜单、今天不再显示 | ✅（气泡上不直接批准，点它回 App） |
| 语音输入（系统识别 / 录音给引擎） | SFSpeechRecognizer + AVAudioEngine，16 kHz WAV | ✅ |
| 手机操控（读屏、点按） | 需要辅助功能（AXUIElement）+ ScreenCaptureKit + 审批 | 🚧 待实现 |
| 原生插件协议（native-media / native-files） | 依赖 dsh-go-bridge 的 WebSocket 能力，Mac 侧尚未接线 | 🚧 待实现 |

> 「✅」= 代码已就位；`🚧` = 入口在、能力未接，界面会显示不可用而不是崩。

---

## 3. 本机引擎

### 3.1 组成

`runtime/build-runtime-macos.sh` 产出 `app/assets/runtime-macos/runtime-arm64.tar.gz`：

```
runtime/
  node/          Node v24.22.1 darwin-arm64（含 npm、pnpm 11）
  dsh/           npm ci 出来的 DSH 0.2.1-rc.4 依赖树 + runtime/patches/*.diff
  bridge/        dsh-go-bridge（插件清单 / 原生插件协议）
  etc/dsh-app/   启动 overlay（每次启动由 App 重写，里面是绝对路径）
  home/          引擎的 HOME（.dsh、工作区、插件都在这）
  tmp/
```

### 3.2 启动

```
<runtime>/node/bin/node <runtime>/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js \
  web --patch <runtime>/etc/dsh-app/dsh-web.patch.yml \
  --host 127.0.0.1 --port <空闲端口> --no-open
```

DSH 打印 `dsh web: http://127.0.0.1:<port>/?token=…` 后，Dart 侧解析出 baseUrl/token，
做一次 TCP 探活，然后把 `phase=running` 通过和 Android 完全相同的事件推给界面。

### 3.3 使用官方 DSH（实验）

Mac 上已经装了官方 DeepSeek Harness 时，可以让 DSH Go Mac 直接接管它，而不是再启动一套
内置运行时：

- 发现：`lsof` 找官方 App 监听的 `127.0.0.1:<port>`（当前是 62680 这种随机端口）。
- 认证：官方 DSH 的浏览器会话 cookie 由 `~/.dsh/.credentials.yaml` 里
  `client-connection/browser-session` 的长期密钥签名（DSH 的 Dart 客户端本来就有 cookie
  直连模式）。App 在内存里签一个 30 天有效的 `dsh-auth-*` cookie，只用于本机回环请求，
  不写盘、不上传。
- 连接：`DshClient.connect(baseUri, cookie:)`，和浏览器打开官方 DSH 是同一条路。
- 入口：对话列表底部的「切换主机」里，本地有两种：**本地 DSH · 自带** 和 **本地官方 DSH**；
  远程主机单独一组。选中后立即重连，顶部的当前主机名会带上「· 官方」。
- 共享：对话、模型、插件、凭据都是官方 App 那一份；不需要 SSH / DSH Remote。

限制：官方 DSH 必须先运行；官方 App 退出后本机引擎会显示「官方 DSH 没有在运行」。
这种模式下「网页」按钮和插件岛（依赖启动 token）会隐藏；托管技能由官方 App 管理。

### 3.4 手机控制这台 Mac 的内置 DSH

`设置 › 本机引擎 › 手机连接`（只在「本地 DSH · 自带」模式下出现）把手机需要的信息直接列出来：

- 主机（`用户名@局域网地址`）、端口 22、用户名、所有局域网地址，可一键复制
- **密码说明**：用这台 Mac 的**登录密码**（开机/解锁那个），不是 DeepSeek API Key，
  也不是 DSH Go 的密码；也可以改用 SSH 密钥
- 远程登录（22 端口）是否已开启，没开时一键打开系统设置的「共享」页
- 内置引擎是否在运行、手机握手是否已就绪

手机端：`切换主机 › 添加 SSH 主机`，填上面的主机与密码，启动命令保持默认 `dsh web`。

原理：手机端 DSH Go 的 SSH 主机连上后会读 `~/.dsh-app-remote/` 里的 `web.pid`、`web.st`、
`web.cmd`、`web.log`；内置引擎就绪时 App 会把这四样写好，手机于是**复用正在运行的引擎**，
不会再起第二个 DSH。握手文件只在「本地 DSH · 自带」模式写；切到官方 DSH 时会删除，
官方实例（`~/.dsh`）与内置引擎（App 自己的数据目录）始终互不影响。

### 3.5 数据目录

```
~/Library/Application Support/io.github.billwgong.dshgomac/
  runtime/            安装后的引擎（卸载/重置会删掉）
  runtime-state.json  已安装版本、安全模式、连续失败计数
```

运行 `bash runtime/build-runtime-macos.sh` 可单独重建运行时；`--clean` 丢弃缓存重来。

---

## 4. 构建

前置：

1. **完整 Xcode**（App Store 安装，约 7–10 GB）。只有 Command Line Tools 时 `xcodebuild`
   不可用，Flutter 的 macOS 目标编不了：
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
2. **Flutter 3.47.x**（Dart 3.13.5）。仓库未内置 SDK，放到 PATH，或用 `FLUTTER=` 指定。
3. Apple Silicon Mac。

```bash
# 首次：生成运行时（约 2–5 分钟，下载 50 MB Node + npm 依赖）
bash runtime/build-runtime-macos.sh

# 构建 .app（可加 --dmg 顺手打 DMG）
bash tooling/build-macos.sh --dmg

# 日常开发（热重载）
cd app && flutter run -d macos
```

产物：`app/build/macos/Build/Products/Release/dsh_go.app`。

本地未签名构建第一次打开会被 Gatekeeper 拦：右键 → 打开，或
`xattr -dr com.apple.quarantine <app>`。分发给别人需要 Developer ID 签名 + 公证。

---

## 5. 界面：两种版式与文案

文案不另写一套 ARB：`lib/macos/mac_localizations.dart` 继承 gen-l10n 生成的
`L10nZh` / `L10nEn`，只覆盖指代当前设备的那几条（「在这台手机上运行 DSH」→「在这台 Mac
上运行 DSH」、「Android Keystore」→「钥匙串」），并把「手机操控」改叫「Mac 操控」。
界面代码里的 `context.l10n` / `appL10n` 调用一行没改；`flutter test` 里
（`FLUTTER_TEST=true`）自动退回手机文案，既有测试和 golden 不受影响。



- **自适应**（默认）：按窗口宽度铺开，宽屏时侧栏常驻，和原版平板/横屏一致。
- **手机版式**：窗口收成 440×900，内容固定一条，像在 Mac 上开了一台手机。
  菜单「DSH Go › 手机版式」（`⌘⇧M`）切换，选择会记住；窗口被拉宽时内容仍居中在 470pt。

---

## 6. 已知差异与后续

1. **官方 DSH 连接是实验性的**：依赖 `~/.dsh/.credentials.yaml` 的会话密钥；官方升级改了格式就会
   退回「未连上」，不会改官方数据。官方 App 退出后，本机官方 DSH 会显示未运行。
2. **手机操控（唯一没移植的大块）**：原版是「引擎里的 MCP 工具 → 原生无障碍服务 → 屏幕/
   点按」一整套（Kotlin 约 5700 行，含 relay、审批、敏感词、包名策略、不打扰模式）。
   Mac 上的等价物是 ScreenCaptureKit + AXUIElement + CGEvent，但工具协议、审批界面和
   敏感信息拦截都要按同一套语义重写。当前入口保留，页面显示「未就绪」，不会误导。
3. **应用内更新**：Mac 走 DMG；`dsh/update` 目前只报告版本、不提供自安装。
4. **App Store**：当前关闭 App Sandbox（本机引擎要启动自带 Node、读写工作区）。上架需要
   迁移到 XPC 服务 + 沙盒，属于另一条分发路径。
5. **Intel Mac**：`build-runtime-macos.sh` 目前只做 arm64；要支持 Intel 需再产一份 x64 运行时
   并做 universal 或分架构分发。
6. **桌宠细节**：气泡上的「允许一次 / 拒绝」不在浮窗里回答（点气泡回 App）；动画是状态级
   换帧，没有原版逐像素的移动/拖拽物理。

---

## 7. 构建后自查清单

装好 Xcode 后，按顺序过一遍（就是这台机器上无法自动验证的部分）：

1. `bash tooling/build-macos.sh` 能出 `dsh_go.app`，图标是 DSH Go 的。
2. 首次打开 → 引导页；选「本机」→ 安装运行环境（进度条走完）。
3. 引擎页点「启动」→ 日志出现 `dsh web: http://127.0.0.1:…`，状态变运行中。
4. 发一条消息，确认流式回复、工具审批都正常。
5. 菜单 `⌘⇧M` 切手机版式：窗口变窄、内容居中；再切回来。
6. 网页模式能打开（WKWebView）。
7. 一轮结束后系统通知出现；点通知回到对应对话。
8. 设置 › 桌宠：打开「App 外显示」→ 桌面上出现宠物，拖动、右键菜单、今天不再显示。
9. 语音输入：点麦克风，授权后说话，文字进输入框。
10. 保存图片到 `~/Pictures/DSH Go`，另存文件到 `~/Downloads/DSH-Go`。

## 8. 验证状态（2026-10-31 实测）

环境：macOS 27.0.1（Apple Silicon）、Xcode 27.2、Flutter 3.47.7（Dart 3.13.5）。

| 项目 | 结果 |
| --- | --- |
| `flutter analyze` | 0 issue |
| `flutter test test/macos` | 12/12 通过 |
| Swift 平台层 | `swiftc -typecheck`（arm64 / macOS 12）通过 |
| `flutter build macos --release` | ✅ `dsh_go.app` 341.5 MB（显示名 **DSH Go Mac**） |
| DMG | ✅ 256 MB，可挂载，含 Applications 快捷方式 |
| 启动 | ✅ 窗口 1180×820，Metal/Impeller 渲染，无崩溃 |
| 本机引擎 | ✅ 安装 193.5 MiB → 解包 → 启动 → `dsh web: http://127.0.0.1:…` |
| token 换 cookie | ✅ `GET /?token=…` → 303 + `dsh-auth` cookie → `GET /` → 200 |
| 停止 | ✅ 进程退出，无残留 node |
| 真实 App 自动启动引擎 | ✅ 启动后 node 监听 127.0.0.1，`.dsh/profiles` 生成 |

无头探针（不点 UI 直接验证引擎链路）：

```bash
cd app
flutter build macos --release -t lib/dev/macos_runtime_probe.dart
./build/macos/Build/Products/Release/dsh_go.app/Contents/MacOS/dsh_go
```

输出以 `PROBE OK` 结束即通过；随后用 `flutter build macos --release` 恢复正式入口。

> Xcode 27 提示：不再强制 x86_64。想要更小的包可先
> `flutter config --enable-macos-arm64-only`（只影响本机 Flutter 配置）。

测试字体：仓库的 `test/flutter_test_config.dart` 默认找 Linux 的 Noto CJK；Mac 上跑测试时
指一个本地字体目录即可：

```bash
DSH_TEST_FONT_DIR=/path/to/noto-cjk flutter test
```

---

## 9. 上游 1.0.5 / 1.0.6 / 1.0.10 跟进

上游的 `v1.0.5`、`v1.0.6` tag 都指向 1.0.4 的提交（`bf01594`），源码没有随版本发布，
只能按 release notes 跟进。已经落地的：

- 版本号 `1.0.10`（pubspec / AppInfo；关于页直接读编译期常量）
- 顶栏：自适应与标题栏合并；竖屏版式恢复系统标题栏占位（隐藏标题、不透明），红绿灯永不压内容
- 分享卡底部双二维码：原作仓库 + 本移植仓库
- Mac slogan：把 DSH 装进你的 Mac
- 1.0.10：引擎起来后写脱敏诊断 `$DSH_HOME/dsh-app/diagnostics.md`（版本、机型、运行时、启动方式、
  连接、安全模式、最近失败、日志尾部），并写入内置技能 `dsh-go-support`，模型被问「看下诊断」时
  会先读它；日志里的 token 已脱敏
- 对话：手动展开的思考在该轮结束后自动收回（1.0.5）
- 新增设置「Return 发送」：Return 直接发、Shift+Return 换行、⌘/Ctrl+Return 始终发送
- 1.0.5/1.0.6 的刷新率设置、手机操控报文压缩属于 Android 专属，Mac 不适用
- 思考预览三行窗口、侧栏逐帧模糊等性能改动缺少源码，等上游公开后再对齐


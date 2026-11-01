# DSH Go Mac

**DeepSeek Harness 的 macOS 原生客户端** —— Android 版 [DSH Go](https://github.com/ccch1mneyyy/dsh-go) 的移植。

Apple Silicon · Flutter + Swift · AGPL-3.0

> 这是**非官方**社区项目，和 DeepSeek 官方没有关系。
> 它把 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)（AGPL-3.0）从 Android 移植到 macOS：
> 界面代码来自上游，平台层重写为 Swift，本机引擎从 PRoot + Ubuntu 换成 macOS 原生 Node。
> 移植的技术细节、能力对照和已知差异见 [docs/macos/README.md](docs/macos/README.md)。

---

## 这是什么

DSH Go Mac 让你在 Mac 上更好的使用 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)：

- **本机引擎**：不用重新下载 dsh 官方版。App 内置 Node 24 + DSH，点一下就在你的
  Mac 上跑起来，对话、工作区、插件都在本机。
- **远程主机**：也可以连接电脑或服务器上的 DSH（SSH / DSH Remote），手机上那套体验原样搬过来，也可以让手机版 DSH Go链接电脑上的DSH Go Mac。
- **原生界面**：不是套壳网页。聊天、工具审批、提问、插件面板、分享卡、桌宠、语音输入都是
  上游那套 Flutter 界面，Mac 上重新接了系统能力。

## 和上游是什么关系

| | 上游 DSH Go | 本项目 |
| --- | --- | --- |
| 平台 | Android 8+ | macOS 12+（Apple Silicon） |
| 界面 | Flutter | 同一套 Flutter 代码（`app/lib`） |
| 平台层 | Kotlin（`app/android`） | Swift（`app/macos`） |
| 本机引擎 | PRoot + Ubuntu + Node | 原生 Node 24 + DSH npm 包 |
| 手机操控 / 无障碍 | Android AccessibilityService | **尚未移植**（见下文） |
| 应用内更新 | 下载 APK 安装 | 走 DMG（尚未接入） |

移植基于上游 **v1.0.4（commit `bf01594`）**。上游的 Android 构建仍然留在仓库里，未做改动。

## 功能状态

**已实现并实测**

- ✅ 本机引擎：安装（193 MiB 内置包 / 742 MiB 解包）、启动、停止、日志、失败分类、安全模式
- ✅ **本机官方 DSH（实验）**：直接连这台 Mac 上正在运行的 DeepSeek Harness，共享它的
  对话、模型和插件——不需要 SSH / DSH Remote，也不用装内置运行时
- ✅ **切换主机**：本地 DSH（自带）/ 本地官方 DSH / 远程（SSH、DSH Remote），一个弹层切换
- ✅ **手机连接**：App 内直接列出 Mac 的 IP/用户名/端口与密码说明，手机 SSH 复用内置引擎
- ✅ 远程主机：SSH、DSH Remote（纯 Dart 实现，未改动）
- ✅ 聊天、流式回复、工具审批、提问、插件面板、网页模式（WKWebView）
- ✅ 系统通知：一轮结束 / 等你确认，通知上可直接「允许一次 / 拒绝」，点击回到对话
- ✅ 文件：打开、另存到 `~/Downloads/DSH-Go`、保存图片到 `~/Pictures/DSH Go`、PDF 预览
- ✅ 语音输入：SFSpeechRecognizer（流式部分结果）+ 16 kHz 录音给引擎识别
- ✅ 桌宠「App 外显示」：无边框置顶浮窗、状态贴图、气泡、拖动、今天不再显示
- ✅ 窗口：Mac 自适应布局 ⇄ **竖屏版式**（菜单 `⌘⇧M`）；自适应下顶栏与系统标题栏合并，
  竖屏下系统标题栏占位，交通灯永远不会压到内容
- ✅ **分享卡**：对话导出成图片，底部带**原作 `ccch1mneyyy/dsh-go`** 和
  **本移植 `BillWGong/dsh-go-mac`** 两个二维码
- ✅ **关于页**：版本号、检查更新（指向本项目仓库）、给本项目 Star、支持原作者
- ✅ macOS 措辞：「这台手机」→「这台 Mac」、「手机存储」→「本机存储」、「Android Keystore」→「钥匙串」等；文件、语音、安装、更新、操控、布局命名都已按 Mac 校正
- ✅ `dshgo://` 深链、Finder 打开、菜单栏、深色模式、原生 PDF/文件对话框

**尚未移植**

- 🚧 **Mac 操控**（原「手机操控」）：辅助功能 + ScreenCaptureKit + MCP 工具 + 逐次审批。
  设计稿：[docs/macos/mac-control.md](docs/macos/mac-control.md)。当前入口保留、显示「未就绪」。
- 🚧 应用内更新：Mac 走 DMG，目前只报告版本，不自安装。
- 🚧 Intel Mac：运行时只做 arm64。

## 更新

**1.0.10**（当前）

- 顶栏与系统标题栏合并；竖屏版式改为系统标题栏占位，红绿灯不再与侧栏/顶栏重叠
- 关于页版本号修正；检查更新指向本项目仓库
- 新 slogan：**把 DSH 装进你的 Mac**
- 分享图改为双二维码（原作 + 本移植）
- 清理残留「手机」措辞；「手机版式」更名「竖屏版式」
- 修复官方 DSH 未运行时的异常、网页模式在 macOS 上的崩溃

## 安装

从 [Releases](https://github.com/BillWGong/dsh-go-mac/releases/latest) 下载
`dsh-go-mac-1.0.10-macos-arm64.dmg`，打开后把 **DSH Go Mac** 拖进 `Applications`。

首次打开会被 Gatekeeper 拦（未签名构建）：右键 →「打开」，或

```bash
xattr -dr com.apple.quarantine "/Applications/DSH Go Mac.app"
```

首次使用选「本机」会安装运行环境（约 750 MB，一两分钟）；也可以直接连远程主机。

## 从源码构建

前置：

1. **完整 Xcode**（不是只有 Command Line Tools），首次要同意许可：
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   ```
2. **Flutter 3.47.x**（Dart 3.13.5），放进 `PATH` 或用 `FLUTTER=` 指定。
3. Apple Silicon Mac，约 8 GB 空闲磁盘。

```bash
git clone https://github.com/BillWGong/dsh-go-mac.git
cd dsh-go-mac

# 1. 生成内置运行时（Node + DSH + pnpm + bridge，约 2–5 分钟，输出 193 MB）
bash runtime/build-runtime-macos.sh

# 2. 构建 .app 和 DMG
bash tooling/build-macos.sh --dmg
```

产物：

```
app/build/macos/Build/Products/Release/dsh_go.app
app/build/macos/dsh-go-mac-1.0.10-macos-arm64.dmg
```

环境检查：`bash tooling/check-macos-env.sh`。

## 架构

```
DSH Go Mac
├─ app/lib/                 Flutter 界面（与上游同一份）
│  ├─ macos/                 macOS 接入层
│  │  ├─ mac_runtime.dart    本机引擎（实现 RuntimeBridge 同一套契约）
│  │  ├─ window_mode.dart    自适应 / 竖屏版式
│  │  └─ mac_localizations.dart  macOS 措辞
├─ app/macos/               Swift 平台层（Xcode 工程）
│  ├─ MacHost.swift          窗口、菜单、深链
│  ├─ MacNotify.swift        系统通知
│  ├─ MacFiles.swift         文件 / 图片 / PDF
│  ├─ MacVoice.swift         语音识别与录音
│  └─ MacPetOverlay.swift    桌宠浮窗
├─ runtime/build-runtime-macos.sh   生成 Node + DSH 运行时
└─ tooling/build-macos.sh          构建 .app / .dmg
```

为什么不用 Electron/Tauri 重写：上游有 740 个 Dart 文件、约 28 万行界面代码。加一个
Flutter macOS 目标，UI 和交互一行不用重写；只需要把 Kotlin 那层换成 Swift。

## 目录里还有什么

`docs/` 是上游的中文指南；`runtime/` 是运行时打包脚本；`packages/` 是 DSH 的 Dart 客户端；
`services/`、`site/` 是配套的分享服务与网站。Mac 相关的改动集中在
`app/macos/`、`app/lib/macos/`、`runtime/build-runtime-macos.sh`、`tooling/*-macos.sh`。

## 已知限制

- **未签名**：直接分发需要 Developer ID 签名 + 公证，否则别人打开会被 Gatekeeper 拦。
- **未沙盒化**：本机引擎要启动自带 Node、读写工作区，所以关掉了 App Sandbox。上架 App Store
  需要改成 XPC 服务 + 沙盒。
- **Mac 操控未实现**：入口在、页面显示「未就绪」。
- **Intel Mac 不在支持范围**：运行时只做 arm64。

## 许可与致谢

- 本项目以 **AGPL-3.0** 发布，见 [LICENSE](LICENSE)。它包含并修改自
  [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)（AGPL-3.0，v1.0.4）。
  完整归属说明见 [NOTICE](NOTICE)。
- 名称、标识、Deepy / 鲸娘吉祥物等品牌素材不在开源授权范围内，见 [ASSETS.md](ASSETS.md)。
- 本机引擎里运行的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 按其
  自身许可证分发；运行时打包的是 `@deepseek-ai/dsh@0.2.1-rc.4`。
- 感谢上游作者 **ccch1mneyyy** 和 DeepSeek Harness 的开发者。没有他们的工作就没有这个移植。

## English

DSH Go Mac is an unofficial macOS port of [DSH Go](https://github.com/ccch1mneyyy/dsh-go),
the Android client for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness).

The Flutter UI is shared with upstream; the Kotlin platform layer is rewritten in Swift, and the
on-device engine runs native Node 24 + DSH instead of PRoot/Ubuntu. Built and tested on Apple
Silicon (macOS 26/27, Xcode 27, Flutter 3.47.7). Phone control is not ported yet.

Licensed AGPL-3.0. Not affiliated with DeepSeek. See [docs/macos/README.md](docs/macos/README.md)
for the architecture and parity matrix.

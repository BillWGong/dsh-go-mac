# 把 Android 客户端搬上 Mac：DSH Go Mac 移植实录

> 同一套 Flutter 界面，整条平台层从 Kotlin 换成 Swift；本机引擎从 PRoot + Ubuntu 换成 macOS 原生 Node；还能让手机反过来通过 SSH 接管 Mac 上的引擎。
>
> 项目：https://github.com/BillWGong/dsh-go-mac
> 视频：https://www.bilibili.com/video/BV1njxJ6WE59/

---

## 先说结论

DSH Go 是 Android 上的 DeepSeek Harness 客户端。我把它移植成了 macOS 原生 App：

- **界面不重写**：继续用上游那份 Flutter 代码（`app/lib`），只换平台层。
- **不装 Linux 虚拟机**：本机引擎直接跑 macOS arm64 的 Node 24 + DSH npm 包。
- **不套壳网页**：聊天、审批、插件、分享卡、桌宠、语音都是原生 Flutter 界面。
- **直连官方 DSH**：可以连这台 Mac 上正在运行的 DeepSeek Harness，共享它的对话和模型，不需要 SSH / DSH Remote。
- **手机能反过来控制它**：手机版 DSH Go 加一个 SSH 主机，就能复用 Mac 的内置引擎。

代码：AGPL-3.0，Apple Silicon / macOS 12+。

---

## 一、为什么值得做

Android 版的 DSH Go 已经把很多东西做完了：会话、流式回复、工具审批、插件面板、远程主机、分享卡、语音输入。但它有一个硬约束：本机引擎跑在 **PRoot + Ubuntu + Node** 里。这套东西在 Android 上合理，在 Mac 上就是纯负担——要装 Linux 环境、要维护 rootfs、启动慢、路径还是 `/root/workspace` 这种。

移植的目标很明确：

1. **保留上游 UI 和交互**，不重新发明。
2. **把平台层全部换成 macOS 原生**：窗口、通知、文件、PDF、语音、桌宠、深链。
3. **本机引擎改成原生 Node**，不再有 Linux。
4. **多一条路**：直接连官方 DeepSeek Harness，不强迫用户再装一份运行时。

---

## 二、整体架构

```
DSH Go Mac
├─ app/lib/                  Flutter 界面（与上游同一份）
│  ├─ macos/
│  │  ├─ mac_runtime.dart    本机引擎（实现 RuntimeBridge 契约）
│  │  ├─ official_dsh.dart   发现并直连官方 DSH
│  │  ├─ window_mode.dart    自适应 / 竖屏版式
│  │  └─ mac_localizations.dart  macOS 措辞
├─ app/macos/                Swift 平台层
│  ├─ MacHost.swift          窗口、菜单、深链、窗口通道
│  ├─ MacNotify.swift        系统通知（可原地允许/拒绝）
│  ├─ MacFiles.swift         打开/另存/PDF/目录
│  ├─ MacVoice.swift         SFSpeechRecognizer + AVAudioEngine
│  └─ MacPetOverlay.swift    桌宠浮窗（读 pack.json 切序列帧）
└─ runtime/                  构建期脚本：打包 Node + DSH + bridge
```

平台层不是"把 Kotlin 翻译成 Swift"那么简单，而是把 Android 的能力逐项换成 macOS 的等价物：

| 能力 | Android | macOS |
| --- | --- | --- |
| 本机引擎 | PRoot + Ubuntu + Node | 原生 Node 24 + DSH |
| 通知 | NotificationChannel | UNUserNotificationCenter |
| 文件 | SAF / ContentResolver | NSOpenPanel / NSSavePanel |
| PDF | PdfRenderer | PDFKit |
| 语音 | SpeechRecognizer | SFSpeechRecognizer + AVAudioEngine |
| 桌宠 | 悬浮窗 | 无边框 NSPanel + 序列帧 |
| 深链 | Intent filter | NSAppleEventManager / `open urls` |

Flutter 侧通过几个 MethodChannel 与 Swift 通信：`dsh/app`、`dsh/window`、`dsh/notify`、`dsh/files`、`dsh/media`、`dsh/voice`、`dsh/pet_overlay`、`dsh/links`。

---

## 三、本机引擎：不装 Linux，怎么在 Mac 上跑 DSH

### 3.1 运行时打包

`runtime/build-runtime-macos.sh` 负责把下面这些东西塞进一个 tar：

- Node **24.22.1**（darwin-arm64）
- `@deepseek-ai/dsh@0.2.1-rc.4`（含依赖）
- pnpm **11.28.5**
- `dsh-go-bridge`

产物约 **193 MB**，解包约 **742 MB**，放在 App 资源里。首次启动时复制、校验、解包到：

```
~/Library/Application Support/io.github.billwgong.dshgomac/runtime/
```

### 3.2 manifest 是契约

光有 tar 不够，旁边必须有一份 `manifest.json`：

```json
{
  "runtimeVersion": "macos-r1",
  "archiveSha256": "…",
  "archiveBytes": 201141759,
  "uncompressedBytes": 779841536,
  "dshVersion": "0.2.1-rc.4",
  "nodeVersion": "24.22.1",
  "launch": {
    "argv": ["{RUNTIME}/node/bin/node", "…/lib/bin.js", "{DSH_PROFILE_ARGS}",
             "--host", "127.0.0.1", "--port", "{PORT}", "--no-open"],
    "tokenLine": { "regex": "^dsh web: (http://127\\.0\\.0\\.1:[0-9]+/)\\?token=([A-Za-z0-9_-]+)" }
  }
}
```

App 读这份清单，校验 SHA-256，解包，按 `argv` 启动：

```
node …/bin.js web --patch …/dsh-web.patch.yml \
  --host 127.0.0.1 --port <空闲端口> --no-open
```

### 3.3 从 stdout 里拿 token

DSH 启动后会打印一行：

```
dsh web: http://127.0.0.1:54231/?token=…
```

App 解析这一行，用 `DshClient.connect(baseUri, token)` 登录，然后开始健康检查。退出时先 `SIGTERM`，超时再 `SIGKILL`，并留 pid 文件防止孤儿进程占端口。

### 3.4 为什么不用 Docker / 虚拟机

因为没必要。DSH 本身就是 Node 程序，macOS 的 arm64 Node 能直接跑；PRoot 那一层只是 Android 的权宜之计。把 Node 和依赖打进 App，用户点一次就能用，这才是桌面 App 该有的体验。

---

## 四、直连官方 DSH：不抢登录态

很多人已经装了官方 DeepSeek Harness。再让他在 DSH Go Mac 里装一份运行时、重新配模型，很烦。

所以我们做了"本地官方 DSH"模式：

1. 用 `lsof -nP -iTCP -sTCP:LISTEN` 找到官方进程监听的 `127.0.0.1:<port>`（官方端口每次启动都变）。
2. 读 `~/.dsh/.credentials.yaml` 里的 `client-connection/browser-session`，拿到 32 字节的签名密钥。
3. 在本地签一个浏览器 cookie：

```dart
payload = {version: 1, authority: "127.0.0.1:<port>",
           issuedAt: now, expiresAt: now + 30d}
body = b64url(json(payload))
sig  = b64url(HMAC-SHA256(secret, body))
cookie = DshCookie(
  name: "dsh-auth-" + b64url(sha256(authority)),
  value: "v1.$body.$sig",
  authority: authority,
)
```

4. `DshClient.connect(baseUri: base, cookie: cookie)`。

这样共享的是官方那份对话、模型和插件，但 **不修改官方数据**，也不用 SSH。切回"内置 DSH"时是完全独立的另一套数据目录：

- 官方：`~/.dsh`
- 内置：`~/Library/Application Support/io.github.billwgong.dshgomac/runtime/home/.dsh`

两套引擎可以同时存在，互不干扰。

---

## 五、手机反过来控制 Mac

这是我觉得最有意思的一块。

手机版 DSH Go 的 SSH 主机有一个约定：连上远端后，它会读 `~/.dsh-app-remote/` 里的四个文件，复用已经在跑的 `dsh web`，而不是再起一个：

- `web.pid`：进程号
- `web.st`：进程启动时间（用来防止 PID 复用）
- `web.cmd`：启动命令
- `web.log`：含 `token=` 的那行地址

所以 Mac 这边只要在内置引擎就绪时，把这四样写进去，手机就会直接接管这个引擎：

```dart
await File('${dir}/web.pid').writeAsString('${process.pid}');
await File('${dir}/web.st').writeAsString(psLstart(process.pid));
await File('${dir}/web.cmd').writeAsString('dsh web');
await File('${dir}/web.log').writeAsString('dsh web: $base?token=$token\n');
```

手机连上后走 SSH 本地转发到 `127.0.0.1:<port>`，带上 `Host` 头登录。它 **不会** 碰官方 DSH，因为握手文件只在"内置引擎"模式写；切到官方模式会主动删掉。

这里踩了一个非常隐蔽的坑：

> `ps -p <pid> -o lstart=` 的输出 **尾部有列宽空格**。我们一开始 `trim()` 了，写进 `web.st` 的值和手机端 `$(ps …)` 拿到的值差几个空格，`ours()` 判定失败，手机就以为进程不是自己的，删掉 pid 然后尝试自己起 `dsh web`——结果当然起不来。
>
> 修法：只去掉行尾换行，保留空格，做到字节级一致。

---

## 六、窗口与标题栏：和交通灯和平共处

macOS 的窗口标题栏是个麻烦。原版是手机布局，顶栏和系统标题栏会叠成两层；用了 `fullSizeContentView` 之后，内容又会跑到交通灯下面。

最后的策略是 **按版式切换**：

- **自适应**：`fullSizeContentView` + 透明标题栏 + 隐藏标题，交通灯和 App 顶栏合成一行；侧栏按钮整体下移，避开红绿灯。
- **竖屏版式**：恢复系统标题栏占位（隐藏标题、不透明材质），所有内容都在交通灯下方，任何页面都不可能重叠。

窗口拖动用 `performDrag(with:)`，由 Flutter 顶栏的空白区域触发。这比 `isMovableByWindowBackground = true` 安全——后者会让你在选文字时把窗口拖走。

---

## 七、三个真实踩坑（这一段最值钱）

### 坑 1：新建对话失败，因为 `/root/workspace`

新建会话时，如果没选工作区，代码会把 `localWorkspaceDir` 当 `cwd` 传给引擎。这个常量是 Android 的 `/root/workspace`。在 Mac 上：

```
failed to ensure project directory "/root/workspace":
  Error: ENOENT: no such file or directory, mkdir '/root'
```

用探针复现得很清楚：

```
FAIL cwd=/root/workspace
OK   cwd=/Users/billwgong
OK   cwd=null
```

修法：macOS 用 `$HOME`，其它平台保持 `/root/workspace`。路径显示和目录选择器里的 `localHome` 也一起改掉，否则界面还会显示 `/root`。

**教训**：移植不是换平台层就完了，**业务代码里藏着的平台假设**才是暗雷。

### 坑 2：CI 缓存只存 tar，不存 manifest

Release 的 DMG 发出去后，有人装完点"安装运行环境"直接失败。

原因：GitHub Actions 的缓存只缓存了 `runtime-arm64.tar.gz`，没缓存 `manifest.json`；而构建脚本只要看到 tar 在就跳过运行时生成。于是打出来的 App 里只有 tar、没有清单，安装时读不到 manifest。

修法三重保险：

1. 缓存路径加上 `manifest.json`；
2. 构建前检查 `test -f manifest.json || bash runtime/build-runtime-macos.sh`；
3. 打包脚本里加断言：App 内缺 tar 或 manifest 直接失败，绝不发布。

```bash
runtime_assets="$out/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/runtime-macos"
for f in runtime-arm64.tar.gz manifest.json; do
  [[ -f "$runtime_assets/$f" ]] || die "运行时不完整：缺少 $f"
done
```

### 坑 3：并发启动，旧进程把 `_process` 清空

自动启动可能从两个地方各触发一次 `start()`。原来的代码在几个 `await` 之后才设 `_starting = true`，于是两次启动都能穿过去；旧进程退出时又把 `_process` 置空，新进程的握手写入就被跳过了。

修法：

- `_starting` 在第一个 `await` **之前**占位；
- 进程的 stdout/exit 回调都先判断 `identical(_process, process)`，过期进程的事件一律忽略。

这类竞态不会稳定复现，但会在用户机器上偶发——所以修复时要顺手加身份判断，而不是只加锁。

---

## 八、怎么用（教程）

### 8.1 安装

从 [Releases](https://github.com/BillWGong/dsh-go-mac/releases/latest) 下 `dsh-go-mac-1.0.11-macos-arm64.dmg`，拖进 `Applications`。

未签名，首次打开右键 →「打开」，或：

```bash
xattr -dr com.apple.quarantine "/Applications/DSH Go Mac.app"
```

### 8.2 三种主机

- **本地 DSH · 自带**：App 内置 Node + DSH，点一下安装运行环境（约 750 MB）。
- **本地官方 DSH**：直接连正在运行的 DeepSeek Harness，共享它的对话和模型。
- **远程**：SSH / DSH Remote，和手机版一致。

### 8.3 手机连接 Mac

1. Mac：打开「系统设置 › 通用 › 共享 › 远程登录」。
2. App：切到「本地 DSH · 自带」，`设置 › 本机引擎 › 手机连接` 会列出 IP、用户名、端口和密码说明。
3. 手机：`切换主机 › 添加 SSH 主机`，填上面的地址、Mac 登录密码，启动命令保持默认 `dsh web`。
4. 手机会复用 Mac 上已经在跑的内置引擎，不会另起一个，也不会碰官方那份数据。

### 8.4 从源码构建

```bash
git clone https://github.com/BillWGong/dsh-go-mac.git
cd dsh-go-mac

bash runtime/build-runtime-macos.sh   # 生成内置运行时（约 2–5 分钟）
bash tooling/build-macos.sh --dmg     # 产出 .app 和 DMG
```

前置：完整 Xcode、Flutter 3.47.x、Apple Silicon、约 8 GB 空闲磁盘。

---

## 九、还没做的

- **Mac 操控**：原版"手机操控"依赖 Android 无障碍，Mac 上要换 AX + ScreenCaptureKit + MCP 工具 + 逐次审批，工作量不小。入口保留，显示"未就绪"。
- **应用内更新**：Mac 走 DMG，目前只检查版本，不自动安装。
- **Intel Mac**：运行时只做 arm64。
- **签名/公证**：目前是未签名构建。

---

## 十、最后

这是一个非官方社区项目，基于 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)（AGPL-3.0）和 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。

如果它帮你省掉了装 Linux 的麻烦，欢迎点个 star：

**https://github.com/BillWGong/dsh-go-mac**

有问题、有想补的功能，直接提 issue。

---

# 附：短版文案（V2EX / 小红书 / QQ 群）

> 把 Android 的 DSH Go 搬到了 Mac 上，已开源：
> https://github.com/BillWGong/dsh-go-mac
>
> - 不用装 Linux / Docker，App 内置 Node + DSH，点一下就能跑
> - 可以直接连本机官方 DeepSeek Harness，共享对话和模型
> - 手机版 DSH Go 加个 SSH 主机，就能反过来控制 Mac 上的内置引擎
> - 同一套 Flutter 界面，平台层全部 Swift 重写
>
> 踩坑记录：Android 的 `/root/workspace` 路径导致新建对话失败、CI 少缓存 manifest 导致装不上、并发启动竞态……文章里有完整复盘。
>
> 演示视频：https://www.bilibili.com/video/BV1njxJ6WE59/
> 求 star ⭐

---

# 附：发布建议

- **标题备选**
  1. 把 Android 客户端搬上 Mac：DSH Go Mac 移植实录
  2. 不装 Linux 虚拟机，在 Mac 上跑 DSH
  3. 同一套 Flutter，重写整条平台层：DSH Go Mac 架构与踩坑
  4. 手机反过来控制 Mac：一次真实的跨端移植
- **平台**：掘金 / V2EX（分享创造）/ Linux.do / 少数派 / 知乎；短视频同步 B 站。
- **标签**：macOS、Flutter、Swift、DeepSeek、客户端移植、独立开发。
- **封面**：DSH Go Mac 聊天界面 + 交通灯与顶栏合并的特写，标题压一行"不装 Linux 也能跑"。

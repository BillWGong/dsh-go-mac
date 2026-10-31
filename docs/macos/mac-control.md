# Mac 操控：把「手机操控」换成 macOS 等价能力

> 产品名：**DSH Go Mac**。

> 状态：设计稿。Android 的「手机操控」是本次移植里唯一没有落地的功能，入口保留、页面显示
> 「未就绪」。这份文档说明 Mac 上等价的实现方式，供下一阶段开发使用。

## 1. 原版是什么

Android 版让引擎里的模型「看屏幕、点按、输入」：

```
DSH 引擎（手机里的 Linux）
  └─ MCP server `phone`（relay，stdio）
       └─ 本机 TCP + token ──► App 的 PhoneControl（Kotlin）
                                  ├─ AccessibilityService：读屏、点按、输入、返回、通知
                                  ├─ MediaProjection：截屏
                                  ├─ 包名白名单 / 敏感词 / 逐次确认
                                  └─ 不打扰模式（Shizuku / ADB 提供 shell 身份）
```

模型侧看到的是 `mcp__phone__*` 工具；App 侧决定每个动作要不要先问人。

## 2. Mac 上对应什么

| Android | macOS |
| --- | --- |
| AccessibilityService（读屏、点按） | 辅助功能授权 + `AXUIElement`（读控件树、`AXPress`）+ `CGEvent`（真实鼠标/键盘） |
| MediaProjection 截屏 | ScreenCaptureKit（macOS 12.3+）/ `CGWindowListCreateImage`（旧） |
| 应用列表 | `NSWorkspace.shared.runningApplications` |
| 通知读取 | 不提供（macOS 无公开接口，需用户授权「通知」读取，风险高，默认不做） |
| Shizuku / ADB（不打扰模式） | 不适用：直接丢弃这两个入口 |
| 返回键 / 最近任务 | `CGEvent` 发送 `⌘[` / `⌘Tab` 等，不模拟 Android 语义 |

**权限**（缺一不可）：

1. 辅助功能：`AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`。
2. 屏幕录制：`CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`，或首次
   ScreenCaptureKit 抓帧时由系统弹窗。
3. 自动化（可选）：只对别的 App 发 AppleEvent 时才要，能不用就不用。

## 3. 传输与协议

沿用原版的分层，换掉传输两端：

```
DSH 引擎
  └─ runtime/phone/mac-relay.mjs（MCP stdio server，随运行时打包）
       └─ POST http://127.0.0.1:<port>/tool   （Bearer <token>）
            └─ App 的 MacControlServer（Swift, Network.framework）
                 └─ AX / ScreenCaptureKit / CGEvent
```

- 端口：App 启动时绑 `127.0.0.1:0` 取随机端口；token 每次启动随机 32 字节。
- 配置：写到 `~/Library/Application Support/<bundle id>/runtime/etc/dsh-app/mac-control.json`
  （0600），launch overlay 里给 MCP server 传 `MAC_CONTROL_URL` / `MAC_CONTROL_TOKEN`。
- 工具（与 Android 同名同参，减少模型侧差异）：
  `screenshot`、`tap`、`swipe`/`scroll`、`type`、`key`、`back`、`home`、`apps`、
  `open_app`、`window_list`、`wait`。
- 返回：`{ok, data?, error?, needsApproval?}`；所有动作有超时与幂等键。

## 4. 审批与安全

原版最值得保留的是「动作前先问人」：

- **只读**（`screenshot`、`apps`、`window_list`）：首次授权后放行，界面显示「正在看屏幕」。
- **会改变状态**（`tap`、`type`、`key`、`open_app`）：每次确认，或本次会话内允许；确认框
  必须显示目标窗口标题和动作摘要。
- **敏感内容**：输入框里出现密码/验证码时一律交给用户（沿用 `SensitiveWords` 的规则表，
  搬到 Swift）。
- **审计**：最近 200 条动作在「设置 › 手机操控」可见，可随时停止。

## 5. 与 `dsh/phone` 通道的映射

Dart 侧不用改，只要 Swift 实现同一份 `dsh/phone` 方法集合：

| 方法 | Mac 上的含义 |
| --- | --- |
| `status` | 辅助功能/屏幕录制授权、服务就绪、当前前台 App |
| `start` / `stop` | 开/关 MCP 工具与本地服务 |
| `requestPermission` / `openSettings` | 打开「隐私与安全性 › 辅助功能 / 屏幕录制」 |
| `apps` / `policies` | 运行中的 App；白名单沿用「只允许列表里的 App」 |
| `log` | 审计环形缓冲 |
| `events` | 动作开始/结束/等待确认 |

`shizuku` / `adb` / `battery` 等字段返回「不适用」，页面自动隐藏。

## 6. 工作量与顺序

1. `MacControlServer` + 权限状态 + `dsh/phone` 的 status/start/stop（约 400 行 Swift）。
2. `mac-relay.mjs` + overlay 注入（约 250 行 JS），先做 `screenshot` / `tap` / `type`。
3. 审批 UI 接现有 `user-approval` 组件，敏感词与白名单。
4. 审计、日志、停止按钮。
5. 端到端测试：授权 → 截屏 → 点按按钮 → 读回窗口标题。

第 1、2 步可以独立验证（不需要模型）；第 3 步之后要和 `dsh web` 一起跑。

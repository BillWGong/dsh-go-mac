# Mac 操控：Peekaboo（仅 macOS 15+）

> 产品名：**DSH Go Mac**。

## 结论

Mac 操控的执行层直接使用 [Peekaboo](https://github.com/openclaw/Peekaboo)，不自研 AX/CGEvent
控制层。Peekaboo 以 CLI + MCP 的形式随 App 分发：

- **macOS 15+**：设置里可以开启 Mac 操控；引擎启动时注册 `peekaboo mcp`。
- **macOS 12–14**：页面显示「未就绪」，不启动 helper，也不注册 MCP。

这样做的原因：Peekaboo 是 MIT 许可、Swift 原生、已有成熟的截图/Accessibility/点击/输入/窗口/菜单
能力；自研等价层需要维护大量 AX 细节和后台输入边界。代价是 Peekaboo 官方发布包最低要求
macOS 15，无法在 12–14 上使用。

## 架构

```
DSH 引擎（bundled runtime）
  └─ @deepseek-ai/dsh-mcp-client（stdio）
       └─ Peekaboo helper: peekaboo mcp
            └─ Screen Recording + Accessibility + Event Synthesizing
```

- 不经过自建 HTTP relay；工具直接来自 Peekaboo，模型侧名字是 `mcp__peekaboo__*`。
- helper 以 `app/macos/Resources/peekaboo/` 随 `.app` 分发，不进入 Flutter assets，避免 Android
  APK 也跟着变大。
- 首次在设置页开启时，Swift 把 helper 复制到
  `~/Library/Application Support/io.github.billwgong.dshgomac/peekaboo/`，保留 Peekaboo 自己的
  签名；helper 由 App 启动，macOS 的 TCC 提示显示为 **dsh_go / DSH Go Mac**，权限也记在它名下。
- `mac-peekaboo.json`（0600）记录是否开启。`macLaunchOverlay` 只有在 macOS 15+、已开启且 helper
  存在时才插入 MCP entry。

## 设置行为

### macOS 15+

设置 → Mac 操控：

- 开关：写配置后重启本机引擎，让 MCP entry 挂载/移除。
- 权限：Screen Recording、Accessibility、Event Synthesizing；按钮调用
  `peekaboo permissions request ...` 并打开对应系统设置页。
- 显示 Peekaboo 版本和 helper 状态。
- 只暴露后台安全工具；不传 `--allow-foreground`：
  `see`、`app`、`window`、`menu`、`click`、`type`、`set_value`、`action`、`scroll`、`press`、
  `verify_state`、`sleep`。
- 禁用 `shell`、`browser`、`agent`、`dialog_*`、`capture`、`paste`、`clipboard`。
- 直接使用 Peekaboo 不提供 DSH 的逐次点击确认；页面明确写「不逐次确认」，并说明权限授予
  DSH Go Mac（dsh_go）。

### macOS 12–14

`dsh/mac_peekaboo` 的 `status` 返回 `supported=false`，页面显示现有的
「这个版本里，Mac 操控模块还没有就绪」。不执行 helper、不请求权限、不注册 MCP。

## 打包与升级

- 固定 Peekaboo **4.9.8**，只取 `peekaboo-macos-arm64.tar.gz`；`tooling/fetch-peekaboo.sh`
  下载并校验固定 SHA，输出到 `app/macos/Resources/peekaboo/`。
- 当前仓库已带该 binary 与 `libswiftCompatibilitySpan.dylib`、LICENSE、VERSION；构建脚本把它们
  复制到 `.app/Contents/Resources/peekaboo/`。
- 升级 Peekaboo 时更新脚本里的版本和 SHA，重新生成资源，并在 macOS 15+ 实机上验证权限和
  `mcp__peekaboo__*` 工具。
- 许可：MIT，Copyright (c) 2025 Peter Steinberger；见 `THIRD_PARTY_NOTICES.md`。

## 验证

1. macOS 15+：开启设置 → 授权三个权限 → 确认引擎日志里出现 `mcp-peekaboo` 且工具可列。
2. 模型调用 `mcp__peekaboo__see`、`click`、`type`、`verify_state`。
3. 关闭开关 → 引擎重启 → 工具消失，Peekaboo daemon 停止。
4. macOS 14：页面显示未就绪；没有 Peekaboo 进程和 MCP 工具。
5. App bundle 内 helper 与固定版本一致，MIT 声明和 license 页存在。

## 已知限制

- 直接 MCP 是后台模式；不提供逐次确认、悬浮条、动作日志和敏感词审批（这些是 Android 手机操控的
  产品层，不是 Peekaboo 的 MCP 能力）。
- 密码管理器、银行/支付类 App、系统设置/钥匙串等高风险目标不在产品放行范围；需要后续用
  Peekaboo 工具策略或额外代理做更细的白名单。
- helper 升级或重新签名可能导致 macOS 要求重新授权。
- macOS 12–14 没有 Mac 操控。

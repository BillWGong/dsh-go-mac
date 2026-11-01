# DSH Go Mac 推广作战计划

> 诊断：仓库 124 次浏览 / 18 个独立访客 / 11 次下载 / 6 star。
> 结论：**没有触达**，不是内容不好。先把东西送到人眼前，再谈转化。

---

## 一、一句话定位（所有渠道统一）

> **Mac 上跑 DSH，不用装 Linux；手机还能远程连回来。**

三个钩子，按渠道选一个：

- 开发者向：**同一套 Flutter，整条平台层换成 Swift**
- 痛点向：**不装 Linux / Docker，点一下就能跑**
- 猎奇向：**手机反过来控制 Mac 上的 AI 客户端**

---

## 二、渠道优先级（按 ROI 排序）

### P0：DSH Go 现有社区（人已经在那）

1. **QQ 群（1285 人）**：先发 15 秒录屏 + 三句话，不要一上来甩长文。
2. **forum.dshtui.com**：发「分享」帖，标题带 macOS。
3. **上游仓库 Discussions / Issue**：礼貌地问一句能不能收录到 README 的「移植/生态」区。
4. **私信上游作者**：附视频 + 一句话，请他转发/群公告。这是最快的放大器。

### P1：V2EX「分享创造」

- 受众：独立开发者、Mac 用户，和你的目标高度重合。
- 关键：**标题 + 首屏两张 GIF**，正文控制在 500 字内，链接放最后。
- 时间：工作日 09:30–10:30 或 20:00–22:00。

### P2：B 站 / 小红书（视频优先）

- B 站：现有视频改标题、封面、简介、标签（见下）。
- 小红书：3:4 封面 + 15 秒竖屏剪辑，标题口语化，正文 5 行内。

### P3：掘金 / 知乎（长文）

- 长文是「可信度」而不是「流量」；等 P0/P1 有反馈后再发，文末导流。

### P4：海外（可选）

- r/macapps、r/FlutterDev、Show HN；需要英文 README + 英文短帖。

---

## 三、可直接复制的文案

### 3.1 QQ 群（短，先图后链接）

> 做了个 **Mac 版 DSH Go**，把 Android 那套界面搬过来了：
> 本机引擎不用 Linux 了，点一下就能跑；也能直接连你 Mac 上开着的官方 DSH；手机加个 SSH 主机还能反过来连它。
> 演示：https://www.bilibili.com/video/BV1njxJ6WE59/
> 仓库：https://github.com/BillWGong/dsh-go-mac
> 免费开源，有问题群里直接说。

### 3.2 forum.dshtui.com

**标题**：DSH Go Mac 1.0.11：把 DSH Go 搬到 macOS，不装 Linux

**正文**：

> 用 Flutter 把 Android 端的界面原样搬到了 macOS，平台层用 Swift 重写，本机引擎换成原生 Node（不再需要 PRoot / Ubuntu）。
>
> 目前能用的：
> - 本机引擎一键安装、启动、日志、安全模式
> - 直连本机官方 DeepSeek Harness（共享对话和模型，不用 SSH）
> - 切换主机：自带 / 官方 / 远程（SSH、DSH Remote）
> - 手机版 DSH Go 通过 SSH 复用 Mac 的内置引擎
> - 系统通知、文件、PDF、语音、桌宠、深浅色、竖屏版式
>
> 还没做：Mac 操控、应用内更新、Intel、签名。
>
> 仓库：https://github.com/BillWGong/dsh-go-mac
> 演示：https://www.bilibili.com/video/BV1njxJ6WE59/

### 3.3 V2EX「分享创造」

**标题**：把 Android 的 DSH Go 移植到了 macOS，不装 Linux，手机还能连回来

**正文**：

> DSH Go 是 Android 上的 DeepSeek Harness 客户端。我把它搬到了 Mac：
>
> - 界面不重写，继续用上游 Flutter 代码
> - 平台层 Kotlin → Swift（窗口、通知、文件、PDF、语音、桌宠）
> - 本机引擎从 PRoot + Ubuntu 换成原生 Node 24 + DSH，点一下就能跑
> - 可以直接连这台 Mac 上正在运行的官方 DSH，共享对话和模型
> - 手机版 DSH Go 加一个 SSH 主机，就能复用 Mac 的内置引擎
>
> 踩过的坑：Android 的 `/root/workspace` 导致新建对话 `ENOENT mkdir '/root'`；CI 只缓存 tar 不缓存 manifest，发出去的包装不上引擎；并发启动竞态导致握手文件不写。
>
> 未签名，首次打开要右键 →「打开」。只做 Apple Silicon / macOS 12+。
>
> 仓库：https://github.com/BillWGong/dsh-go-mac
> 视频：https://www.bilibili.com/video/BV1njxJ6WE59/

### 3.4 小红书

**标题**：把 AI 客户端装进 Mac，手机还能远程接管它

**正文**：

> 把 Android 上的 DSH Go 搬到了 MacBook 上✨
> 不用装 Linux、不用开虚拟机，点一下就能跑。
> 最爽的是：手机加个 SSH 主机，就能反过来连 Mac 上的引擎。
> 界面和手机版一模一样，通知、语音、桌宠都有。
> 开源免费，Mac 用户可以直接下👇
> #macOS #AI工具 #独立开发 #效率工具

### 3.5 B 站（改标题/简介/标签）

- **标题**：不用装 Linux！在 Mac 上跑 DSH 客户端（手机还能连回来）
- **封面**：聊天界面 + 红绿灯与顶栏合并特写，压字「不装 Linux 也能跑」
- **简介**：项目地址 + 三种主机 + 手机连接步骤 + 首次打开右键说明
- **标签**：macOS、Flutter、AI、DeepSeek、客户端、独立开发

### 3.6 上游仓库（礼貌询问）

> Hi，我把 DSH Go 移植到了 macOS（Flutter 界面复用，平台层 Swift，本机引擎原生 Node）：
> https://github.com/BillWGong/dsh-go-mac
> 如果合适，能否在 README 的生态/移植区加一行？也欢迎在群里转一下，感谢！

---

## 四、七天节奏

| 天 | 动作 |
| --- | --- |
| D1 | QQ 群 + 私信上游作者；forum 发帖 |
| D2 | V2EX 分享创造（配 2 张 GIF） |
| D3 | B 站改标题/封面；小红书发竖屏剪辑 |
| D4 | 掘金发技术长文（docs/blog/dsh-go-mac.md） |
| D5 | 收集反馈，修 1–2 个高频问题，发 1.0.12 |
| D6 | 发「更新日志 + 用户反馈」二帖，形成二次曝光 |
| D7 | 汇总数据，决定是否投海外 |

---

## 五、素材清单（比文案更重要）

1. **15 秒 GIF/视频**：启动 → 安装引擎 → 聊天 → 手机连上 Mac。
2. **两张对比图**：Android/PRoot vs Mac 原生；标题栏合并前后。
3. **安装三步图**：下载 DMG → 右键打开 → 选「本地 DSH · 自带」。
4. **README 首屏 GIF**：现在 README 没有动图，这是最大的转化损失。

---

## 六、转化优化（看了之后愿意装）

- README 顶部加 GIF + 「已有官方 DSH？跳过 750 MB 运行时」。
- 提供 `brew install --cask`（可信度 + 分发）。
- 首次打开说明做成图，不要只写一行命令。
- Release 页放 SHA256 和「未签名」说明。
- 英文 README（为海外渠道准备）。

---

## 七、现实预期

DSH Go 本身是垂直工具，Mac 移植是「垂直中的垂直」。目标不应该是全网爆款，而是：

1. 让 DSH Go 社区里 **10% 的 Mac 用户**知道并试用；
2. 拿到 20–50 个真实反馈；
3. 用反馈迭代出 1–2 个「非它不可」的功能（Mac 操控 / 手机无缝接管）。

有这三点，下一波才有得推。

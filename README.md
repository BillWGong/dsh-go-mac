<div align="center">

<h1>DSH Go Mac</h1>

<p><b>把「运行」当成界面。</b><br/>
DeepSeek Harness 的 macOS 客户端。同一个引擎，零迁移。</p>

<p><a href="https://github.com/BillWGong/dsh-go-mac/releases/latest"><b>下载 DMG</b></a> ·
<a href="https://github.com/BillWGong/homebrew-tap">brew install --cask BillWGong/tap/dsh-go-mac</a> ·
<a href="https://www.bilibili.com/video/BV1njxJ6WE59/">演示视频</a> ·
<a href="https://billwgong.github.io/dsh-go-mac/">主页</a> ·
<a href="README.en.md">English</a></p>

</div>

<p align="center"><img src="docs/images/demo.gif" alt="DSH Go Mac 真实录屏：思考、工具调用、运行详情" width="100%"></p>

<p align="center"><sub>真实录屏，没有加速。一个需要工具调用的任务，从思考到运行详情。</sub></p>

> [!NOTE]
> 非官方社区项目，与 DeepSeek 无隶属关系。界面来自 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)（AGPL-3.0），平台层以 Swift 重写。归属见 [NOTICE](NOTICE)。

---

## 它是什么

一个 macOS 客户端，连你现有的 DeepSeek Harness，或者用 App 内置的 Node + DSH 引擎。

它不换引擎，只把**一轮任务的全貌**放到你面前：用时、步骤、改动文件；轨迹、改动、文件、进度、上下文。点「改动」就是 diff，点「轨迹」回看每一步。

![运行详情](docs/images/run-detail.jpg)

## 三个不同

**运行是一等公民。** 聊天流擅长读，不擅长看。审批和提问从消息里浮出来，不藏在第 40 条后面。

**同一个引擎，零迁移。** 首次启动检测本机官方 DSH；连上后读的还是 `~/.dsh`，对话、模型、插件原样都在。也可以切到内置引擎，或远程 SSH / DSH Remote。

![连接官方 DSH](docs/images/official-mode.jpg)

**原生，不是套壳。** Flutter 界面 + Swift 平台层 + 原生 Node。没有 Electron，没有内嵌浏览器。通知上的「允许 / 拒绝」是真的系统通知。

## 安装

```bash
# 一条命令（推荐）
brew install --cask BillWGong/tap/dsh-go-mac

# 或者下载 DMG（Apple Silicon / macOS 12+）
open https://github.com/BillWGong/dsh-go-mac/releases/latest
open "/Applications/DSH Go Mac.app"

# 未签名构建被 Gatekeeper 拦住时
xattr -dr com.apple.quarantine "/Applications/DSH Go Mac.app"
```

首次启动：

- **已在用官方 DSH** → 选「连接官方 DSH · 推荐」，不装运行时
- **想用内置引擎** → 选「本机」，安装约 750 MB 运行时
- **连远程** → 选「远程主机」

## 状态

| | |
| :--- | :--- |
| ✅ 可以日常用 | 本机引擎、官方直连、远程、通知审批、文件/PDF/语音、桌宠、手机连接、分享卡 |
| 🚧 还没做 | Mac 操控（[设计稿](docs/macos/mac-control.md)）、应用内更新、签名/公证 |
| ❌ 不做 | Intel Mac、Windows |

<details>
<summary><b>常见问题</b></summary>

**和官方客户端是什么关系？** 同一个引擎的另一个客户端。连官方时共用对话、模型和插件，不迁移数据。

**为什么 App 255 MB，还要 750 MB？** App 自带 193 MB 压缩的 Node + DSH 运行时；首次用内置引擎才解包。只用官方模式可以不装。

**SSH 主机保存失败？** 1.0.16 起远程密钥改用 0600 文件存储（ad-hoc 签名没有 Keychain entitlement），路径在 `~/Library/Application Support/io.github.billwgong.dshgomac/remote-secrets.json`。

**删除对话入口不见了？** 需要内置运行时 `macos-r2`。老用户在 `设置 › 本机引擎` 重新安装一次运行时（可保留对话）；官方模式不支持删除。

</details>

<details>
<summary><b>从源码构建 / 测试</b></summary>

```bash
git clone https://github.com/BillWGong/dsh-go-mac.git
cd dsh-go-mac
bash runtime/build-runtime-macos.sh
bash tooling/build-macos.sh --dmg

cd app
flutter analyze
flutter test test/macos
flutter test test/chat test/state
```

需要完整 Xcode、Flutter 3.47.x、Apple Silicon、约 8 GB 磁盘。
</details>

---

## 许可

AGPL-3.0。基于 [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)，引擎是 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)。归属见 [NOTICE](NOTICE)。

<div align="center">

**如果它让你少翻几次聊天记录，点个 star 就够了 ⭐**

</div>

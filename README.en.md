<div align="center">

<h1>DSH Go Mac</h1>

<p><b>Treat the run as the interface.</b><br/>
A macOS client for DeepSeek Harness. Same engine, no migration.</p>

<p><a href="https://github.com/BillWGong/dsh-go-mac/releases/latest"><b>Download DMG</b></a> ·
<a href="https://github.com/BillWGong/homebrew-tap">brew install --cask BillWGong/tap/dsh-go-mac</a> ·
<a href="https://www.bilibili.com/video/BV1njxJ6WE59/">Demo</a> ·
<a href="https://billwgong.github.io/dsh-go-mac/">Site</a> ·
<a href="README.md">简体中文</a></p>

</div>

> [!IMPORTANT]
> **Star the original project first: [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)**
>
> This repo is only a port. Without the original DSH Go, DSH Go Mac would not exist. Do it now — it is the least this work deserves.
>
> [![Star the original](https://img.shields.io/github/stars/ccch1mneyyy/dsh-go?style=for-the-badge&logo=github&label=STAR%20THE%20ORIGINAL)](https://github.com/ccch1mneyyy/dsh-go)


<p align="center"><img src="docs/images/demo.gif" alt="DSH Go Mac screen recording: thinking, tool calls, run details" width="100%"></p>

<p align="center"><sub>A real recording, no speed-up. One tool-using task, from thinking to run details.</sub></p>

> [!NOTE]
> Unofficial community project, not affiliated with DeepSeek. The UI comes from [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go) (AGPL-3.0); the platform layer is written in Swift. See [NOTICE](NOTICE).

---

## What it is

A macOS client that attaches to your existing DeepSeek Harness, or runs the bundled Node + DSH engine inside the app.

It doesn't replace the engine. It puts **the whole run** in front of you: time, steps, changed files; trace, diff, files, progress, context. Diff opens the patch; trace replays every step.

![Run details](docs/images/run-detail.jpg)

## Three differences

**The run is a first-class object.** Chat is good at reading, bad at seeing. Approvals and questions rise out of the stream instead of hiding below message forty.

**Same engine, no migration.** On first launch it finds the official DSH on your Mac; it reads the same `~/.dsh`, with your chats, models and plugins already there. Or switch to the bundled engine, or a remote host over SSH / DSH Remote.

![Connect to official DSH](docs/images/official-mode.jpg)

**Native, not a wrapper.** Flutter UI + Swift platform layer + native Node. No Electron, no embedded browser. The “Allow / Deny” on a notification is a real system notification.

## Install

```bash
# One command (recommended)
brew install --cask BillWGong/tap/dsh-go-mac

# Or the DMG (Apple Silicon / macOS 12+)
open https://github.com/BillWGong/dsh-go-mac/releases/latest
open "/Applications/DSH Go Mac.app"

# If Gatekeeper blocks the unsigned build
xattr -dr com.apple.quarantine "/Applications/DSH Go Mac.app"
```

On first launch:

- **Already using the official DSH?** Pick “Connect to official DSH” — no runtime install
- **Want the bundled engine?** Pick “This Mac” and install the ~750 MB runtime
- **Remote?** Pick “Remote host”

## Status

| | |
| :--- | :--- |
| ✅ Daily-driver ready | Bundled engine, official attach, remote, notification approvals, files/PDF/speech, pet, phone link, share card |
| 🚧 Not yet | Mac control ([design](docs/macos/mac-control.md)), in-app updates, signing/notarization |
| ❌ Not planned | Intel Mac, Windows |

<details>
<summary><b>Questions</b></summary>

**How is this related to the official client?** Another client for the same engine. When attached, chats, models and plugins are shared; no data migration.

**Why 255 MB, and another 750 MB?** The app ships a 193 MB compressed Node + DSH runtime. The first bundled-engine run unpacks it. Official-only use skips it entirely.

**Saving an SSH host fails?** Since 1.0.16, remote secrets use a 0600 file (ad-hoc signing has no Keychain entitlement) at `~/Library/Application Support/io.github.billwgong.dshgomac/remote-secrets.json`.

**Where did “delete conversation” go?** It needs the bundled runtime `macos-r2`. Existing installs should reinstall the runtime from `Settings › Local engine` (keep conversations when prompted). Official mode does not support deletion.

</details>

<details>
<summary><b>Build & test</b></summary>

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

Full Xcode, Flutter 3.47.x, Apple Silicon, ~8 GB free disk.
</details>

---

## License

AGPL-3.0. Built on [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go); the engine is [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness). See [NOTICE](NOTICE).

<div align="center">

**The most important thing: star the original project → [ccch1mneyyy/dsh-go](https://github.com/ccch1mneyyy/dsh-go)**

If this port helped you too, star [this repo](https://github.com/BillWGong/dsh-go-mac) as well.

[![Star the original](https://img.shields.io/github/stars/ccch1mneyyy/dsh-go?style=for-the-badge&logo=github&label=STAR%20THE%20ORIGINAL)](https://github.com/ccch1mneyyy/dsh-go)

</div>

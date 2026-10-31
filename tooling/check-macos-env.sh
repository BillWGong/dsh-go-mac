#!/usr/bin/env bash
# macOS 移植的构建环境检查：缺什么、怎么补，一次说清楚。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ok=0; bad=0
pass() { printf '  ✓ %s\n' "$*"; ok=$((ok+1)); }
fail() { printf '  ✗ %s\n' "$*"; bad=$((bad+1)); }

echo "== 机器"
[[ $(uname -m) == arm64 ]] && pass "Apple Silicon ($(uname -m))" || fail "需要 Apple Silicon（当前 $(uname -m)）"
free=$(df -g "$ROOT" | awk 'NR==2{print $4}')
(( free >= 8 )) && pass "磁盘余量 ${free} GB" || fail "磁盘余量只有 ${free} GB（构建 + 运行时约需 8 GB）"

echo "== Xcode"
dev="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
if [[ "$dev" == *Xcode.app* ]]; then pass "xcode-select → $dev"; else fail "xcode-select 是 ${dev}（只有 CLT）"; fi
if xcodebuild -version >/dev/null 2>&1; then pass "$(xcodebuild -version | head -1)"; else
  fail "xcodebuild 不可用；App Store 装 Xcode 后：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi
[[ -d /Applications/Xcode.app ]] && pass "Xcode.app 已安装" || fail "还没有 /Applications/Xcode.app"

echo "== Flutter"
flutter_bin="${FLUTTER:-$(command -v flutter || true)}"
for candidate in "$ROOT/.tools/flutter/bin/flutter" "$ROOT/../.tools/flutter/bin/flutter" "$HOME/development/flutter/bin/flutter"; do
  [[ -z "$flutter_bin" && -x "$candidate" ]] && flutter_bin="$candidate"
done
if [[ -n "$flutter_bin" ]]; then
  pass "$("$flutter_bin" --version 2>/dev/null | head -1)"
else
  fail "找不到 flutter（PATH 或 FLUTTER=/path/to/flutter）"
fi

echo "== 运行时"
if [[ -f "$ROOT/app/assets/runtime-macos/runtime-arm64.tar.gz" ]]; then
  size=$(du -h "$ROOT/app/assets/runtime-macos/runtime-arm64.tar.gz" | cut -f1)
  pass "本机引擎运行时 $size"
else
  fail "还没有运行时：bash runtime/build-runtime-macos.sh"
fi

echo "== 其他"
command -v pod >/dev/null && pass "CocoaPods $(pod --version 2>/dev/null)" || echo "  · 没装 CocoaPods（当前插件都走 Swift Package Manager，暂时不需要）"

echo
echo "结果：$ok 项通过，$bad 项待处理"
(( bad == 0 ))

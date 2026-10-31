#!/usr/bin/env bash
# 构建 macOS 版 DSH Go（Apple Silicon）。
#
#   bash tooling/build-macos.sh              # release .app
#   bash tooling/build-macos.sh --dmg        # 再打一个 DMG
#   bash tooling/build-macos.sh --debug      # debug 构建
#
# 前置：
#   - 完整 Xcode（不是只有 Command Line Tools）：sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#   - Flutter 3.47.x（PATH 里有 flutter，或 FLUTTER=/path/to/flutter）
#   - 首次构建会自动生成 macOS 运行时（runtime/build-runtime-macos.sh，约 2–5 分钟）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/app"
mode=release
dmg=0

for arg in "$@"; do
  case "$arg" in
    --debug) mode=debug ;;
    --release) mode=release ;;
    --dmg) dmg=1 ;;
    -h | --help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "build-macos: 未知参数 $arg" >&2; exit 2 ;;
  esac
done

die() { echo "build-macos: $*" >&2; exit 1; }

# 1. Xcode：Flutter 的 macOS 目标用 xcodebuild，只有 Command Line Tools 不够。
#    装了 Xcode 但没 sudo xcode-select 切换时，用 DEVELOPER_DIR 指过去就行。
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "build-macos: xcodebuild 不可用（当前 $(xcode-select -p 2>/dev/null)）" >&2
  echo "  需要完整 Xcode：从 App Store 安装，然后任选其一：" >&2
  echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tooling/build-macos.sh" >&2
  echo "  首次安装后若提示需要组件/许可：sudo xcodebuild -runFirstLaunch && sudo xcodebuild -license accept" >&2
  exit 1
fi
echo "== Xcode $(xcodebuild -version | head -1)"

# 2. Flutter
if [[ -n "${FLUTTER:-}" ]]; then
  flutter="$FLUTTER"
elif command -v flutter >/dev/null; then
  flutter="$(command -v flutter)"
elif [[ -x "$ROOT/.tools/flutter/bin/flutter" ]]; then
  flutter="$ROOT/.tools/flutter/bin/flutter"
elif [[ -x "$ROOT/../.tools/flutter/bin/flutter" ]]; then
  flutter="$ROOT/../.tools/flutter/bin/flutter"
else
  die "找不到 flutter。装 Flutter 3.47.x，或用 FLUTTER=/path/to/flutter 指定"
fi

# 3. 运行时（首次）
if [[ ! -f "$APP/assets/runtime-macos/runtime-arm64.tar.gz" ]]; then
  echo "== 生成本机引擎运行时（首次约 2–5 分钟）"
  bash "$ROOT/runtime/build-runtime-macos.sh"
fi

# 4. 构建
cd "$APP"
"$flutter" pub get
"$flutter" build macos "--$mode"

out="$APP/build/macos/Build/Products/$(tr '[:lower:]' '[:upper:]' <<<"${mode:0:1}")${mode:1}/dsh_go.app"
[[ -d "$out" ]] || die "构建完成但没找到 $out"
echo
echo "App: $out"
echo "运行：open \"$out\""

# 5. 可选 DMG
if ((dmg)); then
  version="$(grep -m1 '^version:' "$APP/pubspec.yaml" | awk '{print $2}' | cut -d+ -f1)"
  target="$APP/build/macos/dsh-go-mac-$version-macos-arm64.dmg"
  rm -f "$target"
  stage="$(mktemp -d)"
  cp -R "$out" "$stage/"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname "DSH Go Mac" -srcfolder "$stage" -ov -format UDZO "$target" >/dev/null
  rm -rf "$stage"
  echo "DMG: $target"
fi

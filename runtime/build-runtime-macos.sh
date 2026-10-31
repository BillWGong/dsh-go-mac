#!/usr/bin/env bash
# 生成 macOS（Apple Silicon）本机引擎运行时包，供 DSH Go 的 Mac 版内置。
#
# 和 Android 版 runtime/build-runtime.sh 的差别：这里不需要 PRoot / Ubuntu rootfs。
# macOS 上直接用官方 Node darwin-arm64 跑 DSH 的 npm 依赖树，所以运行时 = Node + DSH + pnpm
# + dsh-go-bridge，总大小比 Linux rootfs 小，启动也快得多。
#
#   bash runtime/build-runtime-macos.sh              # arm64，输出到 app/assets/runtime-macos/
#   OUT=/path bash runtime/build-runtime-macos.sh    # 输出到别处
#   bash runtime/build-runtime-macos.sh --clean      # 丢掉缓存重新下载
#
# 产物：
#   app/assets/runtime-macos/runtime-arm64.tar.gz    （顶层目录 runtime/）
#   app/assets/runtime-macos/manifest.json           （版本、sha256、启动 argv）
#
# 缓存：runtime/.cache/macos/（Node 发行版、npm ci 出来的依赖树），可重复使用。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
CACHE="$HERE/.cache/macos"
WORK="$HERE/.work/macos"
OUT="${OUT:-$ROOT/app/assets/runtime-macos}"
STAGE="$WORK/stage"

DSH_VERSION="${DSH_VERSION:-0.2.1-rc.4}"
NODE_VERSION="${NODE_VERSION:-24.22.1}"
PNPM_VERSION="${PNPM_VERSION:-11.28.5}"

clean=0
for arg in "$@"; do
  case "$arg" in
    --clean) clean=1 ;;
    -h | --help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "build-runtime-macos: unknown argument $arg" >&2; exit 2 ;;
  esac
done

if [[ $(uname -m) != arm64 ]]; then
  echo "build-runtime-macos: 需要 Apple Silicon（当前 $(uname -m)）；Intel Mac 请把 NODE_ARCH 改成 x64 并自行验证。" >&2
  exit 1
fi

command -v node >/dev/null || { echo "build-runtime-macos: 需要 node（只用它跑 npm ci）" >&2; exit 1; }
command -v npm >/dev/null || { echo "build-runtime-macos: 需要 npm" >&2; exit 1; }

mkdir -p "$CACHE" "$WORK" "$OUT"
if ((clean)); then
  rm -rf "$CACHE" "$WORK"
  mkdir -p "$CACHE" "$WORK"
fi

say() { printf '\n== %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. Node darwin-arm64

NODE_DIR="$CACHE/node"
if [[ ! -x "$NODE_DIR/bin/node" ]]; then
  say "下载 Node $NODE_VERSION (darwin-arm64)"
  tar="$CACHE/node-v$NODE_VERSION-darwin-arm64.tar.gz"
  if [[ ! -f "$tar" ]]; then
    # 先国内镜像，再官方；两者内容相同。
    for url in \
      "https://npmmirror.com/mirrors/node/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.gz" \
      "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-darwin-arm64.tar.gz"; do
      if curl -fL --retry 2 -o "$tar.part" "$url"; then mv "$tar.part" "$tar"; break; fi
    done
    [[ -f "$tar" ]] || { echo "下载 Node 失败" >&2; exit 1; }
  fi
  tmp="$CACHE/node.tmp"
  rm -rf "$tmp" && mkdir -p "$tmp"
  tar -xzf "$tar" -C "$tmp" --strip-components=1
  rm -rf "$NODE_DIR" && mv "$tmp" "$NODE_DIR"
fi
"$NODE_DIR/bin/node" --version

# ---------------------------------------------------------------------------
# 2. DSH 依赖树（npm ci，锁文件固定在 runtime/locks/）

DSH_DIR="$CACHE/dsh"
if [[ ! -d "$DSH_DIR/node_modules/@deepseek-ai/dsh" ]]; then
  say "安装 DSH ${DSH_VERSION}（npm ci）"
  rm -rf "$DSH_DIR"
  mkdir -p "$DSH_DIR"
  cp "$HERE/locks/dsh-$DSH_VERSION/package.json" "$HERE/locks/dsh-$DSH_VERSION/package-lock.json" "$DSH_DIR/"
  (cd "$DSH_DIR" && HOME="$CACHE/home" "$NODE_DIR/bin/npm" ci --no-audit --no-fund --loglevel=error)
fi

# ---------------------------------------------------------------------------
# 3. pnpm（插件安装用）

if [[ ! -x "$NODE_DIR/bin/pnpm" ]]; then
  say "安装 pnpm $PNPM_VERSION"
  HOME="$CACHE/home" "$NODE_DIR/bin/npm" install -g "pnpm@$PNPM_VERSION" --prefix "$NODE_DIR" \
    --no-audit --no-fund --loglevel=error
fi

# ---------------------------------------------------------------------------
# 4. 组装

say "组装运行时"
rm -rf "$STAGE"
mkdir -p "$STAGE/runtime"
cp -R "$NODE_DIR" "$STAGE/runtime/node"
cp -R "$DSH_DIR" "$STAGE/runtime/dsh"
cp -R "$HERE/bridge/dsh-go-bridge" "$STAGE/runtime/bridge"
mkdir -p "$STAGE/runtime/etc/dsh-app" "$STAGE/runtime/home/.dsh" "$STAGE/runtime/tmp"
chmod 700 "$STAGE/runtime/home" "$STAGE/runtime/home/.dsh"

say "应用 dsh 补丁"
for diff in "$HERE"/patches/*.diff; do
  echo "  - $(basename "$diff")"
  patch --batch -N -s -p1 -d "$STAGE/runtime/dsh" <"$diff" || { echo "补丁失败：$diff" >&2; exit 1; }
done

cat >"$STAGE/runtime/etc/dsh-app/runtime.json" <<EOF
{
  "runtimeVersion": "macos-r1",
  "platform": "darwin-arm64",
  "dshVersion": "$DSH_VERSION",
  "nodeVersion": "$NODE_VERSION",
  "pnpmVersion": "$PNPM_VERSION",
  "bridgeVersion": "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$HERE/bridge/dsh-go-bridge/package.json")"
}
EOF

say "打包（gzip）"
archive="runtime-arm64.tar.gz"
rm -f "$OUT/$archive"
tar --no-xattrs -czf "$OUT/$archive" -C "$STAGE" runtime
bytes=$(stat -f%z "$OUT/$archive")
sha=$(shasum -a 256 "$OUT/$archive" | cut -d' ' -f1)
unpacked=$(du -sk "$STAGE/runtime" | cut -f1)

# ---------------------------------------------------------------------------
# 5. manifest.json

say "写 manifest"
python3 - "$OUT" "$archive" "$bytes" "$sha" "$((unpacked * 1024))" "$DSH_VERSION" "$NODE_VERSION" <<'PY'
import json, os, sys
out, archive, size, sha, unpacked, dsh, node = sys.argv[1:8]
manifest = {
    "runtimeVersion": "macos-r1",
    "abi": "arm64",
    "platform": "darwin-arm64",
    "archive": f"assets/runtime-macos/{archive}",
    "archiveBytes": int(size),
    "archiveSha256": sha,
    "uncompressedBytes": int(unpacked),
    "dshVersion": dsh,
    "nodeVersion": node,
    "launch": {
        "argv": [
            "{RUNTIME}/node/bin/node",
            "{RUNTIME}/dsh/node_modules/@deepseek-ai/dsh/lib/bin.js",
            "{DSH_PROFILE_ARGS}",
            "--host", "127.0.0.1",
            "--port", "{PORT}",
            "--no-open",
        ],
        "env": {},
        "profile": "web",
        "patch": "{RUNTIME}/etc/dsh-app/dsh-web.patch.yml",
        "tokenLine": {
            "regex": "^dsh web: (http://127\\.0\\.0\\.1:[0-9]+/)\\?token=([A-Za-z0-9_-]+)",
        },
    },
}
with open(os.path.join(out, "manifest.json"), "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print(json.dumps({k: manifest[k] for k in ("runtimeVersion", "archiveBytes", "dshVersion", "nodeVersion")}, indent=2))
PY

say "完成：$OUT/${archive}（$((bytes / 1048576)) MiB，解包 $((unpacked / 1024)) MiB）"

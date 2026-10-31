# macOS 本机引擎运行时（构建产物）

这个目录在构建前是空的（只有本说明和 `.gitkeep`）。`pubspec.yaml` 把整个目录声明为
Flutter 资源，运行时包由脚本生成：

```bash
bash runtime/build-runtime-macos.sh
```

生成后会有：

- `manifest.json`：版本、sha256、启动 argv
- `runtime-arm64.tar.gz`：Node 24 + DSH + pnpm + dsh-go-bridge，约 190 MB

两者都被 `.gitignore` 忽略：包太大，而且完全可以从 `runtime/locks/` 里的锁文件重建。
没有它们时 App 仍能构建和启动，只是「本机引擎」显示未安装。

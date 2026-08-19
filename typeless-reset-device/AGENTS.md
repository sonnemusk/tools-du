# Agent：重置 Typeless Device ID

读完直接执行。**只跑官方脚本，不要自己拼删除命令。**

## 做什么

在 macOS 上跑 `reset-device-macos.sh`，清掉本地设备编号和登录态。跑完用户重新登录即可。

## 怎么跑

### 有网络（默认）

下载到临时目录 → 执行 → 删掉临时目录：

```bash
set -euo pipefail
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/typeless-reset.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT
curl -fsSL \
  "https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh" \
  -o "$tmpdir/reset-device-macos.sh"
bash "$tmpdir/reset-device-macos.sh"
```

### 没网络

1. 让用户把脚本存到：`~/Tools/typeless-reset-device/reset-device-macos.sh`
2. 执行后删掉：

```bash
set -euo pipefail
SCRIPT="$HOME/Tools/typeless-reset-device/reset-device-macos.sh"
bash "$SCRIPT"
rm -f "$SCRIPT"
rmdir "$HOME/Tools/typeless-reset-device" 2>/dev/null || true
```

脚本下载页：https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh

## 执行前跟用户说一声

- 会退出当前登录，需要重新登
- Keychain 可能弹授权框
- 历史库和录音不会删
- 用来执行的脚本跑完会删掉，不留残留

## 可选环境变量

```bash
TYPELESS_APP_PATH="/path/to/Typeless.app" bash "$SCRIPT"   # App 不在默认位置
SKIP_LAUNCH=1 bash "$SCRIPT"                               # 不自动打开软件
```

## 跑完检查

```bash
cat "$HOME/Library/Application Support/now.typeless.desktop/device.cache"
```

Device ID 应变新；让用户重新登录。确认执行用的脚本已删除。

## 不要做

- 不要自己写清理步骤替代脚本
- 不要删 `typeless.db`、`Recordings/`
- 不要整份删 `app-storage.json`
- 脚本留在 Desktop / Downloads 等随意路径就去跑——只认临时目录或上面的指定路径

# Agent 执行说明：typeless-reset-device

面向 Agent / 自动化助手。读完本文件后直接执行。

**核心规则：只跑 GitHub 上的官方脚本，禁止自行发明或手搓清理步骤。**

## 目标

在 **任意 macOS** 上重置 Typeless 本地 Device ID，让服务端把当前机器当成新设备，从而避免：

```text
The number of users logged into this device has exceeded the limit.
```

本工具只做一件事：清掉本地设备编号和登录态。不碰历史库、录音。

## 何时使用

- 用户明确要求重置 Typeless 设备编号 / Device ID
- 同一台 Mac 换账号登录触发设备用户数超限
- 用户只要清登录态与设备标识

## 何时不要用

- 用户要求删除历史数据库或录音：本脚本故意不删
- 非 macOS 环境：直接拒绝并说明只支持 macOS
- **既没有网络，指定目录里也没有脚本**：停止执行，引导用户联网下载，或手动把脚本放到指定目录；**不要**根据本文清单自己敲删除命令凑合

## 获取与执行策略（必须遵守）

| 优先级 | 场景 | 做法 |
|--------|------|------|
| 1 | 有网络（默认） | 从 GitHub raw 下载到**临时目录** → 执行 → **删除临时目录** |
| 2 | 无网络 / 拉不下 GitHub | 让用户手动下载脚本，放到**指定目录** → Agent 执行 → **删除该脚本文件**（不留残留） |
| — | 以上都不满足 | **停止**。禁止手搓清理。 |

### 指定目录（离线投放点）

用户手动下载时，必须把脚本放到：

```text
~/Tools/typeless-reset-device/reset-device-macos.sh
```

完整 URL（给人看的下载页 / raw）：

- 目录：https://github.com/sonnemusk/tools-du/tree/main/typeless-reset-device
- Raw：https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh

硬性要求：

1. **禁止**根据「会清理」清单自行拼命令替代脚本。
2. **禁止**接受随意路径（如 Desktop / Downloads 里随便放的文件）；只认上面的指定路径，或本次 `mktemp` 临时文件。
3. 在线下载必须用 `mktemp` 临时目录；执行结束后 `rm -rf` 清掉整个临时目录。
4. 离线投放：执行结束后删除 `~/Tools/typeless-reset-device/reset-device-macos.sh`（若目录因此空了，可一并删掉空目录）。不要长期残留。
5. 脚本内容以 GitHub `main` 分支为准。
## 前置条件

| 项 | 要求 |
|----|------|
| OS | macOS（`uname -s` = `Darwin`） |
| Shell | bash |
| 网络 | 在线模式需要；离线模式可用「用户放到指定目录」代替 |
| 命令 | `curl`（在线）、`python3`、`security`、`pgrep`、`osascript`、`open`、`mktemp` |
| 软件 | 已安装 Typeless.app（可选；找不到也可以只清理，稍后手动打开） |
| Node.js | **不需要** |

路径均基于**当前用户** `$HOME`，不写死某台机器的用户名，因此换 Mac / 换账号也能跑。

## 会改动什么 / 不会动什么

（说明用途：让 Agent/用户理解副作用。**不是**让你照着手动删。）

**脚本会清理：**

1. 退出 Typeless（必要时强制结束进程）
2. `~/Library/Application Support/now.typeless.desktop/device.cache`
3. Keychain：`service=now.typeless.desktop.deviceIdentifier`，`account=now.typeless.desktop.security.auth_key`
4. `~/Library/Application Support/Typeless/user-data.json`
5. `app-storage.json` 中的 `userData`、`quotaUsage`（其余字段保留）
6. `Cookies`、`Cookies-journal`、整个 `Local Storage/`
7. 默认重新打开 Typeless

**不会动：**

- `typeless.db`
- `Recordings/`
- `app-settings.json`、`app-onboarding.json`

## 执行步骤（按顺序）

### 1. 告知用户副作用

开始前明确告诉用户：

- 当前 Typeless 登录态会被清掉，需要重新登录
- Keychain 删除时，系统可能弹出授权/密码框，需要用户点允许
- 历史和录音默认保留
- 将从 GitHub 临时下载脚本，执行完会删除，不留本地残留

若用户尚未确认，先确认再执行。

### 2. 拿到脚本 → 执行 → 删除

#### 方式 A（默认，有网络）

```bash
set -euo pipefail
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/typeless-reset.XXXXXX")"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

curl -fsSL \
  "https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh" \
  -o "$tmpdir/reset-device-macos.sh"

bash "$tmpdir/reset-device-macos.sh"
# trap 会在结束时删除临时目录
```

#### 方式 B（无网络：用户手动投放）

1. 告诉用户：请自行下载  
   `https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh`  
   保存为：

```text
~/Tools/typeless-reset-device/reset-device-macos.sh
```

2. 用户确认已放好后，再执行：

```bash
set -euo pipefail
SCRIPT="$HOME/Tools/typeless-reset-device/reset-device-macos.sh"
if [[ ! -f "$SCRIPT" ]]; then
  echo "指定目录没有脚本: $SCRIPT" >&2
  exit 1
fi
bash "$SCRIPT"
rm -f "$SCRIPT"
rmdir "$HOME/Tools/typeless-reset-device" 2>/dev/null || true
```

常用环境变量（加在 `bash ...` 前面）：

```bash
TYPELESS_APP_PATH="/custom/path/Typeless.app" bash "$SCRIPT"
SKIP_LAUNCH=1 bash "$SCRIPT"
```

脚本查找 Typeless.app 的顺序：

1. `$TYPELESS_APP_PATH`（若设置）
2. `~/Applications/Typeless.app`
3. `/Applications/Typeless.app`
4. Spotlight（`mdfind`）兜底

### 3. 确认脚本残留已清理

- 方式 A：`$tmpdir` 应不存在
- 方式 B：`~/Tools/typeless-reset-device/reset-device-macos.sh` 应不存在

**禁止**留下：

- `~/reset-device-macos.sh`
- `~/Downloads/reset-device-macos.sh`
- `~/Desktop/reset-device-macos.sh`
- 执行完仍留在指定目录里的脚本
### 4. 验收（必须做）

脚本跑完后检查：

```bash
# 1) 缓存里的新编号（启动后才会重新生成）
cat "$HOME/Library/Application Support/now.typeless.desktop/device.cache"

# 2) 钥匙串（可能弹授权框；优先看缓存）
security find-generic-password \
  -s "now.typeless.desktop.deviceIdentifier" \
  -a "now.typeless.desktop.security.auth_key" \
  -w

# 3) 登录密文应不存在（重新登录前）
test ! -f "$HOME/Library/Application Support/Typeless/user-data.json" && echo "user-data.json cleared"

# 4) app-storage 不应再含 userData / quotaUsage
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / "Library/Application Support/Typeless/app-storage.json"
d = json.loads(p.read_text()) if p.exists() else {}
print("userData" in d, "quotaUsage" in d)
PY
```

**成功标准：**

1. `device.cache` / Keychain 出现**与清理前不同**的新 UUID（软件启动后）
2. 目标账号登录不再报设备用户数超限
3. `typeless.db` 与 `Recordings/` 仍在
4. 用于执行的脚本文件/临时目录已被删除（无残留）

### 5. 向用户回报

简要汇报：

- 用的是方式 A（在线临时下载）还是方式 B（用户放到指定目录）
- 是否已删除执行用的脚本（无本地残留）
- 是否已退出 Typeless
- 清理前后 Device ID（若能读到）
- 是否已重新打开 Typeless
- 请用户在软件里重新登录

## 失败处理

| 现象 | 处理 |
|------|------|
| 无法访问 GitHub / curl 失败 | 改走方式 B：请用户手动下载到指定目录。**不要**手搓清理。清理已创建的临时目录 |
| 指定目录没有脚本 | 提示正确路径 `~/Tools/typeless-reset-device/reset-device-macos.sh`，等用户放好再跑 |
| 脚本报 Typeless still running | 让用户手动退出后，重新走方式 A 或 B（含执行后删除） |
| Keychain 命令失败 / 弹窗 | 让用户在弹窗授权；条目本就不存在可视为已干净 |
| 找不到 Typeless.app | 设置 `TYPELESS_APP_PATH`，或 `SKIP_LAUNCH=1` 只清理 |
| 重置后仍超限 | 确认进程已退出后重跑整套流程；核对 cache 与 Keychain **两处**都已是新编号 |
| 非 Darwin | 停止，说明仅支持 macOS |

## 硬约束

1. **只跑官方脚本**（在线临时下载，或用户放到指定目录）；禁止自行发明清理步骤。
2. **先退出软件，再删文件。**（由脚本完成；进程还在时脚本会失败退出）
3. **不要整份删除或覆盖 `app-storage.json`。**
4. **不要删除** `typeless.db`、`Recordings/`。
5. **不要**在 Device ID 读不到时伪造 `UNKNOWN`。
6. 不要把本机绝对用户名写死进命令；始终用 `$HOME`。
7. **执行结束后必须删除本次用来执行的脚本**，不留本地残留。

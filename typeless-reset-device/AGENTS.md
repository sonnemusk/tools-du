# Agent 执行说明：typeless-reset-device

面向 Agent / 自动化助手。读完本文件后直接执行，不要自行发明清理步骤。

## 目标

在 **任意 macOS** 上重置 Typeless 本地 Device ID，让服务端把当前机器当成新设备，从而避免：

```text
The number of users logged into this device has exceeded the limit.
```

本工具对应「路径 A：只换设备」。**不迁移**词典、历史、录音。

## 何时使用

- 用户明确要求重置 Typeless 设备编号 / Device ID
- 同一台 Mac 换账号登录触发设备用户数超限
- 用户只要清登录态与设备标识，不要动历史库和录音

## 何时不要用

- 还需要从**旧账号**导出云端词典：必须先导出，再跑本脚本；顺序反了会丢旧登录令牌
- 用户要求删除历史数据库或录音：本脚本故意不删
- 非 macOS 环境：直接拒绝并说明只支持 macOS

## 前置条件

| 项 | 要求 |
|----|------|
| OS | macOS（`uname -s` = `Darwin`） |
| Shell | bash |
| 命令 | `python3`、`security`、`pgrep`、`osascript`、`open`（均为系统自带或常见预装） |
| 软件 | 已安装 Typeless.app（可选；找不到也可以只清理，稍后手动打开） |
| 网络 | 不需要 |
| Node.js | **不需要** |

路径均基于**当前用户** `$HOME`，不写死某台机器的用户名，因此换 Mac / 换账号也能跑。

## 会改动什么 / 不会动什么

**会清理：**

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

### 1. 定位本目录

优先使用用户仓库中的副本：

```text
typeless-reset-device/reset-device-macos.sh
```

若在 GitHub：

```text
https://github.com/sonnemusk/tools-du/tree/main/typeless-reset-device
```

### 2. 告知用户副作用

开始前明确告诉用户：

- 当前 Typeless 登录态会被清掉，需要重新登录
- Keychain 删除时，系统可能弹出授权/密码框，需要用户点允许
- 历史和录音默认保留

若用户尚未确认，先确认再执行。

### 3. 运行脚本

在包含脚本的目录执行（推荐绝对路径）：

```bash
bash "/absolute/path/to/typeless-reset-device/reset-device-macos.sh"
```

常用环境变量：

```bash
# Typeless 不在默认位置时
TYPELESS_APP_PATH="/custom/path/Typeless.app" bash reset-device-macos.sh

# 只清理、不自动打开软件（适合远程/无人值守后再手动开）
SKIP_LAUNCH=1 bash reset-device-macos.sh
```

默认查找顺序：

1. `$TYPELESS_APP_PATH`（若设置）
2. `~/Applications/Typeless.app`
3. `/Applications/Typeless.app`
4. Spotlight（`mdfind`）兜底

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

### 5. 向用户回报

简要汇报：

- 是否已退出 Typeless
- 清理前后 Device ID（若能读到）
- 是否已重新打开 Typeless
- 请用户在软件里重新登录

## 失败处理

| 现象 | 处理 |
|------|------|
| 脚本报 Typeless still running | 让用户手动退出，或 `pkill -f Typeless.app` 后再跑 |
| Keychain 命令失败 / 弹窗 | 让用户在弹窗授权；条目本就不存在可视为已干净 |
| 找不到 Typeless.app | 设置 `TYPELESS_APP_PATH`，或 `SKIP_LAUNCH=1` 只清理 |
| 重置后仍超限 | 确认进程已退出后重跑；核对 cache 与 Keychain **两处**都已是新编号 |
| 非 Darwin | 停止，说明仅支持 macOS |

## 硬约束

1. **先退出软件，再删文件。** 进程还在时禁止清理。
2. **不要整份删除或覆盖 `app-storage.json`。** 只移除 `userData`、`quotaUsage`。
3. **不要删除** `typeless.db`、`Recordings/`。
4. **不要**在 Device ID 读不到时伪造 `UNKNOWN`。
5. 若用户还要迁词典：阻止「先重置再导出」；必须先导出旧账号数据。
6. 不要把本机绝对用户名写死进命令；始终用 `$HOME`。

## 一键命令（Agent 可直接跑）

在已克隆 `tools-du` 的机器上：

```bash
REPO_DIR="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || true)"
SCRIPT="$HOME/Tools/tools-du/typeless-reset-device/reset-device-macos.sh"
if [[ ! -f "$SCRIPT" ]]; then
  SCRIPT="$(pwd)/typeless-reset-device/reset-device-macos.sh"
fi
bash "$SCRIPT"
```

或从 GitHub 临时拉取后执行：

```bash
tmpdir="$(mktemp -d)"
curl -fsSL \
  "https://raw.githubusercontent.com/sonnemusk/tools-du/main/typeless-reset-device/reset-device-macos.sh" \
  -o "$tmpdir/reset-device-macos.sh"
bash "$tmpdir/reset-device-macos.sh"
```

# typeless-reset-device

在任意 macOS 上重置 Typeless 本地 Device ID，让服务端把当前机器当成新设备。

> **给 Agent：** 先读 [`AGENTS.md`](./AGENTS.md)。有网络时从 GitHub 临时下载脚本执行，跑完删除临时文件；禁止手搓清理，无网络则停止。

## 用法

```bash
bash reset-device-macos.sh
```

```bash
# Typeless 不在默认安装位置
TYPELESS_APP_PATH="/path/to/Typeless.app" bash reset-device-macos.sh

# 只清理，不自动打开软件
SKIP_LAUNCH=1 bash reset-device-macos.sh
```

## 可移植性

- 路径全部基于当前用户 `$HOME`，不绑定特定机器
- 依赖：`bash`、`python3`、`security`、`pgrep`、`osascript`、`open`
- **不需要** Node.js
- 会先退出 Typeless；软退出失败则强制结束进程，避免清不干净

## 脚本会做什么

1. 退出 Typeless（必要时强制结束）
2. 删除 `device.cache`
3. 删除 Keychain 中的设备编号
4. 删除 `user-data.json`
5. 清理 `app-storage.json` 的 `userData` / `quotaUsage`
6. 删除 Cookies 与 Local Storage
7. 默认重新启动 Typeless（可用 `SKIP_LAUNCH=1` 跳过）

运行后需要重新登录。历史库与录音默认保留。

## 来源说明

基于上游：

- https://github.com/estarpro1022/typeless-reset-device

相对上游的改动：

- 退出阶段增加强制结束与失败即退出
- `app-storage.json` 改用 `python3` 处理，去掉 Node 依赖
- 支持 `SKIP_LAUNCH`、`TYPELESS_APP_PATH`，并用 Spotlight 兜底查找 App

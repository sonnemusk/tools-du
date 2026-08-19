# typeless-reset-device

重置 Typeless（macOS）本地 Device ID，让服务端把当前机器当成新设备。

## 用法

```bash
bash reset-device-macos.sh
```

可选：自定义 App 路径

```bash
TYPELESS_APP_PATH="/path/to/Typeless.app" bash reset-device-macos.sh
```

## 脚本会做什么

1. 退出 Typeless（软退出失败则按 PID 强制结束）
2. 删除 `device.cache`
3. 删除 Keychain 中的设备编号
4. 删除 `user-data.json`
5. 清理 `app-storage.json` 中的 `userData` / `quotaUsage`
6. 删除 Cookies 与 Local Storage
7. 重新启动 Typeless

运行后需要重新登录。

## 来源说明

基于上游项目：

- https://github.com/estarpro1022/typeless-reset-device

本地相对上游的改动：

- 退出阶段增加强制结束与「杀不掉则报错退出」，避免进程还在时清理不干净。

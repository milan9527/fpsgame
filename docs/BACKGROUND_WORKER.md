# 后台目标任务

本机通过用户级 systemd 服务 `fpsgame-goal.service` 运行独立 Codex 进程。当前优先目标是 Android 稳定帧率。每轮读取 `docs/BACKGROUND_GOAL.md`，把开发进度写入 `docs/ANDROID_BACKGROUND_CHECKPOINT.md`，然后开启下一轮短会话。它不依赖浏览器或 SSH 连接。

运行依赖主机开机、网络和模型访问权限。临时调用失败后每 300 秒重试；进程异常由 systemd 重启。linger 已开启，用户退出登录仍继续运行。按用户要求服务保持 disabled，不设置开机启动；主机重启后需手动启动服务。机器关机期间不会开发。

每轮要求约20分钟保存检查点并返回；90分钟超时会终止该轮并重试，避免调用无限挂起。每次调用使用全新上下文，文件检查点承接工作，避免不断恢复过长历史。文件锁确保仅一个后台循环运行。

查看状态：

```bash
systemctl --user status fpsgame-goal.service
cat artifacts/background-goal/status
tail -n 35 docs/ANDROID_BACKGROUND_CHECKPOINT.md
```

每轮日志和结构化结果在 `artifacts/background-goal/`。

停止 / 恢复：

```bash
systemctl --user stop fpsgame-goal.service
systemctl --user start fpsgame-goal.service
```

只有任务报告完成且 `tools/check_android_acceptance.py` 重算真机帧时间通过后，才保存 `artifacts/background-goal/completed` 并退出。验收要求完整场景、单机和联网各3次至少300秒测试，平均≥58 FPS、p95≤20ms、p99≤33.4ms、超过50ms帧占比≤1%，以及APK校验、画面和功能审阅证据。脚本检查证据文件和数值，不能独立证明录像内容或测试真实性，后台开发者必须审阅原始证据。

该状态不会自动同步当前界面的 goal 状态，也不代表所有Android硬件绝对零掉帧。重新指定目标后，需要更新任务说明，并在确有完成标记时删除标记再启动服务。

未经用户确认禁止 GitHub 推送。手动编辑游戏前先停止服务，避免并发修改。

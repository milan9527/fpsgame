# Codex 上下文过长恢复

用户报告 `Input is too long`，并且 remote compact 同样失败。这表明服务端拒绝了过长输入；仅凭错误无法确定具体长度上限，也不能断言远端故障已修复。

如果当前聊天继续失败，新建会话，只发送：

> 继续 /home/ec2-user/project/fpsgame 的任务。先读 docs/CODEX_RESTART_BRIEF.md，检查现有后台 worker，避免重复启动。不要载入旧聊天全文。

不要通过 fork 复制出错聊天，也不要粘贴完整历史、整份日志或大量截图。交接文件保存进度，按需读取局部证据。

2026-09-14 本机核查：

- `fpsgame-goal.service` 为 `active/running`，`UnitFileState=disabled`：当前运行，未启用开机启动。
- `tools/background_goal.sh` 每轮启动新的 `codex exec`，没有 resume 历史会话。
- 提前压缩阈值 `model_auto_compact_token_limit=32000` 和工具输出限制 `tool_output_token_limit=4000` 已存在，本次没有修改。
- 后台进程与聊天界面分离；主机持续运行、进程和服务依赖正常时，界面断开不会直接结束该 worker。主机关机、凭据失效或服务错误仍可能影响执行。
- 本次没有重启任务、启动第二个 worker、推送代码或部署 AWS。

上述是检查时的状态，不是游戏目标完成证明，也不是后台永不失败的保证。

状态检查：

```bash
systemctl --user show fpsgame-goal.service -p ActiveState -p SubState -p UnitFileState -p MainPID
cat artifacts/background-goal/status
```

官方文档说明 `/compact` 用于压缩当前聊天，`/status` 查看上下文状态，`/fork` 会复制聊天。压缩请求自身已失败时，本项目采用精简文件交接到新会话的恢复方式；没有通过修改游戏代码修复远端聊天服务。

参考：https://learn.chatgpt.com/docs/reference/slash-commands#available-slash-commands

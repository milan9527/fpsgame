# Codex 输入过长恢复

2026-09-13 检查：Codex CLI 0.153.4。用户配置已设置
`model_auto_compact_token_limit = 32000` 和
`tool_output_token_limit = 4000`；项目没有覆盖配置。

本地日志还记录了旧会话自动压缩时的历史投影错误：
`failed to project durable rollout` / `thread history projection ... expected ordinal`。
这是独立的会话异常证据，尚不能确定它是服务端长度报错的直接原因。
不要通过删除数据库或手工截断会话文件修复。

从终端启动新的交互会话：

```bash
bash /home/ec2-user/project/fpsgame/tools/restart_codex_clean.sh
```

入口只传入简短提示，让新会话读取 `docs/CODEX_RESTART_BRIEF.md`，
不使用 resume/fork，也不改动已有游戏文件或历史会话。
脚本要求交互终端，并直接从终端读取输入，避免管道中的旧日志被附加到新提示中。
在 Codex CLI 输入 `/new` 新建会话，再输入“读取 docs/CODEX_RESTART_BRIEF.md，继续项目”。
不要使用 `/resume` 或 `/fork` 恢复这段过长的历史。其他 Codex 界面使用新建会话按钮。
旧会话仍可接收命令时可以先尝试 `/compact`；若失败，使用新会话。

配置解析和脚本检查不能证明上游服务端问题已解决；
需要新会话成功完成模型请求后确认恢复。
这些配置不能追溯缩短旧请求，也不能保证限制插件工具定义等所有输入。
本次增加独立短交接文件，避免恢复时一次加载不断增长的开发记录。

配置参考：https://developers.openai.com/codex/config-reference/
命令参考：https://developers.openai.com/codex/cli/slash-commands/

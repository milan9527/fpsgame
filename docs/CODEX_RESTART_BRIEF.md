# 精简恢复入口

项目：`/home/ec2-user/project/fpsgame`，Godot + Blender FPS 游戏。
当前最高优先级：解决 Android 掉帧，保留最新写实画面与单机/联网功能；性能尚未达标。
先读 docs/BACKGROUND_GOAL.md 与 docs/ANDROID_BACKGROUND_CHECKPOINT.md（如存在），
再按需读取 docs/ANDROID_PERFORMANCE_20260925.md 最后100行；旧画质微调任务不得抢占性能修复。
未经用户明确确认不得 push GitHub。保留所有已有未提交修改。
后台任务要求与界面分离运行，不设置开机启动。
先检查 `systemctl --user show fpsgame-goal.service -p ActiveState -p SubState -p MainPID -p UnitFileState`。
若现有 worker 正在运行，交互会话不要重复启动，也不要与它同时修改游戏文件。
由该服务启动的 worker 本身应继续开发；上述约束禁止第二个编辑者，不阻止唯一 worker。
后台运行状态必须实测；不要保证主机关机或凭据失效后仍能执行。

先检查 `git status --short`。详细进度按需从
`docs/CONTINUE_GAME.md` 最后 35 行读取；较早记录可能已被后续验证替代。
根据实际文件和日志确认状态，不把交接记录当作测试通过的证据。
上轮涉及人物、武器、草地模型和着色器；不要覆盖这些修改。

避免加载旧会话、整份日志、整个资源目录或大量图片。
文本查询限定范围和输出条数；日志先查询 PASS/FAIL/ERROR，再读相关小段。
每次只查看必要截图。任务进度保存到文件，长会话及时压缩。
若再次出现 `Input is too long`，新建会话并仅传入本文件路径；
不要 resume/fork 出错会话或粘贴完整聊天记录。

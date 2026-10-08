# 后台任务中断修复

核查时间：2026-09-16 23:51 UTC。

## 原因与当前状态

systemd 日志记录 03:57 和 11:36 两次 OOM kill（内存耗尽），均在约 60 秒后恢复。这两次中断有明确的内存原因，没有证据表明由交互界面断开直接触发。

服务 `fpsgame-goal.service` 当前为 `active/running`，主进程 2797282，本次维护没有重启开发进程。任务尚未完成。

## 已执行修复

- 创建 `/var/tmp/fpsgame-runtime.swap`，权限 0600，启用 8 GiB 交换空间以缓解内存峰值。未写入 `/etc/fstab`，重启机器后不会自动启用。
- 更新 `/home/ec2-user/.config/systemd/user/fpsgame-goal.service`，设置 `Restart=always`、`RestartSec=60`、`StartLimitIntervalSec=0`。非完成状态下，即使主进程正常退出也自动恢复。
- 添加 `ConditionPathExists=!/home/ec2-user/project/fpsgame/artifacts/background-goal/completed`，完成后停止自动启动。
- 执行 `systemctl --user daemon-reload`，新规则已生效，未中断正在执行的轮次。
- 保持服务 `disabled`（没有开机启动）；现有 `Linger=yes` 允许用户服务在退出登录后继续运行。
- 保留脚本的单实例文件锁、每轮独立 Codex 上下文、失败后 300 秒重试和结果检查。

## 验证

- systemd 单元校验通过；实际服务的恢复策略及状态核查通过。
- 使用独立临时测试服务验证：正常退出后会再次运行，写入完成标记后不再启动。验证通过，测试服务已移除，未操作开发工作进程。
- `swapon --show` 确认 8 GiB 交换空间已启用。
- 本地服务器 `http://127.0.0.1:8002/health` 返回 `status=ok`、协议 17、数据库版本 0004。

## 运行边界

界面关闭或 SSH 断开后，当前主机上的 systemd 服务仍可继续。交换空间降低内存耗尽风险，不能保证永不 OOM。主机停止/重启、磁盘满、凭据失效或上游服务长时间不可用仍会阻止实际开发进展；不能承诺这些情况下自动完成。

因用户要求不开机启动，主机重启后需要手动 `systemctl --user start fpsgame-goal.service`。没有 GitHub 推送，没有 CloudFormation 操作。

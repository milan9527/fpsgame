# 0.36.0-dev 运行服务升级

2026-09-12，发布 API、单人及双人专服、默认 Linux 包切换到 **0.36.0-dev / 协议 17 / ash-valley-18**。数据库仍为 0004。这是开发发行，完整商业级游戏目标尚未完成。

本版发布双座越野车、驾驶和乘坐、车体与乘员命中、空间发动机音频、载具存档、观战跟车及机器人平坦直线进圈驾驶。复杂绕行、倒车脱困、燃料补给、悬挂翻滚、完整协作 AI 和公网长期体验仍待完善。

## 运行入口

| 组件 | 地址或端口 |
|---|---|
| 发布 API | `http://127.0.0.1:8000` |
| 单人 / 双人专服 | UDP 27015 / 27022 |
| 独立开发 API / 双人专服 | 8001 / UDP 27031 |
| Linux 包 | `artifacts/IronMeridian-Linux-x86_64.tar.gz` |

解压后在 Linux x86_64 桌面运行 `./play.sh`，需要 OpenGL 3.3；离线 SOLO/DUO 无需账号。在线填写发布 API 地址。API 目前仅绑定本机，跨机器访问仍需按运维文档配置入口。服务保持 `restart: unless-stopped`；PostgreSQL 和 Redis 没有新增宿主端口或替换数据卷。

默认包与候选 `artifacts/candidates/0.36.0-dev-8245350d-mdczhhx9/` 一致，源提交 `8245350d`，63,196,528 字节，SHA-256：
`31357a83d0fcf6896cf8bc0c6acfa4b3c4c408528626f18f3afa4af169a54895`。
旧 0.35 包和运行目录保留于 `artifacts/releases/0.35.0-dev/`；旧客户端不能连接新协议服务。

## 切换与验证

`tools/publish_candidate.py` 检查房间无人、无有效预约、结果队列为空，保留旧包、镜像 ID 和最新数据库备份；停止两台旧专服并等待租约过期，使用验证过的 API 和专服镜像启动。切换前后 users、matches、results 全字段指纹一致。没有执行在线数据库降级或备份回灌。

专服镜像中的运行文件与候选包逐字节一致。API 镜像通过 95 项隔离集成测试；当前 0004 幂等启动及旧 0003 升级的隔离恢复演练均通过。候选另已通过 42 项包内规则、默认入口、实际渲染、车辆网络场景和两场正常时间自然对局；范围及限制见 [候选包记录](CANDIDATES.md)。

发布端口上，两个打包单人客户端通过移动、姿态、武器、手雷、菜单和预测同步检查；两个打包双人客户端通过邀请、准备、入场、返回和连续两轮重开。记录在 `artifacts/release-0.36.0-dev/`：

- `verification.json`：旧/新镜像、备份、数据指纹、房间及版本。
- `solo-clients.log`、`duo-requeue.log`：发布端口客户端验证。
- `post-release-restore.json`：切换后新备份的隔离恢复和统计完整性。

继续使用已验证镜像启动服务：

```sh
docker compose -f compose.yaml -f artifacts/release-0.36.0-dev/compose.override.json up -d --no-build
```

旧镜像 ID 和旧包作为回退材料保留。回退应先检查玩家、队列及新产生的数据；本次未向旧数据库快照自动回退。物理音频设备、公网长时间稳定性和完整商业级功能仍未验收完成。

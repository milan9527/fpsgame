# 双人组队开发记录

开发分支：`feature/duo-mode`。发布基线：`39d331e`（0.34 / 协议 15）。

**双人组队尚未发布，现有发布游戏包和发布后台服务仍为 0.34。不能将下面的后端进展称为已完成双人游戏。完整游戏 Goal 保持 active。**

## 已完成并验证的后端基础

- 房间心跳、匹配请求和入场票据支持 `mode: solo | duo`；缺省与旧 Redis 数据一律按单人处理。
- 分配在现有 Redis Lua 原子操作中按模式筛选，指定房间编号也不能绕过筛选。
- 票据绑定房间模式与专服消费声明。错误模式消费不会销毁有效票据。
- 双人房间容量必须为偶数。容量、玩家唯一预约、取消与代际约束继续生效。
- 同一回合不能修改模式；跨回合修改也必须先清空已连接玩家，防止无意迁移其玩法。
- 现有认证、会话撤销与验证错误隐私规则继续适用。

验证使用独立标签 `fpsgame-api-duo-dev`，未替换正式镜像或服务。`artifacts/duo-backend-tests.log`：34 项房间、会话、迁移和依赖故障测试通过，新增模式测试使用独立 Redis 前缀，HTTP 认证测试使用临时数据库。包含 40 个混合模式并发请求及真实 HTTP 模式传递/票据消费。

## 接下来的实现与验收

1. 已完成原生基础：服务器/单机模式、回合内队伍分配、机器人补齐和角色队伍快照；开发协议升级为 16。四真实客户端入场与队伍复制已通过，仍需后续完整战斗验收。
2. 实现队友伤害规则、倒地/流血/扶起、交互中断、整队淘汰和按队伍排名/获胜；机器人需要识别队友并参与扶起。保留真实物理、伤害和库存约束。
3. 接入客户端模式入口、队友状态、地图标记与队伍观战；提供明确的邀请/组队流程，避免仅能随机配对却宣称完整组队。
4. 将对局模式与队伍结果写入数据库和本地记录；处理现有单人检查点的兼容，验证旧数据不被错误解释为组队。
5. 至少四个真实客户端验证两队对局、扶起与中断、淘汰/获胜、战绩落库、断开与会话撤销；同时回归现有单人、保存、协议门禁和发行包。
6. 完成以上集成后再更新实际开发状态、发行包与持久专服配置。当前不向玩家暴露未完成的双人入口。

这些是组队功能的实施步骤，不替代原始完整游戏目标；载具、跳伞、更多内容与生产运营等其他未完成范围仍需继续推进。

## 原生队伍基础与隔离环境（未发布）

开发源码使用协议 16 / 0.35.0-dev；发布包仍为协议 15 / 0.34。原生对局已实现 16 角色分成 8 队、队友附近安全出生、友伤过滤（保留自伤）、机器人排除队友目标、整队排名和最后一队获胜。阵亡成员可随存活队友获得队伍排名。角色快照包含队伍；单人检查点仍使用原有字段。队伍战绩和队伍检查点暂不写入单人数据。

`artifacts/duo-team-rules.log`、`duo-solo-checkpoint.log`、`duo-solo-smoke.log` 记录原生队伍规则、旧存档及单人完整对局回归通过。倒地/扶起、邀请、队伍 UI、持久化尚待实现，这不是完整双人模式。

`tools/duo_dev.sh` 启动独立 Compose 项目 `fpsgame-duo`：API 仅监听本机 8001，双人专服 UDP 27031，数据库 `iron_duo`、Redis、数据卷及三项随机密钥均独立，容器使用 `unless-stopped` 重启策略。密钥文件 `artifacts/duo-dev.env` 权限 0600，不提交版本库。发布项目不变。

`artifacts/duo-environment-isolation.log` 验证两套服务协议不同、测试账号可重复登录、令牌不能跨环境使用；`artifacts/duo-dev-backend-tests.log` 记录独立开发环境内 34 项后端测试通过。

## 重跑开发验证

```bash
./tools/duo_dev.sh
docker compose --env-file artifacts/duo-dev.env -f compose.duo-dev.yaml run --rm --no-deps -v "$PWD/backend/tests:/app/tests:ro" api python -m pytest -q -p no:cacheprovider tests/test_rooms.py tests/test_sessions.py tests/test_migrations.py tests/test_availability.py
.venv/bin/python tools/test_duo_network.py
```

四客户端脚本仅验收真实鉴权入场、两个人类队伍和 8 队快照；完整战斗、扶起、战绩与退出验收仍须后续实现。

`artifacts/duo-network.log`：四真实客户端鉴权、模式通知、16 角色/8 队/2 人类队伍快照通过；`artifacts/duo-network-server.log` 确认四连接退出并释放房间。专服使用 `api.internal` 容器别名，避免 Godot HTTP 对过短主机名的限制。

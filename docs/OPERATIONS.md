# 运行与运维

## 启动和检查

```bash
./tools/setup.sh
docker compose ps
curl -f http://127.0.0.1:8000/health
docker compose logs --tail 50 api game game2
```

`setup.sh` 仅在 `.env` 不存在时生成三项随机密钥，并设置权限 0600。不覆盖已有凭据。容器自动重启策略为 `unless-stopped`。数据库、缓存和战绩队列均使用持久卷，日志按大小轮转。

```bash
# 重启服务，保留数据
docker compose restart
# 停止服务，保留卷
docker compose stop
# 再次启动
docker compose up -d
```

不要使用 `docker compose down -v`，除非明确要清空全部数据库与持久队列。

## 远程玩家接入

提供 `compose.public.yaml` 与 `infra/Caddyfile`，使用 Caddy 自动申请和续期公共 HTTPS 证书。部署需要已有域名，DNS 指向游戏主机；有 AAAA 记录时 IPv6 也须可达。先在现有 `.env` 增加 `PUBLIC_HOST`（仅 API 域名，不含协议/路径），并将 `GAME_PUBLIC_HOST` 设为玩家可达的游戏主机域名或 IP。不要覆盖现有凭据。

允许 TCP 80/443 用于证书签发及 HTTPS，UDP 27015/27022 用于游戏连接。API 与游戏主机可用同一域名；HTTP 反向代理不会转发 ENet UDP。房间公布的主机地址必须可被外部玩家访问。调整游戏环境变量会重建专服，应在房间无人且结果队列已排空时执行。

使用当前已验证的固定发布镜像，再叠加公网配置：

```bash
docker compose -f compose.yaml -f artifacts/release-0.38.0-dev/compose.override.json -f compose.public.yaml up -d --no-build
```

不要省略固定镜像 override，否则可能选到本地旧镜像标签。证书状态保存到 `edge_data`，配置状态保存到 `edge_config`，代理配置自动重启和日志轮转。客户端填写 `https://你的域名`。Caddy 服务端口不会映射管理 API，访问日志默认未启用。

API 默认仅绑定环回地址；数据库与 Redis 不对外开放。开发用 HTTP 不应直接作为公网账号入口。若仅通过本机测试或 SSH 隧道连接，可使用默认地址。

`tools/test_https_proxy.py` 已在独立临时 Caddy 容器内通过真实 API 的本机 HTTPS 检查，使用仅测试用的本地 CA，并严格校验证书链与 localhost 主机名；公开配置本身也通过 Caddy 校验。测试只读取 `/health`、`/protocol`，不登录、不改房间地址、不开放公网端口、不替换生产服务。报告 `artifacts/https-proxy-verification.json`。这不验证实际公共证书签发、DNS、防火墙或外部 UDP 可达性。当前公网代理尚未部署，等待明确域名。

## 备份

```bash
./tools/backup.sh
```

备份保存至 `artifacts/backups/`。PostgreSQL 使用一致性逻辑转储，另保存两个专服的战绩重试队列：`results.json` 与 `results-game2.json`。备份含账户哈希和游戏数据，目录权限为 0700、文件为 0600。新脚本先写唯一临时目录，全部命令成功且 JSON 队列可解析后才发布备份目录；`manifest.json` 记录格式版本、构建信息及各文件长度与 SHA-256。旧版无清单备份需要重新生成才能使用下面的自动演练。

运行以下命令对指定备份进行真实恢复演练：

```bash
python3 tools/restore_drill.py artifacts/backups/<备份目录名>
python3 tools/test_backup_integrity.py artifacts/backups/<备份目录名>
```

演练先验证清单与文件完整性，再启动独立 PostgreSQL 16 容器：无网络、无宿主端口、使用临时内存文件系统，不挂载正式数据库卷。它以单事务恢复转储，检查迁移版本、行数、约束、孤立/重复结果及统计值范围，并实际探测外键拒绝非法写入。成功或失败都会清理已创建的临时容器；报告只有在成功清理后才发布至 `artifacts/restore-drill.json`。报告不含账号名称、密码哈希或令牌。当前演练限定 512MiB 容器内存、2GiB 临时数据空间；更大的数据库需要单独规划恢复资源，超限应视为演练失败。

数据库转储使用一致性快照，两个战绩队列在转储后分别读取，**不是跨服务的一致时刻备份**。队列只检查哈希及 JSON 数组格式，演练不会重放队列；正式恢复需要核对队列涉及的用户与已结算 match_id，再通过原有幂等结算接口处理，不能直接认为队列与数据库必然匹配。Redis 中房间目录、占位与票据依赖短租约和进程实例，不应随旧备份恢复；恢复部署时使用干净缓存，由新专服重新注册。跨主机恢复和异地副本尚未实现；本机定时备份已配置如下。

### 本机定时备份

`infra/systemd/iron-meridian-backup.{service,timer}` 已安装到本机 systemd 并启用。每天 UTC 03:00 加最多 5 分钟随机延迟执行发布环境备份；`Persistent=true` 使关机期间错过的计划在定时器重新激活时补跑。服务以 `ec2-user` 执行，UMask 0077，超时 2 分钟，使用非阻塞文件锁避免同一计划任务重叠。备份沿用现有完整性校验和原子发布，不删除历史备份。手动备份脚本不使用此锁，但每次使用独立目录。

单元文件绑定当前部署路径 `/home/ec2-user/project/fpsgame` 和其中的 Python 虚拟环境；迁移主机或目录时应调整 `User`、`WorkingDirectory`、`ExecStart`。部署及检查命令：

```bash
sudo install -m 644 infra/systemd/iron-meridian-backup.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now iron-meridian-backup.timer
systemctl list-timers iron-meridian-backup.timer
sudo systemctl start iron-meridian-backup.service
systemctl show iron-meridian-backup.service -p Result -p ExecMainStatus
sudo journalctl -u iron-meridian-backup.service --since today
```

需要暂停计划时运行 `sudo systemctl disable --now iron-meridian-backup.timer`，不会删除备份或停止游戏。失败记录在 systemd journal，目前没有外部告警和自动清理策略，应监控磁盘空间；每日备份仍位于同一主机，不能抵御主机或磁盘丢失。

本次通过 systemd 手动触发同一 service，生成 `artifacts/backups/20260913T003425Z-4b9f9384`，目录 0700、文件 0600，并在隔离 PostgreSQL 中恢复通过。`artifacts/scheduled-backup-verification.json` 记录服务退出成功、安装文件哈希及定时器启用/待执行状态；恢复报告为 `artifacts/scheduled-backup-restore.json`。尚未观察到首次自动日历触发，不能把手动触发等同于完整周期或重启补跑验收。

正式恢复应先停止账号写入和游戏服务，保留原卷及配置，在替代数据库完成上述演练和应用验证后再切换，并重新启动空缓存与专服。此工具不会自动覆盖现有生产库；当前演练也不宣称已验证应用切换、非空队列重放或完整灾备流程。备份仍位于本机，需另外保存至独立存储。

## 配置与容量

当前一个房间最多 16 名参战者，空缺用机器人补足。API 运行两个 worker；Godot 固定两个专用实例，使用房间目录匹配。已做有限的延迟和随机丢包验证；尚未完成 16 真人压力测试、长时间稳定性测试或自动扩容验证，不能据此宣称支持大规模生产运营。

0.38 已通过 16 个独立打包客户端的本机满员回合检查：

```bash
.venv/bin/python tools/test_capacity.py --candidate-dir artifacts/candidates/0.38.0-dev-484d98d9-ssm8gza_
```

测试要求发布单人房间处于空闲状态，并使用测试账号实际登录，不绕过登录限流。16 个独立 ENet peer 同时进入同一回合，确认没有机器人占位；随后持续 8 秒正常移动/开火，16 个客户端均观察到全部 16 个角色移动、弹药消耗与位置校正，服务端时间推进约 8.00–8.05 秒。第 17 个请求返回 503；这是已满且已开始的房间拒绝入场，不单独证明候场阶段的名额竞争行为。所有客户端退出后房间回收成功。

报告 `artifacts/capacity-1789259737404766483/report.json` 绑定归档哈希，各客户端与服务端日志保留在同目录；汇总 `artifacts/capacity-038-packed.log`。客户端为 headless、最大帧率 30，测试不测 GPU 渲染帧率，不等于 16 名真人、公网延迟、长时间对局或生产峰值压力。候选参数会验证 API 版本和归档完整性，每个客户端使用独立用户数据目录。

Linux 客户端以 OpenGL Compatibility 渲染。开发主机通过软件 OpenGL 做实际渲染验证，所得性能不代表玩家 GPU 性能。Windows、macOS、移动端目前未打包验证。

## AI 任务

容器独立于编辑器和 Codex 前端运行。AI 自主开发的持续性取决于平台提供的 Goal 调度和会话生命周期，不由 Docker restart 保证。项目状态与下一步工作保存在 `docs/STATUS.md`，重新打开工作区可据此续接。

## 测试资源

骨骼蒙皮测试通过 Xvfb 使用实际 OpenGL 渲染，验证顶点变形与脚底位置；纯 headless 渲染器不能完成这项检查。联机测试账户凭据保存在忽略提交且权限为 0600 的 `artifacts/test-accounts.json`，不包含持久令牌。仅在重建测试数据库后删除此缓存以重新生成测试账户。

数据库升级已改用 Alembic，API 启动前自动运行事务迁移；`/health` 返回实际版本。升级策略和真实数据保留验证见 [数据库迁移](DATABASE_MIGRATIONS.md)。

## 请求校验错误

API 的请求模型校验失败返回 HTTP 422，`detail` 是可直接展示的简短提示，`errors` 为最多 20 个去重的 `{field, message}` 项。用户名与密码提示使用固定规则文本；错误响应不包含提交值、请求体、Pydantic 的 `input`/`ctx` 或解析异常上下文，并设置 `Cache-Control: no-store`。非法 JSON 也使用固定提示。字段名采用服务端白名单，不回显任意请求键。

该格式替代 FastAPI 默认的校验错误数组，现有客户端直接显示 `detail` 字符串。内部工具如依赖默认数组格式，需要改用 `errors`。业务错误的 HTTP 状态和内容保持原样。`backend/tests/test_validation_privacy.py` 使用实际 HTTP 服务验证，需运行环境提供 `SERVER_SECRET` 以覆盖专服模型级校验；不要将该值写入命令日志。

## 依赖暂时不可用

Redis 连接失败/读取超时、PostgreSQL 操作连接错误和 SQLAlchemy 连接池等待超时返回 HTTP 503，响应为固定的在线服务暂不可用提示，并包含 `Retry-After: 3`、`Cache-Control: no-store`。日志仅记录异常类别，不输出异常字符串中的连接信息或 SQL 参数。其他编程错误没有被统一掩盖成 503。

Redis 连接和读取超时均为 2 秒，不自动重试读取超时；数据库连接建立和连接池等待上限各为 3 秒。这些是各阶段超时，不是完整请求的延迟承诺，也没有给全部 SQL 查询设置执行时限。玩家可稍后重试；专服继续使用现有心跳与结算重试机制。

`backend/tests/test_availability.py` 在单独 API 测试进程中使用真实拒绝连接的 TCP 端口、不回应的 TCP 服务以及只有一个连接的临时连接池验证 503；释放池连接后再次访问健康接口必须恢复成功。测试不停止正式数据库/缓存，不改变正式实例的故障状态。这些检查不等同于跨主机网络分区或整个部署的灾难恢复验证。


## 独立组队开发库备份与恢复

`python3 tools/backup.py --duo-dev` 备份独立 `fpsgame-duo` 项目的 `iron_duo` 数据库和游戏结果队列。无参数仍备份原发布项目。两者的清单都从运行中 API 获取版本，避免分支源码版本与实际服务不一致。清单标注环境及队列来源；开发项目只有一个专服，第二个队列文件为保持既有包格式的空数组，来源明确为 `null`。

恢复器支持 0002、0003、0004。对 0004 额外检查模式与队伍编号、同队人数/排名、跨队排名、账户总计与结果行一致性，并汇总各模式对局/玩家结果/玩家胜利/击杀。还在回滚事务中探测模式和队伍编号 CHECK 约束。`backend/tests/test_restore_teams.py` 使用临时 PostgreSQL 数据验证异常关系可被检测；容器测试需同时挂载仓库 `tools` 目录到 `/app/tools`。

`restore_drill.py <备份目录> --upgrade-image <后端镜像>` 支持两类启动演练：0003 备份升级为 0004，并检查历史字段及单人模式回填；0004 备份重新运行启动迁移，比较 users、matches、results 的全部字段指纹与行数，确认幂等性。两者都在无外部网络的临时 PostgreSQL 容器中执行，并继续检查约束、队伍关系和账户统计；不会恢复或迁移在线数据库。

本轮演练实际恢复 3 场双人对局、12 条玩家结果、6 次玩家胜利和 6 次击杀；证据 `artifacts/duo-restore-drill.json`。发布结构 0003 的恢复回归通过，且其备份清单仍记录运行中的协议 15，而非开发源码协议 16；证据 `artifacts/release-restore-regression.json`。备份目录权限 0700，文件权限 0600。上述演练均在隔离临时容器完成，没有替换现有数据库。

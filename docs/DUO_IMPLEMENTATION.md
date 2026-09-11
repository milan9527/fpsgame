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
6. 完成以上集成后再更新实际开发状态、发行包与持久专服配置。开发源码现提供离线双人入口和在线邀请大厅；完整发行验收完成前不覆盖旧发布包。

这些是组队功能的实施步骤，不替代原始完整游戏目标；载具、跳伞、更多内容与生产运营等其他未完成范围仍需继续推进。

## 原生队伍基础与隔离环境（未发布）

开发源码使用协议 16 / 0.35.0-dev；发布包仍为协议 15 / 0.34。原生对局已实现 16 角色分成 8 队、队友附近安全出生、友伤过滤（保留自伤）、机器人排除队友目标、整队排名和最后一队获胜。阵亡成员可随存活队友获得队伍排名。角色快照包含队伍；单人检查点仍使用原有字段。队伍检查点使用格式 2，旧单人格式 1 继续兼容；服务端队伍战绩现已接入独立模式字段。

`artifacts/duo-team-rules.log`、`duo-solo-checkpoint.log`、`duo-solo-smoke.log` 记录原生队伍规则、旧存档及单人完整对局回归通过。倒地/扶起已完成原生规则验证，后续网络战斗、邀请大厅和持久化验证见本文后续章节，发行验收仍未完成。

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

## 倒地与扶起原生规则（未发布）

双人模式中，致命伤害发生时仍有站立队友则进入倒地：保留角色碰撞与库存，生命为 0，另有 100 点倒地生命与 30 秒流血时间。只能低速蹲行，不能开火、治疗、换弹、投掷、拾取或操作配件。补枪耗尽倒地生命或流血到期才执行正式淘汰、击杀计数与库存掉落。没有站立队友时不能再次倒地，现存倒地队友一起淘汰。单人仍立即淘汰。

队友在 2.8 米内、静态墙体无遮挡时按拾取交互键开始 5 秒扶起，再次交互取消；移动、距离、遮挡、战斗动作、救援者或伤员受伤会中断。完成恢复 30 生命，不消耗医疗包。原有可靠动作序号/回合/预算检查覆盖交互，重放动作不能误取消扶起。机器人按导航接近并使用相同救援规则，临近手雷避险优先。HUD 显示倒地倒计时、附近队友救援提示及扶起进度。

`tests/rescue_rules.gd` 在实际 Godot 世界中验证倒地、动作限制、真实墙体遮挡、快照复制/恢复、受伤/移动/距离/再次交互中断、可靠动作重放、完成、机器人救援、流血归因、整队淘汰及单人立即死亡。证据 `artifacts/rescue-rules.log`。旧存档和单人完整对局分别见 `artifacts/rescue-solo-checkpoint.log` 与 `artifacts/rescue-solo-smoke.log`。

四客户端倒地/扶起/两次受伤中断/队伍胜负同步已通过专门验收，战绩落库已接入本轮验收，退出/会话撤销组合验收仍待完成。原有入场脚本仍只证明入场与队伍快照。当前倒地使用蹲姿，没有专用倒地动画；队伍观战、地图及邀请大厅已实现。开发协议 16 扩展快照字段 `downed`、`down_health`、`bleed`、`revive_target`、`revive_left`；旧单人检查点不包含这些字段。

## 四客户端救援网络验收

运行 `.venv/bin/python tools/test_rescue_network.py`：临时专服连接独立开发 API，监听 UDP 27032；四个真实客户端使用各自账号完成房间票据鉴权。夹具控制伤害时机并关闭机器人攻击，以稳定制造倒地、救援者受伤、伤员受伤、扶起完成和对方整队淘汰。救援者实际注入拾取交互输入，由客户端正常可靠动作链路发送，未直接调用专服救援方法。四个客户端都必须看到倒地、进度、两次中断、恢复 30 生命及两队名次，专服另检查击杀与排名。

证据：`artifacts/rescue-network.log`、`artifacts/rescue-network-server.log`、`artifacts/rescue-network-client-0.log` 至 `-3.log`。测试不是自由对战压力测试，也不证明全部战绩与生产压力：组队结果现在进入模式适配后的专服接口，后续验收还需包含断开与会话撤销。

同时修正倒地补枪的护甲重复扣除及淘汰报告：补枪仅消耗倒地生命，剩余护甲进入死亡掉落，报告显示该次倒地生命损失。`tests/rescue_rules.gd` 验证 82 点剩余护甲完整回收以及 100 点补枪伤害报告；`artifacts/rescue-death-recap.log` 验证既有报告规则回归。

## 服务端组队战绩

数据库迁移 `0004` 增加对局模式与玩家队伍编号；API 验证队伍人数、共享排名、跨队排名唯一性，并保留旧单人请求默认值。专服在回合开始保存每个人类成员的队伍编号，回合结束写入带模式的持久发送队列。JSON 队列重新加载后会将队伍编号规范为整数再提交。

四客户端救援测试现会重载结果队列，等待正常后台发送，并直接查询 PostgreSQL 确认 4 条账号记录、两队共享名次、2 次击杀及 `duo` 模式；同时验证每个玩家的组队统计增量和单人统计未变。本地双人记录已接入模式区分；组队检查点与邀请大厅已完成，其他未完成范围见当前状态。

## 本地组队记录

离线组队结果使用本地记录版本 2，包含模式和队伍编号。旧单人记录继续只读兼容；队友尚存活时个人死亡不视为最终名次，提前退出记为中止，留到队伍结算则保存最终排名。历史页面增加模式列和分模式统计。真实游戏/UI、磁盘失败重试、独立进程重读及旧单人存档回归见 `artifacts/local-duo-full-regression.log` 和 `artifacts/local-duo-checkpoint-regression.log`。组队检查点已通过恢复验证。

## 队伍观战

双人玩家倒地时保留自己的镜头；正式阵亡后，观战候选只包含同队存活成员。按键循环、自动换人及直接选择均受该限制。队友淘汰或从名单移除后，镜头回到本人的阵亡位置，不跟随其他队伍；界面显示队伍淘汰与队伍名次。单人模式继续使用存活玩家名单，回合重置清除队伍过滤。

`tests/duo_spectator.gd` 验证倒地视角、队友选择、输入循环、显式选择限制、整队淘汰、名单移除和回到单人模式；`tests/spectator_rules.gd` 回归单人换人、墙体碰撞、缩放、退出与重置。四客户端救援场景进一步在扶起后淘汰伤员，确认其跟随队友获得胜利；败方两个客户端不能进入胜方视角，数据库仍保存阵亡成员的共享胜利。

证据：`artifacts/duo-spectator-rules.log`、`artifacts/duo-spectator-solo-regression.log`、`artifacts/duo-spectator-network.log`。这是标准客户端的观战规则；当前网络快照仍同步所有角色，不构成针对修改客户端的敌方状态保密机制。

## 队友状态与地图

战斗 HUD 显示队友姓名、生命/倒地剩余秒数/救援进度/淘汰状态和距离。队友缺失时显示不可用，不保留过期位置。小地图和战术地图仅绘制本队其他成员：绿色存活标记、橙色倒地标记、淘汰叉号；战术地图标注姓名，姓名保持在地图边界内。进入单人、新回合或离开时清除标记。队伍文字带深色描边以适应亮天空。

原生验证：`tests/team_hud.gd`，日志 `artifacts/team-hud.log`。原单人地图回归：`artifacts/team-map-solo-regression.log`。真实四客户端救援场景确认队友倒地提示及本队标记筛选，并继续通过胜负/战绩落库验收：`artifacts/team-hud-network.log`。实际渲染截图为 `artifacts/team-hud.png` 和 `artifacts/team-map.png`。尚未实现队友共享主动标点和语音通信。

## 组队数据恢复验收

备份工具提供独立开发环境入口，恢复器支持 0004 的队伍排名与账户总计检查。实际双人数据库备份已在无网络临时 PostgreSQL 容器恢复并验证，旧发布库 0003 也通过恢复回归；详见 [运维说明](OPERATIONS.md) 及 `artifacts/duo-restore-drill.json`。共享标点/语音与其余发行验收仍需继续完成。

## 组队检查点与离线入口

开发版主菜单现在可以直接启动人机双人对局。新增格式 2 保存队伍、倒地、流血归因和救援进度；队友仍存活时可挂起阵亡观战，恢复后仍可随队获得胜利。单人格式 1 和已结算旧档隔离继续保留。实际渲染/恢复测试、六进程反复保存读取及旧单人回归分别见 `artifacts/duo-checkpoint.log`、`artifacts/duo-checkpoint-process.log`、`artifacts/duo-checkpoint-solo-regression.log`。主菜单截图为 `artifacts/duo-deployment-menu.png`。

## 邀请后端基础

开发 API 提供 `POST /parties`、`GET /parties/current`、`POST /parties/accept`（`invitation` 字段）和 `DELETE /parties/current`。所有操作需要有效账号令牌，使用 Redis Lua 原子管理一人一队及双人上限。创建者得到 32 字节随机邀请码，有效期 15 分钟；接受后单次邀请立即失效，不延长组队有效期。只有未满队的创建者可读取邀请码，响应禁用缓存；成员列表不返回会话版本或邀请码哈希。任一成员离开会解散双人队伍。

正常全设备注销按会话版本清理旧队伍，延迟清理不能误删新会话创建的队伍。接受邀请还在数据库共享锁下核验邀请者会话版本，防止注销提交后缓存清理失败留下有效旧邀请。缓存/数据库不可用继续使用既有依赖错误处理。

`backend/tests/test_parties.py` 验证单次邀请、16 个并发接受请求仅一个成功、成员唯一性、过期、解散、会话版本清理、HTTP 认证和验证错误隐私。连同房间/会话/故障/战绩回归共 46 项通过，证据 `artifacts/party-backend-tests.log`。已部署到独立开发 API 8001，两个隔离测试账号的真实 HTTP 创建/接受/查询/解散通过，证据 `artifacts/party-live-http.log`。

邀请通过下述专用预约入口接入整队容量；普通逐人匹配目前仍不读取队伍。客户端邀请/开始界面和真实邀请队伍交错入场均已有独立验收（见后文）；两名成员均明确准备后才允许队长开始，详见准备状态验收。

## 整队预约内部能力与专服配队

`RoomDirectory.allocate_party` 接收两个不同的成员，在同一次 Redis Lua 操作中检查全部成员占位及目标双人房间的剩余容量，然后同时签发两张独立票据。每张票据绑定 `party_id`、本次 `group_id`、房间实例/回合和会话版本。普通逐人预约使用同一容量逻辑，避免两个实现各自占位而超额。容量不足或任一成员忙碌时，不为另一人留下预约。

任一未消费的组票被本人取消时，同批尚未消费的票据一起释放；已消费票据对应的连接租约保留，由正常心跳/离开流程管理。取消不能通过第三方账号发起，也不会删除不同会话版本的新租约。

专服回合开始按已鉴权票据的 `party_id` 分组，完整双人队优先保持，不依赖玩家交错入场顺序。缺席伙伴优先用机器人补齐；后续大厅若只有多个不完整人类队伍，则在保留完整队伍的前提下补齐剩余位置。单人模式忽略组队身份。

52 项后端回归通过，包含 12 支队伍并发争夺 6 个位置、容量不足整队失败、成员忙碌无部分写入、票据绑定、整批取消及部分入场租约保留；日志 `artifacts/party-reservation-tests.log`。原生交错配对、缺席伙伴、满人类不完整队伍与既有队伍回归见 `artifacts/party-team-rules.log`、`artifacts/party-team-regression.log`。

该原语现由下述 `POST /parties/reserve` 入口调用。当前普通匹配不会自动把已接受邀请的两人送进同一房间，客户端需要显式使用整队入口。

更新后的共享分配器和专服继续通过既有四客户端真实救援/胜负/战绩落库回归：`artifacts/party-reservation-network-regression.log`。该回归尚不使用邀请队伍预约，不代替后续整队 HTTP 流程验收。

## 邀请队伍预约入口

开发 API 的 `POST /parties/reserve` 接收构建信息和可选 `room_id`，只允许满双人队的队长调用。数据库共享锁下核验两人的当前会话版本，随后 Redis 在一次操作中核对队伍快照、预约两个名额并保存该批票据。并发重试返回同批预约，不重复占位。队伍剩余寿命不足 45 秒时拒绝预约，避免队伍先过期。

响应以及 `GET /parties/current` 只返回请求者自己的 `admission`，包含房间绑定、模式、构建信息和实际票据剩余秒数；不会返回同伴票据、内部预约对象或会话版本。已消费或过期票据不再返回，状态为 `consumed_or_expired`。目前此状态需要离队后重新组队，没有自动重新排队。任一成员解散会释放同批未使用票据；已经连接的成员保留连接租约，由专服正常管理。

61 项后端回归通过，证据 `artifacts/party-coordinator-tests.log`：包括并发幂等、队长权限、响应隐私、无可用房间重试、过期快照、注销失效、解散竞争、部分入场后解散及队伍即将过期。开发 API 8001 已更新；运行 `.venv/bin/python tools/test_party_http.py` 使用两个可复用隔离账号，对运行中的 UDP 27031 房间完成邀请、预约、幂等重试、按人取票及解散后容量再预约，日志 `artifacts/party-coordinator-http.log`。此 HTTP 验收不消费 ENet 票据；交错入场由后述独立网络验收覆盖，客户端界面另有下述双客户端验收。

## 邀请队伍真实交错入场验收

`.venv/bin/python tools/test_rescue_network.py --parties` 创建两支真实账号邀请队伍（账号 0/2 和 1/3），分别调用整队预约，再等待每名客户端鉴权完成后按 A、B、A、B 顺序启动下一名。客户端使用各自 HTTP 返回的票据，通过游戏正常 ENet 握手消费；专服根据鉴权会话检查实际入场顺序和邀请身份，并确认同伴共享队伍编号。

该场景继续执行真实客户端救援交互、两次受伤中断、成功扶起、阵亡队友观战获胜、整队淘汰和结果队列磁盘重载。最终直接查询 PostgreSQL 的四条结果，按账号确认原邀请伙伴仍共享队伍和名次，并核对每人双人统计增量及单人统计不变。证据 `artifacts/invited-party-network.log`、`artifacts/invited-party-network-server.log` 和四份 `artifacts/invited-party-network-client-*.log`。

客户端现在复用 `connect_admission` 完成构建/模式校验、票据登记、ENet 连接和握手超时处理。连接尝试编号会拒绝迟到预约并用原始账号来源取消票据；`artifacts/party-admission-cancellation.log` 验证取消与单机启动之后的迟到响应隔离。这项四客户端验收由测试驱动创建邀请；面向玩家的界面由下述双客户端测试单独覆盖。

共享入场入口改动后，普通逐人双人匹配仍通过四客户端救援、观战和战绩回归：`artifacts/party-admission-solo-queue-regression.log`（文件名中的 solo-queue 指单人排队，实际对局模式为 duo）。

## 玩家邀请大厅（开发源码）

启动 `tools/godot --path client`，在线账号区域选择 `DUO`，API 地址填写 `http://127.0.0.1:8001`，登录或创建账号后进入队伍大厅。队长点击 `CREATE TEAM` 并复制邀请码，另一名玩家粘贴后点击 `ACCEPT INVITATION`；两名成员分别点击 `READY`，队长看到双方准备后点击 `START DUO OPERATION`。大厅每两秒查询成员及自己的票据，两人通过同一房间的独立票据入场。登录成功后清除密码输入。

`LEAVE TEAM & RETURN` 调用后端解散并释放待使用预约，成功后返回菜单；`RETURN / KEEP TEAM` 仅关闭大厅，允许保留队伍。重新选择 DUO 登录会加载已有队伍。面板打开时隐藏主菜单以隔离键盘焦点；请求期间避免重复操作，失败后恢复按钮并显示服务错误，轮询失败退避至五秒。401 清理登录并返回菜单。队伍寿命不续期；已消费或过期预约可在成员均离开后手动重置并保留队伍；胜负页返回队伍按钮已接入；重置与准备仍由玩家操作。

`tests/party_lobby_rules.gd` 验证角色权限、邀请码、预约失败重试、按人入场、解散/保留返回、迟到响应与登录失效。实际渲染截图为 `artifacts/party-lobby-menu.png` 和 `artifacts/party-lobby.png`，使用合成姓名与邀请码。`artifacts/party-lobby-render.log` 为渲染和规则记录，连接取消回归见 `artifacts/party-lobby-cancel-regression.log`。

`.venv/bin/python tools/test_party_lobby_network.py` 启动两个真实 Godot 客户端，操作正式登录入口与邀请面板控件，连接独立开发 API/UDP 27031，验证队长创建、成员接受、成员轮询、队长开始、ENet 入场及快照中同伴姓名/队伍编号。主日志 `artifacts/party-lobby-network.log`，客户端日志 `artifacts/party-lobby-network-0.log` 和 `-1.log`；邀请码仅通过权限 0700 的临时测试目录交换，结束后删除。此测试验证入场，完整战斗和落库由既有四客户端场景覆盖；发布包仍为 0.34。

## 准备状态与并发开始

`POST /parties/ready` 接收严格布尔值 `ready`，仅更改当前已认证成员自己的状态。创建队伍默认未准备，新成员加入会将双方重置为未准备。切换准备使用 Redis 原子更新并保留原过期时间。两人均准备后，队长才能预约；后端和 Redis 预约操作都核验准备状态及完整队伍快照，界面不能绕过限制。预约一旦成功，准备状态锁定，取消需要离队释放预约。

大厅显示每人的 READY / NOT READY，提供 READY / CANCEL READY。开始按钮仅在当前账号为队长且两人准备时启用；取消准备后立即禁用，后端仍会处理其他成员尚未刷新时的并发请求。保留队伍返回菜单不会更改准备状态，需要撤回准备时先点击 CANCEL READY。

`artifacts/party-ready-backend.log` 记录 64 项后端回归；随后包含新增“取消准备与开始同时提交”用例的 13 项预约测试通过，见 `artifacts/party-ready-race.log`。竞争只允许开始成功/取消失败，或取消成功/开始失败，不会在未准备状态分配名额。还验证布尔值校验、准备重置、保留 TTL、旧快照失效及预约后修改被拒绝。

开发 API 8001 已更新。实际双客户端通过面板分别准备再入场，证据 `artifacts/party-ready-network.log` 及 `artifacts/party-lobby-network-0.log` / `-1.log`。原生规则验证准备/取消按钮和开始权限，渲染记录 `artifacts/party-ready-render.log`，更新截图 `artifacts/party-lobby.png`。现有发布包不变，赛后保队重置和返回入口见后文。

## 保留队伍并重置预约

`POST /parties/reset` 接收构建信息及旧 `group_id`。只有队长可操作，当前队伍响应的 `reservation_id` 用于绑定旧预约，防止迟到请求取消新一轮预约。Redis 在一次操作中核验全部成员租约；若存在已消费票据对应的连接租约、其他房间租约或更新会话版本，则返回 409，不改动队伍和票据。允许清理尚未消费的同批预约；连接成员须先离开并由专服心跳释放租约。

重置成功清除旧票据/占位、保留队伍 ID/成员/原过期时间，并将双方设为未准备。重复重置未预约队伍不会清除新准备状态。下一次双方准备后签发新的预约编号与票据。大厅在预约已消费或过期时向队长显示 `RESET MATCHMAKING`；成员只可查看，重置后双方正常重新准备。当前仍需退出对局后重新进入 DUO 大厅，胜负页现提供返回原队伍的按钮（见后文），不强制自动离场。

`artifacts/party-reset-backend.log`：69 项后端回归通过，包括旧票据失效、同队重新预约、新会话租约保护、连接中拒绝重置、心跳释放后允许重置、保留 TTL、重复重置和迟到旧预约重置隔离。`artifacts/party-reset-ui.log` 验证队长按钮、成员权限以及重置后恢复准备界面。开发 API 8001 已更新。

`.venv/bin/python tools/test_party_lobby_network.py --requeue` 已通过：两个真实客户端第一轮进入 live 后主动退出，再启动客户端登录已有队伍；队长通过正式 RESET MATCHMAKING 按钮重置，两人重新准备并进入不同回合，同伴姓名/队伍配对保持正确。两轮队伍 ID 相同、回合 ID 不同，准备状态在第二轮需重新提交。证据 `artifacts/party-reset-network.log` 与 `artifacts/party-requeue-{0,1}-{0,1}.log`。该测试覆盖主动退出后的再次排队，不覆盖胜负页自动返回大厅。

## 结算后返回原队伍

已登录的双人客户端在整场结算时显示 `RETURN TO TEAM`，并释放鼠标供点击。点击后通过正常可靠离场 RPC 通知专服，等待连接关闭（最多两秒），再清理战场并使用原账号令牌打开队伍大厅；不要求重新输入密码，不删除邀请队伍。返回期间收到预期断线不会覆盖大厅流程；若另一个退出操作或账号撤销改变连接尝试，则不再打开大厅。离场失败时仍由后端租约检查阻止重复占位。

玩家可留在现有房间等待下一场，或主动返回队伍；两人返回后队长使用 RESET MATCHMAKING，再分别准备和开始。此行为不自动延长队伍 15 分钟寿命，队伍到期仍需重建。

`.venv/bin/python tools/test_rescue_network.py --parties --return-to-party` 已通过四个真实客户端完整场景：邀请队伍交错入场、救援/两次中断、阵亡成员随队胜利、败方整队淘汰、结算按钮返回原队伍、令牌保持和游戏连接关闭。测试继续核对四条 PostgreSQL 战绩及分模式统计。主日志 `artifacts/post-match-party-network.log`，服务端 `artifacts/post-match-party-server.log`，客户端 `artifacts/post-match-party-client-{0,1,2,3}.log`。界面规则回归 `artifacts/post-match-party-ui.log`。源码尚未打包发布。

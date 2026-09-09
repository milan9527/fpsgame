# 开发状态 — 2026-09-09

**Goal 保持 active；用户要求的完整商业级游戏尚未完成。当前交付是已运行、已联调、有完整单局循环的开发版本，不应称为《和平精英》级成品。**

## 已实际实现

- Godot 4.4.1 原生 FPS 客户端，Linux 可启动包。
- Blender 4.3.2 原创枪械、角色模型和可重复生成脚本；保留 `.blend` 源文件。
- 17 骨骼蒙皮角色、9 个动作片段（待机、走、跑、蹲伏待机/行走/换弹、跳跃、站立换弹、死亡），一张网格、6 个材质面。动作按服务器同步的速度、落地、姿态、换弹与生命状态驱动。
- Blender 第一人称手臂/袖口/手套，5 骨骼、单网格、3 材质；持枪、换弹、投掷跟随、治疗动作；瞄具对齐、弹匣动作、移动起伏与开火回弹。仅本地角色分配这套资源。
- 原创地图，建筑可进入，环境、碰撞、掩体与补给。
- 离线 1 人 + 15 机器人；在线最多 16 名参战者、空位机器人补齐。
- 移动、奔跑、跳跃、真实蹲伏碰撞与低顶站起检查、鼠标视角、缩放瞄准、三种枪械规则、护甲、命中部位、换弹、医疗包、拾取。
- 服务器累计后坐力、随移动/瞄准/蹲伏变化的散布、确认命中/爆头/击杀提示与受击方向。
- 破片手雷：Blender 原创模型，服务器刚体反弹、2.6 秒引信、9 米范围伤害与多点掩体遮挡；库存、补给、近距警告、烟尘火花特效、多人同步及断线击杀归属。
- 缩圈、淘汰、排名、超时裁定和在线回合重启。
- 淘汰后第三人称观战、Q/E 切换、鼠标环绕/滚轮缩放、球体扫掠防穿墙、目标淘汰/离线自动切换、观战 HUD 和回合清理。
- 同帧全灭文案与第一名排名保持一致，回合结束有幂等保护。
- 图形菜单、设置保存、局内 HUD、小地图、Tab 记分板、账户登录与注册、在线排行榜。
- 17 类原创合成音效：枪声/爆炸、草地与硬地脚步、起跳落地、换弹、治疗、拾取与私人命中提示；空间衰减、墙体直达声衰减、48 声音上限/优先级、实时音量和观战听音位置。
- 音效总线限幅、退出时混音资源释放；专服禁用客户端互转，避免同时离线时的内部通知发包错误。
- 60Hz 服务器模拟、30Hz 输入、20Hz 分批压缩快照、可靠补给同步、回合隔离。
- 60Hz 本地移动预测、服务器序号确认、未确认移动重放、120 帧历史上限、死亡/位置突变清理与摄像机误差平滑。
- 输入验证、序列检查、速率控制、停发输入后的移动/射击停止、一次性联机票据；向客户端发送前检查 ENet 连接是否仍可用。
- PostgreSQL 账户与战绩；Redis 票据和限速；事务、幂等统计、战绩磁盘重试队列。
- Alembic 数据库版本、旧库基线校验、并发迁移锁、事务回滚、统计约束与战绩查询索引。
- Docker 后台运行、健康检查、持久卷、日志轮转和备份脚本。
- 单机本地战绩、完成/中止分类、历史查询、独立记录原子发布、校验与备用副本读取、并发去重、失败重试和未保存退出保护；不包含进行中的对局续存。
- 客户端/API/专服共享版本清单；登录前兼容提示、匹配票据版本绑定、专服监听前版本检查。详见 [协议部署说明](PROTOCOL.md)。

## 已验证的证据

| 检查 | 结果 | 证据 |
|---|---|---|
| 单机规则 | 通过 | `artifacts/offline-smoke.log` |
| 装甲、换弹守恒、治疗消耗、死亡与排名 | 通过 | 同上 |
| 真实物理射线伤害、墙体挡弹、开火间隔 | 通过 | 同上 |
| 蹲伏空间、不同姿态挡弹与爆头、后坐力不可由输入清零、散布与真实伤害反馈 | 通过 | `artifacts/combat-rules.log` |
| 双客户端蹲伏、后坐力和远端姿态同步 | 通过 | `artifacts/combat-online.log` |
| 新枪战规则完整回合落库 | 通过 | `artifacts/combat-full-round.log` |
| 新枪战 HUD 实际渲染 | 已检查 | `artifacts/combat-feedback.png` |
| 骨骼动作、真实蒙皮顶点下降与脚底稳定、动作切换 | 通过（实际 OpenGL） | `artifacts/animation-rules.log` |
| 多人远端骨骼动作 | 通过 | `artifacts/animation-online.log` |
| 动作系统整局结算回归 | 通过 | `artifacts/animation-full-round.log` |
| 动作画面 | 已渲染检查 | `artifacts/animation-gallery.png` |
| 空库/旧库迁移、并发迁移、漂移拒绝、错误数据回滚、版本保护 | 6 项通过 | `artifacts/migration-tests.log` |
| 运行库升级数据保留 | 全部应用行摘要一致，升级至 0002 | `artifacts/live-migration.log` |
| 升级后 API 与完整回合 | 5 项 API 测试及整局落库通过 | `artifacts/post-migration-api-tests.log`、`artifacts/post-migration-full-round.log` |
| 双客户端退出与关闭连接发送保护 | 通过 | `artifacts/disconnect-online.log`、`artifacts/online-server.log` |
| 手雷库存/反弹/贴墙防穿透/引信/掩体/半径/归属/陈旧包清理 | 通过 | `artifacts/grenade-rules.log` |
| 双客户端投掷和爆炸通知 | 通过 | `artifacts/grenade-online.log` |
| 手雷参与的完整对局落库 | 通过 | `artifacts/grenade-full-round.log` |
| 独立发行包内手雷规则与资源 | 通过 | `artifacts/packed-grenade.log` |
| Blender 手雷和实际特效渲染 | 已验证 | `artifacts/grenade-asset.log`、`artifacts/grenade-gameplay.png` |
| HTTP + PostgreSQL + Redis | 5 项通过 | `artifacts/backend-tests.log` |
| 两个独立 Godot 客户端认证、同局、移动、开火 | 通过 | `artifacts/online-tests.log` |
| 独立 20 倍速服务器完整对局与结果落库 | 通过 | `artifacts/full-round-test.log` |
| Blender 资源生成 | 通过 | `artifacts/blender-build.log` |
| 独立 PCK 包内运行 | 通过 | `artifacts/packed-smoke.log` |
| 软件 OpenGL 实际画面 | 已渲染并检查 | `artifacts/menu.png`、`artifacts/game.png` |
| 排行榜、记分板、返回菜单实际 UI 流程 | 通过 | `artifacts/ui-tests.log` |
| 数据库逻辑备份 | 已生成并检查目录 | `artifacts/backup-test.log`、`artifacts/backup-verify.log` |
| 旧协议/错误内容拒绝、票据绑定与并发一次性消费 | 通过 | `artifacts/protocol-api-tests.log` |
| 不兼容客户端登录前提示、专服监听前退出 | 通过 | `artifacts/protocol-client-test.log`、`artifacts/protocol-server-test.log` |
| 兼容版本双客户端与完整回合落库 | 通过 | `artifacts/protocol-online.log`、`artifacts/protocol-full-round.log` |
| 发行包版本清单与登录前兼容检查 | 通过 | `artifacts/packed-protocol.log` |
| 本地即时移动、延迟快照校正、碰撞重放、历史上限、摄像机挡墙、死亡与突变清理 | 通过（独立发行包） | `artifacts/packed-prediction.log` |
| 预测版本真实双客户端与完整回合落库 | 通过 | `artifacts/prediction-online.log`、`artifacts/prediction-full-round.log` |
| 预测版本蹲伏/挡弹/后坐力回归与协议提示 | 通过 | `artifacts/prediction-combat.log`、`artifacts/prediction-protocol.log` |
| 观战输入/目标切换/镜头挡墙/断线/回合重置/全灭结算 | 通过（独立发行包） | `artifacts/packed-spectator.log` |
| 实际观战渲染 | 已检查 | `artifacts/spectator-render.log`、`artifacts/spectator.png` |
| 网络淘汰后观战与整局落库 | 通过 | `artifacts/spectator-full-round.log` |
| Blender 第一人称资源生成 | 通过 | `artifacts/viewmodel-blender.log` |
| 瞄具对齐/真实蒙皮顶点/三种换弹时长/投掷与治疗/无重复消耗 | 通过（实际 OpenGL） | `artifacts/viewmodel-rules.log` |
| 第一人称动作实际画面 | 已检查 | `artifacts/viewmodel-gallery.png` |
| 第一人称版本双客户端与完整回合落库 | 通过 | `artifacts/viewmodel-online.log`、`artifacts/viewmodel-full-round.log` |
| 独立包内手臂资源与动作逻辑 | 通过 | `artifacts/packed-viewmodel.log` |
| 音效状态边沿/表面/静止校正/声音优先级/遮挡/混音限幅/真实立体声录制 | 通过 | `artifacts/audio-rules.log` |
| 开启音频的双客户端与同时退出 | 通过；无对象泄漏或关闭连接发包错误 | `artifacts/audio-online.log`、`artifacts/online-server.log` |
| 音频版本完整对局与战绩落库 | 通过 | `artifacts/audio-full-round.log` |
| 音效样例与真实声道录音 | 已生成并检验 PCM | `artifacts/audio-actions.wav`、`artifacts/audio-right.wav`、`artifacts/audio-turned.wav` |
| 独立包音频与活动声音下关闭窗口 | 通过；退出码 0，无泄漏警告 | `artifacts/packed-audio.log`、`artifacts/packed-audio-shutdown.log` |
| 本地战绩跨进程/并发/去重/冲突/备用副本/校验/未来版本拒绝 | 通过（含独立发行包） | `artifacts/local-profile-storage.log`、`artifacts/packed-local-profile.log` |
| 单机结算/中止/淘汰记录、保存失败重试与退出保护 | 通过（真实游戏及 UI） | 同上 |
| 本地战绩界面 | 已渲染并检查 | `artifacts/local-history.png` |
| 本地战绩版本的联机与在线整局落库回归 | 通过 | `artifacts/local-profile-online.log`、`artifacts/local-profile-full-round.log` |

20 倍速测试用于验证完整流程，不代表实时性能、弱网适应性或长期稳定性。双客户端验证不等于 16 真人并发验证。

预测规则测试在同一物理世界中独立模拟权威角色和客户端角色，延迟 200 毫秒投递权威快照，覆盖移动切换并测得约 0.164 米峰值误差。这是可重复的单向快照延迟测试，不代表双向网络抖动/丢包或动态玩家碰撞验证。

## 距离用户要求的完整游戏仍缺少

以下都是未完成工作，不能用菜单占位或接口存在宣称完成。

1. **枪战体验**：预测校正在双向延迟/抖动/丢包下的调优、延迟补偿、武器专属第一人称模型与动作/手指握持/近墙表现、方向混合/脚步 IK/攀爬动作、枪械差异化后坐力调校、环境声/混响/专业混音、动作细节与过渡打磨、趴下/攀爬。
2. **玩法内容**：跳伞部署、车辆、组队、复活/救援、背包与配件、烟雾/闪光/燃烧等其他投掷物及完整投掷动画、多地图、多模式、延迟/队伍观战与回放、教程与局内存档/续局。
3. **机器人**：导航网格、建筑导航、战术掩体与搜索、难度分层；现有机器人是视线感知与局部避障。
4. **多人服务**：多房间调度、排队与区服选择、断线重连、会话迁移、多版本共存与滚动升级、跨服账户会话约束、好友与队伍。
5. **长期运营**：大数据量在线迁移与运行/迁移角色分离、管理工具、可观察性指标、资源限制与容量模型、灰度发布、灾备恢复演练、赛季与进度系统。
6. **安全与合规**：游戏传输加密、完整反作弊、审计与封禁、账号找回与邮件验证、隐私流程、面向目标市场的法规要求。公网账号入口的 HTTPS 尚需实际域名与部署环境。
7. **发行品质**：美术与场景质量、动画与 UI 无障碍、中文本地化、性能预算、16 真人/高延迟/丢包/长时间测试、Windows/macOS/移动端打包验证。

第三人称已使用真实骨骼蒙皮动作，蹲伏不再缩放整个模型；动作仍需手工美术打磨、方向混合和脚步 IK。第一人称已有蒙皮手臂与瞄具对齐，但三种枪械仍共用主要外观，手指握持和武器专属动作尚需完善。场景使用低多边形美术。移动预测已实现，但双向弱网和移动玩家之间的碰撞仍需系统验证，射击尚无延迟补偿。

## 后续推进顺序

1. 继续改进预测/校正、枪战延迟补偿、武器专属动作与声音设计，不破坏已经验证的权威模拟。
2. 继续实现可独立测试的房间调度，补重连和服务指标；迁移基础已经完成。
3. 扩展背包/配件/其他投掷物、队伍与观战权限，再进行内容与美术制作。
4. 增加弱网、满员和长时间测试，扩大平台发行范围。

## 后台边界

正常游戏服务由 Docker 独立运行，退出终端不会主动停止容器。宿主机停机或 Docker 停止会影响服务。后台 AI 开发取决于 Codex 平台的 Goal 调度和任务生命周期；本仓库没有创建能绕过平台生命周期、在任意界面退出后仍保证无限开发的代理进程。

本轮追加：蹲伏与开火高度统一在权威模拟计算；命中反馈只发给射手/受击者，不广播敌人伤害信息。瞄准与姿态字段改变了输入协议，部署时客户端与服务端必须一起更新。

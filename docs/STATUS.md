# 开发状态 — 2026-09-10

**Goal 保持 active；用户要求的完整商业级游戏尚未完成。当前交付是已运行、已联调、有完整单局循环的开发版本，不应称为《和平精英》级成品。**

## 已实际实现

- 连接取消按钮、未消费预留的账户级原子撤销、迟到响应与旧握手定时器隔离；消费/取消竞争及旧回合保护。详见 [连接生命周期](CONNECTION_LIFECYCLE.md)。

- Godot 房间目录匹配与专服心跳；两个持久专服独立回合、票据绑定、容量预留、名单隔离、空房间回收及失联过期。当前固定两实例，详见 [房间目录](ROOM_DIRECTORY.md)。

- 背包按数量丢弃储备弹药/医疗包/手雷、权威生成与近距离同类合并、其他角色回收及治疗库存保护；协议 7 可靠去重与限流。详见 [丢弃物资](DROPPING.md)。

- B 键战场背包：库存与三枪弹匣、明确选择附近物资、切枪/换弹/治疗、单机/在线权威操作、输入隔离及关闭生命周期。详见 [背包](INVENTORY.md)，尚无完整物品与配件系统。

- 淘汰库存转移、弹匣弹药回收、按类别堆放与部分拾取；清空尸体库存防重复生成，详见 [淘汰物资](DEATH_LOOT.md)。

- 三枪独立弹匣与共享储备，切枪保留装弹量；计时换弹、空弹匣提示与三枪 HUD，协议 6 同步。详见 [弹药规则](AMMUNITION.md)。

- Godot 4.4.1 原生 FPS 客户端，Linux 可启动包。
- Blender 4.3.2 原创枪械、角色模型和可重复生成脚本；保留 `.blend` 源文件。
- 17 骨骼蒙皮角色、9 个动作片段（待机、走、跑、蹲伏待机/行走/换弹、跳跃、站立换弹、死亡），一张网格、4 个材质面。动作按服务器同步的速度、落地、姿态、换弹与生命状态驱动。
- Blender 第一人称手臂/袖口/手套，5 骨骼、单网格、3 材质；持枪、换弹、投掷跟随、治疗动作；瞄具对齐、弹匣动作、移动起伏与开火回弹。仅本地角色分配这套资源。
- 三种独立 Blender 枪模、导出瞄具/枪口挂点、不同瞄准视野；第三人称按武器快照挂接骨骼，第一人称切换对应模型，远端不分配隐藏第一人称枪。详见 [武器外观](WEAPON_VISUALS.md)。
- 第一人称近墙收枪、退出瞄准及 HUD 提示；服务器按实际枪长扫掠空间，阻挡时不消耗弹药/后坐力，支持转向、蹲伏与离墙恢复。尚非武器网格逐三角防穿透。
- 原创地图，建筑可进入，环境、碰撞、掩体与补给。
- 离线 1 人 + 15 机器人；在线最多 16 名参战者、空位机器人补齐。
- 机器人从静态碰撞生成导航网格，缓存绕墙/穿门路线；视线丢失后搜索最后可见位置、按需寻补给、优先进圈，带近身分离与低台阶脱困。
- 移动、奔跑、跳跃、真实蹲伏碰撞与低顶站起检查、鼠标视角、缩放瞄准、三种枪械规则、护甲、命中部位、换弹、医疗包、拾取。
- 补给按距离/环境遮挡选择可用目标，HUD 类型/余量和发光高亮；满库存不吞物资、部分转移保留余量、可靠目标编号与服务器重新验证。仍不等于完整背包。详见 [补给交互](SUPPLIES.md)。
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
- 在线射线命中延迟补偿：服务器 RTT 驱动、最大 200 毫秒、32 帧历史胶囊体、位置插值/姿态与爆头历史、静态墙遮挡；不移动真实角色。详见 [延迟补偿说明](LAG_COMPENSATION.md)。
- 输入验证、序列检查、速率控制、停发输入后的移动/射击停止、一次性联机票据；向客户端发送前检查 ENet 连接是否仍可用。
- 协议 4：跳跃/换弹/治疗/拾取/投掷/切枪使用可靠有序操作通道，独立序号去重、回合隔离、限流和过旧积压丢弃；移动通道不执行一次性操作。
- PostgreSQL 账户与战绩；Redis 票据和限速；事务、幂等统计、战绩磁盘重试队列。
- Alembic 数据库版本、旧库基线校验、并发迁移锁、事务回滚、统计约束与战绩查询索引。
- Docker 后台运行、健康检查、持久卷、日志轮转和备份脚本。
- 单机本地战绩、完成/中止分类、历史查询、独立记录原子发布、校验与备用副本读取、并发去重、失败重试和未保存退出保护；不包含进行中的对局续存。
- 单机 Esc/失去焦点真正暂停模拟、物理、计时、动画、音频和瞬态特效；菜单保持可操作，恢复/返回/退出安全清理。在线菜单不暂停服务器且明确提示风险。
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
| 导航网格、真实角色绕墙进出建筑、孤立屋顶拒绝、路径缓存、视线记忆/补给/进圈 | 通过（1,201 多边形） | `artifacts/navigation-rules.log`、`artifacts/packed-navigation.log` |
| 导航版本的枪战规则、在线整局及结算落库 | 通过 | `artifacts/navigation-combat.log`、`artifacts/navigation-full-round.log` |
| 导航版本双客户端移动/动作/手雷/声音/预测及断线回归 | 通过 | `artifacts/navigation-online.log` |
| 历史胶囊体插值/姿态/真实爆头伤害/挡墙/死亡/瞬移/上限/回合清理 | 通过 | `artifacts/lag-compensation-rules.log`、`artifacts/packed-lag-compensation.log` |
| 双向每向 70–90ms 延迟与抖动、两个真实客户端联机和服务器回溯启用 | 通过（两者回溯均 200ms） | `artifacts/lag-delayed-online.log` |
| 延迟补偿版本枪战回归及完整回合落库 | 通过 | `artifacts/lag-combat.log`、`artifacts/lag-full-round.log` |
| 可靠操作分离/投掷去重/事件视角/跳跃/换弹/治疗/切枪/旧回合/积压/限流/死亡 | 通过 | `artifacts/reliable-actions-rules.log`、`artifacts/packed-reliable-actions.log` |
| 双向 70–90ms 延迟 + 10% 随机丢包；投掷库存恰好消费一次、双客户端退出 | 通过（上行丢 176 包，下行丢 425 包） | `artifacts/reliable-loss-online.log` |
| 协议 4 API/专服拒绝旧版本及完整回合落库 | 通过 | `artifacts/reliable-protocol.log`、`artifacts/reliable-protocol-server.log`、`artifacts/reliable-full-round.log` |
| 三枪 Blender 生成、模型/骨骼挂接/瞄具枪口/不同视野/网格数量/弹药守恒 | 通过（实际 OpenGL 及打包版） | `artifacts/weapon-assets.log`、`artifacts/weapon-visuals.log`、`artifacts/packed-weapon-visuals.log` |
| 拆分武器后的角色蒙皮、手臂动作回归 | 通过 | `artifacts/weapon-animation.log`、`artifacts/weapon-viewmodel.log` |
| 双客户端依次切换三把枪并验证远端模型、整局落库、内容版本检查 | 通过 | `artifacts/weapon-online.log`、`artifacts/weapon-full-round.log`、`artifacts/weapon-protocol.log` |
| 三枪第一人称及第三人称实际画面 | 已检查 | `artifacts/weapon-0-hip.png` 至 `artifacts/weapon-2-aim.png`，共六张 |
| 三枪近墙阻挡、转向/枪长/蹲伏/起点重叠、弹药保护、收枪/瞄准/HUD/恢复 | 通过（实际 OpenGL 及打包版） | `artifacts/weapon-obstruction.log`、`artifacts/packed-weapon-obstruction.log` |
| 近墙枪管参数与 Blender 挂点一致 | 通过 | `artifacts/packed-weapon-visuals.log` |
| 近墙版本枪战、联机、整局落库、内容兼容回归 | 通过 | `artifacts/obstruction-combat.log`、`artifacts/obstruction-online.log`、`artifacts/obstruction-full-round.log`、`artifacts/obstruction-protocol.log` |
| 实际收枪与受阻提示画面 | 已检查 | `artifacts/weapon-obstruction.png` |
| 单机暂停的模拟/刚体/手雷引信/换弹/动画/音频/特效寿命/反馈计时、Esc/焦点/恢复/离开/暂停中退出 | 通过（实际 OpenGL 及打包版） | `artifacts/pause-rules.log`、`artifacts/packed-pause.log` |
| 两个真实客户端在线菜单期间对局快照继续推进、恢复操作与退出 | 通过 | `artifacts/pause-online.log` |
| 暂停版本完整回合落库与版本兼容 | 通过 | `artifacts/pause-full-round.log`、`artifacts/pause-protocol.log` |
| 单机暂停菜单和冻结特效画面 | 已检查 | `artifacts/solo-pause.png` |
| 补给满库存/部分取用/多人先后取用守恒、护甲小数、遮挡/距离/编号/重放/回合、提示与实体更新 | 通过（实际 OpenGL 及打包版） | `artifacts/supply-rules.log`、`artifacts/packed-supplies.log` |
| 真实登录客户端的部分余量、库存、重复目标拒绝、实体位置/移除同步 | 通过 | `artifacts/supply-network.log` |
| 补给版本双客户端操作、整局落库和协议 5 兼容 | 通过 | `artifacts/supply-online.log`、`artifacts/supply-full-round.log`、`artifacts/supply-protocol.log` |
| 独立弹匣、切枪防自动装弹、计时/不足储备换弹、快照复制、HUD 与死亡保护 | 通过（实际 OpenGL 及打包版） | `artifacts/magazine-rules.log`、`artifacts/packed-magazines.log` |
| 弹匣版本完整回合落库及协议 6 兼容 | 通过 | `artifacts/magazine-full-round.log`、`artifacts/magazine-protocol.log` |
| 双客户端三枪开火/切回保留弹量、储备守恒及断开确认 | 通过 | `artifacts/magazine-online.log` |
| 淘汰实际库存转移、弹匣回收、重复/空库存/编号/部分取用/回合清理 | 通过（源码、实际 OpenGL 与打包版） | `artifacts/death-loot-render.log`、`artifacts/packed-death-loot.log` |
| 真实鉴权客户端淘汰物资余量同步、拾取去重与实体移除 | 通过 | `artifacts/death-loot-network.log` |
| 淘汰物资版本整局落库与兼容检查 | 通过 | `artifacts/death-loot-full-round.log`、`artifacts/death-loot-protocol.log` |
| 背包按钮、指定拾取、余量、切枪/换弹/治疗、输入隔离及关闭生命周期 | 通过（实际 OpenGL 及打包版） | `artifacts/inventory-rules.log`、`artifacts/packed-inventory.log` |
| 图形窗口真实鉴权客户端背包选择/切枪/余量同步及鼠标捕获 | 通过 | `artifacts/inventory-network.log` |
| 背包版本双客户端、整局落库与兼容检查 | 通过 | `artifacts/inventory-online.log`、`artifacts/inventory-full-round.log`、`artifacts/inventory-protocol.log` |
| 主动丢弃守恒、合并、另一角色取用、重放/数量/治疗/限流/旧回合保护 | 通过（源码及打包版） | `artifacts/drop-rules.log`、`artifacts/packed-drop.log` |
| 图形窗口真实客户端丢弃/重放拒绝/回收与背包视觉回归 | 通过 | `artifacts/drop-network.log`、`artifacts/drop-inventory-render.log` |
| 协议 7 兼容及整局落库 | 通过 | `artifacts/drop-protocol.log`、`artifacts/drop-full-round.log` |
| 房间目录并发名额/用户占位、票据绑定/一次消费、心跳/回合/过期边界 | 通过（真实 Redis，7 项测试） | `artifacts/rooms-tests.log` |
| 新目录 HTTP 鉴权、双地址分配、用户预留和并发消费 | 通过（合成心跳，非双 Godot 专服） | `artifacts/rooms-http.log` |
| 房间目录部署后原账户/匹配/结算接口回归 | 通过（5 项测试） | `artifacts/rooms-backend-regression.log` |
| 两个真实 Godot 专服与两个客户端、独立回合/名单及空房再分配 | 通过 | `artifacts/multiroom-live.log` |
| 停止空闲第二专服、12 秒过期拒绝匹配、恢复为新实例 | 通过 | `artifacts/multiroom-failure.log` |
| 新房间入口双客户端枪战、背包拾取丢弃、完整回合落库与版本检查 | 通过 | `artifacts/multiroom-online.log`、`artifacts/multiroom-drop-network.log`、`artifacts/multiroom-full-round.log`、`artifacts/multiroom-protocol.log` |
| 新匹配入口 70–90 ms 单向延迟与 10% 丢包、可靠退出与断开确认 | 通过（有限时长） | `artifacts/multiroom-loss.log` |
| PostgreSQL 备份目录和两个独立结算队列 | 通过（未做恢复演练） | `artifacts/multiroom-backup.log` |
| 取消预留归属、消费竞争、旧回合及立即再分配 | 通过（真实 Redis 10 项测试与 HTTP） | `artifacts/cancel-rooms-tests.log`、`artifacts/cancel-http.log` |
| 取消后的迟到响应与单机隔离、原请求凭据来源 | 通过（源码及打包版） | `artifacts/cancel-connection-rules.log`、`artifacts/packed-cancel-connection.log` |
| 真实图形客户端取消无法连接的目标并立即重新分配 | 通过 | `artifacts/cancel-network.log` |
| 取消版本双客户端正常入场、整局落库与兼容检查 | 通过 | `artifacts/cancel-online.log`、`artifacts/cancel-full-round.log`、`artifacts/cancel-protocol.log` |
| 补给目标提示与高亮画面 | 已检查 | `artifacts/supply-prompt.png` |

20 倍速测试用于验证完整流程，不代表实时性能、弱网适应性或长期稳定性。双客户端验证不等于 16 真人并发验证。

预测规则测试在同一物理世界中独立模拟权威角色和客户端角色，延迟 200 毫秒投递权威快照，覆盖移动切换并测得约 0.164 米峰值误差。这是可重复的单向快照延迟测试，不代表双向网络抖动/丢包或动态玩家碰撞验证。

另有真实 UDP 代理的双向延迟/抖动联机测试：每向 70–90ms、两个客户端、约 26 秒，验证开局/动作/手雷/音效/校正/退出和服务器回溯启用。它没有注入丢包，也未测量该网络条件下的瞄准误差分布或长期稳定性。历史目标伤害由独立规则测试验证。

协议 4 另跑了同条件叠加 10% 独立随机丢包的测试，记录实际上下行丢弃数量，并检查每个客户端只消费一枚手雷。该次短时测试通过，不等于所有丢包分布、长突发断流或重连已解决，也不证明随机丢弃恰好命中了指定操作的数据包。可靠通道的序号去重和一次消费由独立规则测试补充验证。

## 距离用户要求的完整游戏仍缺少

以下都是未完成工作，不能用菜单占位或接口存在宣称完成。

1. **枪战体验**：预测校正与延迟补偿在双向延迟/抖动/丢包下的系统调优、实际渲染时间对齐、武器专属第一人称动作/手指握持/第三人称近墙姿态及防穿透细化、方向混合/脚步 IK/攀爬动作、枪械差异化后坐力调校、环境声/混响/专业混音、动作细节与过渡打磨、趴下/攀爬。
2. **玩法内容**：跳伞部署、车辆、组队、复活/救援、背包与配件、烟雾/闪光/燃烧等其他投掷物及完整投掷动画、多地图、多模式、延迟/队伍观战与回放、教程与局内存档/续局。
3. **机器人**：战术掩体评分、系统性搜索与难度分层、拥挤门口的群体避让；现有导航覆盖静态建筑，目标记忆只保留最后可见位置三秒。
4. **多人服务**：自动扩缩容调度、排队与区服选择、断线重连、会话迁移、多版本共存与滚动升级、跨服账户会话约束、好友与队伍。
5. **长期运营**：大数据量在线迁移与运行/迁移角色分离、管理工具、可观察性指标、资源限制与容量模型、灰度发布、灾备恢复演练、赛季与进度系统。
6. **安全与合规**：游戏传输加密、完整反作弊、审计与封禁、账号找回与邮件验证、隐私流程、面向目标市场的法规要求。公网账号入口的 HTTPS 尚需实际域名与部署环境。
7. **发行品质**：美术与场景质量、动画与 UI 无障碍、中文本地化、性能预算、16 真人/高延迟/丢包/长时间测试、Windows/macOS/移动端打包验证。

第三人称已使用真实骨骼蒙皮动作，蹲伏不再缩放整个模型；动作仍需手工美术打磨、方向混合和脚步 IK。第一人称已有蒙皮手臂与瞄具对齐，三种枪械已有独立外观和瞄具/枪口挂点，手指握持和武器专属动作尚需完善。场景使用低多边形美术。移动预测及有上限的射击延迟补偿已实现，但弱网和移动玩家之间的碰撞仍需系统验证。

## 后续推进顺序

1. 继续改进预测/校正、枪战延迟补偿、武器专属动作与声音设计，不破坏已经验证的权威模拟。
2. 继续实现可独立测试的房间调度，补重连和服务指标；迁移基础已经完成。
3. 扩展背包/配件/其他投掷物、队伍与观战权限，再进行内容与美术制作。
4. 增加弱网、满员和长时间测试，扩大平台发行范围。

## 后台边界

正常游戏服务由 Docker 独立运行，退出终端不会主动停止容器。宿主机停机或 Docker 停止会影响服务。后台 AI 开发取决于 Codex 平台的 Goal 调度和任务生命周期；本仓库没有创建能绕过平台生命周期、在任意界面退出后仍保证无限开发的代理进程。

本轮追加：蹲伏与开火高度统一在权威模拟计算；命中反馈只发给射手/受击者，不广播敌人伤害信息。瞄准与姿态字段改变了输入协议，部署时客户端与服务端必须一起更新。

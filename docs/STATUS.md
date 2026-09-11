# 开发状态 — 2026-09-11

**Goal 保持 active；用户要求的完整商业级游戏尚未完成。当前交付是已运行、已联调、有完整单局循环的开发版本，不应称为《和平精英》级成品。**

当前开发发行版本为 **0.35.0-dev / 协议 16 / 数据库 0004**。发布 API 运行于 8000，单人专服 UDP 27015，双人专服 UDP 27022；PostgreSQL、Redis 和专服均配置自动重启。独立开发环境 8001 / 27031 继续保留。

双人分队、友伤限制、倒地救援、队伍观战、共享标点、邀请/准备/重开、分模式战绩、本地检查点、Blender 倒地动画及默认关闭的队内语音已接入发布包。包内规则、渲染、四客户端战斗与战绩落库、发布端口单人同步和双人连续两局、虚拟麦克风驱动均已验证。物理麦克风、耳机及实际网络环境验收仍未完成；其他完整商业级功能缺口仍需继续开发。

默认包 `artifacts/IronMeridian-Linux-x86_64.tar.gz` 已更新为经过验证的候选包，校验和 `2b4bc239ed615949237f8a4cba572315bc0cfde157d22a28993b4b71f95b0a27`。0.34 的包和运行目录保留在 `artifacts/releases/0.34/`。候选构建源提交为 `9e73c12a`。详见 [候选包验证](CANDIDATES.md)、[本次运行服务升级](RELEASE_035.md) 和 [语音验证范围](VOICE.md)。

正在 `feature/vehicles` 分支开发载具：源码单机 solo/duo 对局已自动在道路生成 4 辆越野车，驾驶、乘员、相机、战斗/撞击、耐久/燃料、存档与地图边界已验证。步行机器人绕车已验证；车辆快照、客户端代理、帧配对缓冲与真实 ENet 广播已验证；开发源码升级为 0.36.0-dev / 协议 17 / 内容 18，驾驶输入与会话/座位校验已接入并通过规则及 ENet RPC 测试；真实账号登录入场后的 solo/duo 双客户端驾驶、乘坐、制动和安全下车已通过；行驶中账号撤销和驾驶客户端强制断线后的制动、座位释放、乘客安全下车也已验证；受控延迟/乱序/丢包及三秒上行中断后的制动和恢复也已验证；载具空间发动机/轮胎/制动声音已接入并通过 PCM 与双客户端检查；车体网格及坐姿蒙皮命中盒已接入直接射击、机器人视线和延迟补偿，并通过真实伤害检查；solo/duo 三客户端移动车辆交火链路已通过；移动瞄准时差已按观测校准，保护期后 solo/duo 复验均首发命中；新增实测 30/120 FPS 与单向 30 ms 延迟的三组交火检查均首发命中，短时直线场景以外仍待验证；已修正着地侧坡重力导致的横向漂移，并验证规则坡面驾驶、停车和离地后落地；载具观战的支点、车辆遮挡和上下车切换已修正并通过实际渲染检查，真实三客户端在固定延迟及抖动/丢包/中断下的跟车与下车也已通过；机器人平坦直线进圈用车已接入，并验证走近上车、驾驶、制动下车和动态障碍停车；已修复机器人恢复存档时的意外转向，并验证 solo/duo 中途恢复后停车及乘客安全；真实账号乘坐系统分配的机器人队友车辆，在 30 FPS/单向 30 ms 延迟下的驾驶同步已通过；公网驾驶手感、复杂机器人驾驶及新发布包仍待完成；当前运行包保持 0.35.0-dev。详见 [载具开发](VEHICLES.md)。

0.36 已生成独立候选包（尚未发布）：`artifacts/candidates/0.36.0-dev-8245350d-mdczhhx9/`，63,196,528 字节，SHA-256 `31357a83d0fcf6896cf8bc0c6acfa4b3c4c408528626f18f3afa4af169a54895`。导入、导出、42 项包内规则、解压后默认入口及四项实际渲染检查通过；候选 PCK 已通过载具驾驶/音频/交火/受损网络观战/机器人驾驶及四客户端邀请队伍救援、语音和战绩落库联调；正常时间 solo/duo 两场自然对局结算与落库已通过（约 82.3/99.5 秒，两场未观察到机器人驾驶）。与候选包文件一致的非 root 专服镜像已构建并验证，尚未部署；发布切换仍待完成。详见 [候选包](CANDIDATES.md)。

## 已实际实现

- 主动取消治疗：再次按治疗键或使用背包按钮取消，保留未消耗的医疗包；可靠的独立取消意图防止迟到消息误开第二次治疗。机器人避险使用同一规则。详见 [医疗包](HEALING.md)。

- 机器人近距离破片手雷避险：识别暴露风险、查询导航逃生路线、暂停烟雾驻留并跑离爆心，保留正常物理和伤害规则。详见 [机器人手雷避险](BOT_HAZARDS.md)。

- 机器人烟雾自救与投掷冷却：实际寻找/拾取烟雾，在缺少实体掩体时投掷、等待烟雾遮挡再治疗，进圈优先；使用正常库存与权威物理。详见 [机器人投掷物](BOT_UTILITIES.md)。

- 联机 HUD 网络状态：实际 ENet RTT/波动、有效快照更新时间、延迟与更新停顿提示、自动恢复及回合隔离。详见 [网络状态](NETWORK_STATUS.md)。

- 淘汰报告：观战时显示权威致命一击的攻击者、武器或环境原因、爆头、距离及实际生命/护甲损失；只向受害者发送，新回合清理。详见 [淘汰报告](DEATH_RECAP.md)。

- 单机单槽保存/继续：回合 ID、角色库存与计时、缩圈、随机状态、物资、在途投掷物和烟雾；校验、原子替换、上一份备份、失败留在暂停界面及已结算回合恢复隔离。详见 [单机保存](SOLO_CHECKPOINTS.md)。

- 键盘改键：主菜单/暂停菜单入口、物理键捕获、按战斗/观战上下文检查冲突、本地原子保存、失败保留旧配置、恢复默认及动态 HUD 提示。详见 [控制设置](CONTROLS.md)。

- 权威落地伤害：安全跳跃阈值、冲击能量扣血、护甲不吸收坠落伤害、治疗中断及致命坠落的淘汰/掉落流程，客户端预测不重复扣血。详见 [坠落](FALL_DAMAGE.md)。

- 烟雾弹：Blender 独立罐体、V 键可靠投掷、独立库存/补给/丢弃/淘汰回收、权威 20 秒生命周期、深度遮挡渲染与机器人视线影响。详见 [烟雾弹](SMOKE_GRENADES.md)。

- Z/C 左右探身：视点、碰撞体和第三人称同步倾斜，贴墙限制、移动减速、服务器快照、客户端预测与倾斜命中回溯。详见 [探身](LEANING.md)。

- 地形约束圈心与机器人提前转移：终圈圆盘避开静态建筑、掩体和树干，600 个圈心通过实际碰撞与导航连通性检查；等待阶段按距离预留转移时间。详见 [安全区](SAFE_ZONES.md)。

- 六阶段移动安全区：等待／收缩倒计时、嵌套随机圆心、地图下一圈预告、权威圈外判断与偏心跑圈机器人。详见 [安全区](SAFE_ZONES.md)。

- M 键战术地图：由场景生成的道路/建筑/散布掩体、当前安全区与朝向、个人路标及 HUD 水平距离，包含输入隔离和回合清理。详见 [战术地图](TACTICAL_MAP.md)。

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
- 单机本地战绩、完成/中止分类、历史查询、独立记录原子发布、校验与备用副本读取、并发去重、失败重试和未保存退出保护；进行中的单机续存使用独立检查点文件。
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
| 战术地图几何/坐标/路标边界/距离/输入隔离/菜单互斥/回合清理 | 通过（实际 OpenGL 及打包版） | `artifacts/tactical-map-rules.log`、`artifacts/packed-tactical-map.log` |
| 图形窗口真实联机地图、权威位置/安全区与对局持续推进 | 通过 | `artifacts/map-network.log` |
| 地图版本整局落库、兼容检查及菜单提示渲染 | 通过 | `artifacts/map-full-round.log`、`artifacts/map-protocol.log`、`artifacts/map-menu.log` |
| 补给目标提示与高亮画面 | 已检查 | `artifacts/supply-prompt.png` |

20 倍速测试用于验证完整流程，不代表实时性能、弱网适应性或长期稳定性。双客户端验证不等于 16 真人并发验证。

预测规则测试在同一物理世界中独立模拟权威角色和客户端角色，延迟 200 毫秒投递权威快照，覆盖移动切换并测得约 0.164 米峰值误差。这是可重复的单向快照延迟测试，不代表双向网络抖动/丢包或动态玩家碰撞验证。

另有真实 UDP 代理的双向延迟/抖动联机测试：每向 70–90ms、两个客户端、约 26 秒，验证开局/动作/手雷/音效/校正/退出和服务器回溯启用。它没有注入丢包，也未测量该网络条件下的瞄准误差分布或长期稳定性。历史目标伤害由独立规则测试验证。

协议 4 另跑了同条件叠加 10% 独立随机丢包的测试，记录实际上下行丢弃数量，并检查每个客户端只消费一枚手雷。该次短时测试通过，不等于所有丢包分布、长突发断流或重连已解决，也不证明随机丢弃恰好命中了指定操作的数据包。可靠通道的序号去重和一次消费由独立规则测试补充验证。

## 距离用户要求的完整游戏仍缺少

以下都是未完成工作，不能用菜单占位或接口存在宣称完成。

1. **枪战体验**：预测校正与延迟补偿在双向延迟/抖动/丢包下的系统调优、实际渲染时间对齐、武器专属第一人称动作/手指握持/第三人称近墙姿态及防穿透细化、方向混合/脚步 IK/攀爬动作、枪械差异化后坐力调校、环境声/混响/专业混音、动作细节与过渡打磨、趴下/攀爬。
2. **玩法内容**：跳伞部署、车辆、组队、复活/救援、背包与配件、闪光/燃烧等其他投掷物及完整投掷动画、多地图、多模式、延迟/队伍观战与回放、进阶教程、多槽/自动存档及失败后重试。
3. **机器人**：多敌人威胁评估、掩体间转移/探身射击、系统性搜索与难度分层、拥挤门口的群体避让；现有导航覆盖静态建筑，目标记忆只保留最后可见位置三秒。
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

### 基础训练（0.24）

新增独立九步交互课程，使用真实移动、武器命中、拾取、换弹、治疗、投掷物和地图系统。固定三个靶标，玩家免伤、无缩圈推进、无战绩写入、禁止保存训练进度；既有单机存档可继续。自动化测试覆盖完整课程及存档/战绩隔离。当前不含进阶战术、车辆或团队训练。

### 16 客户端并发门禁（0.24）

新增 `tools/test_capacity.py` 与真实 Godot 客户端脚本，使用普通认证、房间票据和 ENet 通道。实际通过：16 个独立进程、16 个不同 peer、同一回合、无机器人占位，房间目录确认 16 名玩家。8 秒持续移动/射击期间，每个客户端都观察到 16 个角色发生移动、弹药消耗和持续校正；服务器时间推进 7.95–8.05 秒。第 17 个账号申请这个已满且进行中的房间返回 503，全部正常退出后房间以新回合 ID 恢复等待。

证据：`artifacts/capacity-1789010349222806928/report.json` 及同目录逐客户端/服务器日志。工具尊重真实登录限流，重复执行时先等待剩余额度；失败记录保留用于诊断。此次为同机、无图形渲染、短时功能并发验证，不等同于 16 真人体验、整局、弱网或长期负载验证。详见 `docs/CAPACITY_TESTING.md`。

### 备份清单与实际数据库恢复演练

`tools/backup.sh` 现在调用 Python 工具，以唯一临时目录生成 PostgreSQL 转储和两个战绩队列，写入文件长度/SHA-256 清单，校验后发布目录。`tools/restore_drill.py` 将备份恢复至无网络、不挂载正式卷的临时 PostgreSQL 容器，执行结构/外键/约束检查，清理容器后发布报告。

实际恢复了 49 个账号、80 场对局、123 条结果，迁移版本 0002，未发现孤立/重复结果、非法统计或未验证约束。完整性测试覆盖转储损坏、缺失队列、无效队列结构和未知清单版本，均在创建容器前拒绝。证据：`artifacts/restore-drill.json`、`artifacts/backup-integrity.log`、`artifacts/backup-manifest.log`。两个队列此次均为空，未验证非空队列重放；数据库与队列不是协调快照，跨主机灾备和正式应用切换仍未完成。

### 机器人战术掩体（0.25）

低血量、空弹匣或换弹中的机器人，会根据最近实际看见的敌人位置寻找附近掩体。候选点经过站姿/蹲姿两条静态遮挡射线、安全区、导航投影及可达路径长度筛选；昂贵路径查询限定为最近六个候选。抵达后蹲伏并尝试治疗/换弹，安全区撤离优先并清理掩体目标。目标有有限保持时间，不读取墙后敌人的最新位置。

真实物理测试覆盖绕行到达、遮挡成立、蹲伏治疗完成、未知威胁不搜索和撤离覆盖。掩体状态是导航层临时状态，读档后重新评估；现有存档格式与网络协议保持兼容。当前没有多敌人交叉火力分析、路径沿途暴露评分、探身射击或团队掩护。

### 多方向受击提示（0.26）

将单一方向提示改为最多八个短时方向，约 0.9 秒消失，相近方位连击合并。提示保存受击当时的世界方位，随视角旋转，不随移动重新定位敌人；无水平方向的伤害不生成假方位。轮廓增加暗色描边以适应亮背景。测试覆盖真实伤害回调、方向数学、数量上限、合并、过期、暂停、观战与新回合清理；网络消息格式不变。

### 账号校验响应隐私修复

实际复现了默认 422 错误回显不合规则密码的问题。新增全局请求校验处理器，只输出固定提示和白名单字段，移除提交值/上下文，并支持客户端直接展示。13 项专用 HTTP 测试覆盖短/长/非字符串密码、非法用户名、错误请求结构、非法 JSON、缺失字段及专服模型级校验。已发布 0.26 客户端对实际 API 的错误展示测试与截图通过。证据：`artifacts/validation-privacy-tests.log`、`artifacts/validation-message.log`、`artifacts/validation-message.png`。

首次与原有集成测试合并运行共 17 项通过；扩展测试后重复执行注册集成用例触发既有小时注册限流，保留在 `artifacts/validation-repeat-rate-limit.log`，未清空或放宽限流。随后只运行新增专用测试，13 项通过。服务端补丁已部署，客户端包无需重新构建。

### 依赖故障响应与等待上限

新增 Redis 连接/读取超时与 PostgreSQL 连接/池等待故障的固定 503 提示、重试响应头及不包含连接详情的类别日志。Redis 连接/读取分别限制 2 秒，数据库建连/池等待分别限制 3 秒。四项故障注入测试通过，包括真实连接拒绝、无响应 TCP 读取超时及连接池耗尽后的恢复；正式数据库和缓存未停止。证据：`artifacts/availability-tests.log`。尚未将长时间 SQL 执行或跨主机分区恢复纳入此验证。

### 输入中断状态清理（0.27）

输入超时从仅停止移动/开火扩展到释放疾跑、瞄准、侧身和蹲伏，保留已接受的可靠跳跃及计时动作。统一移动与可靠指令的整数序号及武器选择边界。新增规则测试及保持 ENet 连接、暂停发送输入再恢复的真实客户端测试。此能力不包括断线后重连。

输入中断的实际 ENet 测试已通过：停止客户端输入发送但持续接收快照，直接检查权威姿态/速度与弹药稳定；恢复后检查权威位置及确认序号推进。证据：`artifacts/input-timeout-client.log`、`artifacts/packed-input-timeout-final.log`、`artifacts/packed-reliable-actions-final.log`。这不是网络分区或断线重连测试。

### 垂直握把完整流程（0.28 / 协议 12）

新增 Blender 原创握把和世界物资、三武器独立槽、背包安装/拆卸、20% 每发后坐力增量减免、备用库存容量及丢弃、死亡掉落、机器人自动安装、权威 RPC 与远端模型同步。单机检查点保存配件状态，并支持上一内容版本 `ash-valley-16` 在完整校验后迁移为空配件槽，保留原对局/物资。更早内容版本仍不支持。详见 `docs/ATTACHMENTS.md`。本次只包含握把，其他配件类型及手部 IK/安装动作仍未完成。

### 退出全部账户会话（0.29 / 协议 13）

数据库升级至 `0003`，持久化账户会话版本。主菜单可退出所有设备，撤销旧 JWT 和未消费票据；服务器心跳核验在线版本，通知失效客户端并断开连接。重新登录正常，单机存档内容版本不变。两个真实 Godot 客户端已验证异地退出通知、断开、旧令牌拒绝、新登录以及失败提示；数据库迁移、会话、房间和依赖故障共 26 项测试通过，包含取消旧票据不影响新登录预约。证据：`artifacts/session-logout-e2e.log`、`artifacts/session-backend-regression.log`、`artifacts/session-logout.png`。详见 `docs/ACCOUNT_SESSIONS.md`。

迁移前已备份。旧备份恢复或迁移回退可能倒退会话版本，正式开放前需要更换 JWT 签名密钥并废弃旧房间票据。在线退出依赖健康心跳，不提供服务故障期间的即时断开保证；设备列表和单设备撤销尚未实现。

本版 Linux 包通过现有玩法回归和打包后账户界面测试；普通双客户端对局及加速完整对局落库通过。升级后备份在隔离容器中恢复 51 个账户、90 场对局及 136 条结果，会话版本有效，正式库未被替换。证据：`artifacts/session-package.log`、`artifacts/session-packed-logout.log`、`artifacts/session-online.log`、`artifacts/session-full-round.log`、`artifacts/session-restore-drill.json`。测试范围仍不代表商业游戏全部功能或公网大规模运营验收。

### 权威淘汰报告（0.30 / 协议 14）

新增观战中的致命一击报告，包含来源、武器/环境原因、爆头、米级距离以及最后一击扣除的生命/护甲。生命/护甲展示取整，底层保留实际数值，不将过量伤害当作已扣除数值。报告仅可靠发送给受害者，使用在线回合编号隔离；新回合清除。安全区、坠落、手雷爆心、自伤及断线投掷者分别处理。它不包含录像回放或整场交火累计伤害。

单机规则与实际渲染、两个真实客户端的报告接收/观战/隐私、协议门禁、完整对局落库、账户退出回归及 Linux 打包玩法门禁通过。证据：`artifacts/death-recap-rules.log`、`artifacts/death-recap.png`、`artifacts/death-recap-network.log`、`artifacts/recap-protocol.log`、`artifacts/recap-full-round.log`、`artifacts/recap-session-regression.log`、`artifacts/recap-package.log`、`artifacts/packed-death-recap.log`。

### 联机网络状态（0.31 / 协议仍为 14）

新增 ENet 往返延迟和波动、有效快照更新时间、同步等待/高延迟/更新停顿提示；超过一秒未更新时告警，恢复更新后解除。单机隐藏，新回合重新测量，返回菜单清除，旧回合包不刷新状态。数据不代表丢包率、全体角色同帧到达或后台数据库健康，也不提供自动重连。

规则与打包规则通过。实际战斗中使用双向各 75ms 的 UDP 延迟，测得 RTT 180ms；阻断下行 1.8 秒、丢弃 302 个下行数据报，HUD 显示更新停顿，恢复转发后回到正常更新并保持连接。已检查实际截图。证据：`artifacts/network-status-rules.log`、`artifacts/packed-network-status.log`、`artifacts/network-status-proxy.log`、`artifacts/network-status-client.log`、`artifacts/network-status-stalled.png`。

### 机器人烟雾自救与投掷冷却（0.32）

机器人巡逻寻物资时会考虑烟雾。受伤、仍有医疗包且缺少实体掩体时，使用实际库存向近地投掷，停止射击并蹲伏，实际烟雾遮断已知威胁视线后才治疗；最多驻留 8 秒，进圈立即取消驻留。破片手雷与烟雾共享投掷成功后的战术冷却，分别为 12 / 18 秒。正常动作限制、烟雾物理与数量上限保持生效。临时决策计时不写入存档，续存后重新决策，实际物资和投掷物仍保存。

实际刚体落地、起烟、遮挡后治疗及库存/冷却/掩体/进圈规则通过；专服机器人实际拾取烟雾并完成治疗，真实客户端验证库存、飞行投掷物、烟雾和治疗同步。原有实体掩体规则和完整对局落库通过。证据：`artifacts/bot-utilities-rules.log`、`artifacts/packed-bot-utilities.log`、`artifacts/bot-utilities-network.log`、`artifacts/packed-bot-cover.log`、`artifacts/bot-utilities-full-round.log`。尚不包含通用投掷轨迹规划、团队烟墙或更完整的多威胁战术。

### 机器人近距离手雷避险（0.33）

新增近距离破片手雷识别、实体爆炸遮挡检查、导航逃生点及路径筛选、已知危险短程跟踪和缓存路线重算。有效逃生路线覆盖交火移动与烟雾驻留，停火并请求疾跑；爆炸消失或被实体完全遮挡后恢复普通战术。治疗减速、碰撞和伤害仍然有效；算法有候选/路径预算和圈界限制，不保证所有复杂场景都能避开爆炸。

规则测试与打包后的新增/移动危险重算测试通过：机器人实际跑离两枚手雷，爆炸后生命保持 100。专服与真实客户端的逃生位置、投掷物、生命同步通过；烟雾自救回归和完整对局落库通过。证据：`artifacts/bot-hazards-rules.log`、`artifacts/packed-bot-hazards-final.log`、`artifacts/bot-hazards-network.log`、`artifacts/packed-bot-utilities.log`、`artifacts/bot-hazards-full-round.log`。详见 `docs/BOT_HAZARDS.md`。

### 主动取消治疗（0.34 / 协议 15）

治疗键与背包支持主动取消，HUD 显示绑定按键。取消不回血、不消耗医疗包，恢复正常移动能力。独立 `cancel_heal` 可靠意图与严格输入结构、回合隔离、操作序号及限流结合：迟到取消不会开启第二次治疗，旧取消不能打断新治疗；开始与取消同时为真的指令被拒绝。机器人在手雷逃生时使用相同取消方法，并避免立即重新治疗。

规则、打包规则、真实专服的取消/完成/迟到/重放场景、机器人避险回归、完整对局落库及旧协议拦截通过；Linux 发行包玩法门禁通过。证据：`artifacts/heal-cancel-rules.log`、`artifacts/packed-heal-cancel.log`、`artifacts/heal-cancel-network.log`、`artifacts/packed-bot-hazards.log`、`artifacts/heal-cancel-full-round.log`、`artifacts/heal-cancel-protocol.log`、`artifacts/heal-cancel-package.log`。数据库和存档结构不变，旧网络协议客户端需要更新。

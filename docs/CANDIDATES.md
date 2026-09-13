# 独立 Linux 候选包

`tools/package_candidate.py` 要求干净且已提交的工作区，将当前 Godot 工程导出到独立的 `artifacts/candidates/<版本>-<提交>-<随机标识>/`，不会覆盖现有 `artifacts/IronMeridian-Linux-x86_64.tar.gz`。

运行：

```sh
.venv/bin/python tools/package_candidate.py
```

流程记录源提交、协议清单、每项检查及耗时。导入与导出成功后，使用复制的游戏执行文件和导出的 PCK 运行 50 项检查，覆盖清单一致性、双人分队/救援/观战/共享标点/邀请界面/本地战绩/检查点、单人保存兼容、按键、治疗、机器人投掷、背包、缩圈和语音组件，以及载具驾驶、坡面、座位、命中、音频、观战、存档、机器人驾驶、队友上车等待、主动搭乘和网络规则。检查必须出现对应成功标记，且不能包含脚本错误、断言失败或对象泄漏。玩家测试数据写入独立临时目录；不访问生产账号。所有检查完成后才生成压缩包，写入压缩包及 PCK 的 SHA-256。

构建失败会保留日志和失败状态，不将失败目录当作通过的候选包。成功报告中的 `scope` 仅说明包内离线规则验证，不代替网络、渲染或物理音频设备验收。后续发布仍需相应回归与服务版本切换。

## 0.38 候选（已作为开发版本发布）

源码版本为 0.38.0-dev，协议 17、资源 ash-valley-18、数据库 0004 不变；在线仍要求完整版本清单匹配。新增安全路线可用时提前转移、驾驶员等待队友与危险中断、机器人主动搭乘及安全下车。独立开发服务、发布服务及默认归档均为 0.38。

- 源提交：`484d98d958a0973d5dc630ce6474dcdcba950035`。
- 目录：`artifacts/candidates/0.38.0-dev-484d98d9-ssm8gza_/`。
- 归档：63,217,821 字节，SHA-256 `e2a94bca580253e22f4df38d9fc3ec145d4d8fc139e874ece5aa9297212bcb69`。
- 导入、导出及 48 项包内规则共 50 项检查通过；`artifacts/candidate-038-build-final.log`。
- 从归档重新解压、使用全新用户目录执行默认 `play.sh --headless -- --smoke` 通过；候选内 `archive-startup.json`、`logs/archive-startup.log`。
- 4 项实际 OpenGL 渲染检查通过：角色动画、倒地动画、语音设置界面和载具观战；`render-verification/verification.json`。
- 后端在隔离 Docker 内网、临时 PostgreSQL/Redis 中通过 95 项测试，无跳过；一项第三方 Starlette 弃用警告。`backend-verification.json`、`logs/backend-tests.log`。
- 专服镜像以非 root 用户运行，执行文件/PCK/build.json 与候选逐字节一致，禁用网络启动检查通过；`server-image.json`。

后端镜像 `iron-meridian-api:0.38-484d98d9` 固定 ID 为 `sha256:62e6c5e6813bc83f52f89a1932ad0b92cc4e94bab0081eb581f819a94b7e1ed2`；专服 `iron-meridian-candidate:484d98d958a0` 固定 ID 为 `sha256:00e5f2831d82dafc5069794766f5c54df16f27986a55f2f1acd8dd438129db31`。两者已用于独立开发服务。

首次候选 `0.38.0-dev-37471e67-1sovf4g8` 在 37 项检查后因乘客测试中间日志被识别为额外成功标记而失败，未生成合格归档。修正日志命名并提交后完整重建通过，失败目录保留。后续打包联网、自然对局及发布验证已完成；本候选不等于完整商业游戏。

### 0.38 存量数据与开发环境

发布环境备份 `artifacts/backups/20260913T001854Z-0aa0cf81` 在隔离 PostgreSQL 中恢复，通过新后端的 0004 幂等启动。55 个账号、112 场对局、169 条玩家结果的全字段指纹不变，约束、队伍和账号统计一致；未回灌线上数据库。报告 `artifacts/candidate-038-startup-restore.json`。初次编排命令因 Python 模块搜索路径错误在任何备份动作前退出，调整导入路径后执行成功。

`deploy_candidate_dev.py --with-api` 在开发房间无人、无预约、结果队列为空时备份开发数据库并升级 API/专服。前后 users、matches、results 全字段指纹一致，保留现有 PostgreSQL/Redis 数据卷和旧镜像 ID，容器自动重启策略为 `unless-stopped`。备份在候选目录 `dev-backup/database.pgdump`，权限 0600；报告 `dev-deployment.json`，日志 `artifacts/candidate-038-dev-deploy.log`。本次没有触发失败回退。

开发 API 8001、双人专服 UDP 27031 为 0.38；发布 API 8000 及专服亦已升级为 0.38。重启开发固定镜像使用：

```sh
docker compose --env-file artifacts/duo-dev.env -f compose.duo-dev.yaml -f artifacts/duo-candidate.override.json up -d --no-build
```

打包客户端在 30 FPS、固定单向 150 ms 下通过机器人驾驶员等待上车、行驶、制动和双方下车回归，服务器等待 82 个物理帧后乘客正常入座。汇总 `artifacts/candidate-038-bot-boarding.log`，报告前缀 `artifacts/vehicle-login-duo-bot-driver-boarding-wait-fps30-delay150-packed-484d98d9-`。这是自动化真人账号乘客验证，不是机器人作为乘客的专项联网验证，也不代表公网体验。

两个打包客户端通过开发服务正常邀请、接受、准备、准入和同队快照，保持同一队伍连续进入两局。汇总 `artifacts/candidate-038-dev-requeue.log`，客户端日志 `artifacts/candidate-484d98d9-party-requeue-{0,1}-{0,1}.log`；测试绑定上述候选归档哈希，不是自然完整对局结算验证。

### 0.38 正常对局与四客户端组队战斗

同一候选包在正常时间比例下分别完成 solo / duo 对局，每场为一个自动化账号客户端、15 个正常机器人和 4 辆车；无胜负或缩圈覆盖。solo 约 92.48 秒，客户端第 16 名；duo 约 81.80 秒，队伍第 7 名。客户端结算、数据库结果及分模式账号统计增量一致，服务端和客户端日志无脚本错误或泄漏标记。报告为候选内 `natural-round-{solo,duo}/verification.json`，汇总日志 `artifacts/candidate-038-natural-{solo,duo}.log`。

两场机器人驾驶帧数均为零。每秒只读采样中，solo 共 607 个存活机器人样本：504 次附近无车、83 次附近有车但交战、19 次转移距离不足、1 次健康/治疗条件不符；duo 共 852 次，747 次附近无车、105 次交战。没有采到接近或入座状态。该有限采样不能证明所有瞬时机会都不存在，也不能证明新协作提高了自然用车率；完整对局通过不能替代此玩法质量验证。

四个打包客户端组成两支邀请队伍，通过正常输入触发倒地、两次救援中断和成功救援，完成队伍胜负、4 条结果落库、分模式统计与结果队列重载。四客户端赛后返回队伍、战术标点按队隔离、合成语音包转发和解码也通过。汇总 `artifacts/candidate-038-party-combat.log`；这些受控验证不等于物理麦克风验收或公网长期运行。

### 0.38 网络异常和移动交火

- 三个打包客户端、30 FPS 的载具观战通过固定测试网络的 50–100 ms 单向延迟、3% 丢包和 3 秒上行中断。服务端确认输入超时制动及输入恢复后重新行驶。汇总 `artifacts/candidate-038-impaired-spectator.log`；详细报告前缀 `artifacts/vehicle-login-duo-impaired-spectator-fps30-packed-484d98d9-`。
- 两客户端分别通过驾驶员断线和账号撤销后的制动、驾驶位释放及乘客安全流程。撤销场景确认驾驶输入立即清理。汇总 `artifacts/candidate-038-{drop,revoke}.log`；详细报告前缀 `artifacts/vehicle-login-duo-{drop,revoke}-packed-484d98d9-`。
- 三客户端、30 FPS、单向 30 ms 下，通过正常输入射击移动中的驾驶员。命中时车速约 13.33 m/s，驾驶员生命降至 77，车体仍为 600、副驾驶生命仍为 100，射手消耗一发弹药，服务端回溯命中检查通过。汇总 `artifacts/candidate-038-combat.log`；详细报告前缀 `artifacts/vehicle-login-duo-combat-fps30-delay30-packed-484d98d9-`。

以上均使用相同候选包和真实账号准入；受控丢包恢复不等于断线后重新登录并重返原对局的重连功能，也不等于公网长时间测试。

### 0.38 机器人副驾驶联网

`tools/test_vehicle_login.py --mode duo --bot-rider --client-fps 30 --latency-ms 150 --candidate-dir ...` 使用一个真实账号自动客户端驾驶、一个正常分配的机器人队友作为副驾驶。服务器和客户端均加载此候选包；夹具只将参与角色放到车门附近、将其他机器人放到交战距离外，通过正常 AI 和座位检查上车，不直接给机器人设置座位或驾驶指令。

服务器验证正常 AI 上车、随车行驶、停稳后跟随驾驶员离车及下车冷却；客户端验证同队机器人座位同步、移动中乘员存在和最终座位释放。30 FPS、固定单向 150 ms 场景通过，报告前缀 `artifacts/vehicle-login-duo-bot-rider-fps30-delay150-packed-484d98d9-`，汇总 `artifacts/candidate-038-bot-rider.log`。这证明受控网络搭乘流程，不证明自然搭乘频率、真人驾驶体验或公网稳定性。

新增分支后，原有机器人驾驶员等待真人账号乘客上车场景在 30 FPS、单向 30 ms 下回归通过，日志 `artifacts/candidate-038-rider-driver-regression.log`。运行中的发布服务和默认归档已升级至 0.38，详见 [发行记录](RELEASE_038.md)。

## 0.37 候选（已作为开发版本发布）

- 版本：0.37.0-dev / 协议 17 / 资源 ash-valley-18；数据库无需迁移。
- 源提交：`967bc7d9281691b12fc9e6c788c93b23b6649458`。
- 目录：`artifacts/candidates/0.37.0-dev-967bc7d9-0vrlx33n/`。
- 压缩包：63,206,876 字节，SHA-256 `68321608692a9c4702698dfc9b3a1fd44ce7bcaf2bc9f62b3924ae438b4e9e7e`。
- 导入、导出及 45 项包内规则，共 47 项检查通过；构建日志 `artifacts/candidate-037-build.log`。
- 从归档重新解压后执行默认 `play.sh --headless -- --smoke` 通过；候选内 `logs/archive-startup.log`。
- 实际 OpenGL 渲染的角色动画、倒地动画、语音界面及载具观战通过；`render-verification/verification.json` 和 `artifacts/candidate-037-render.log`。

本候选包含机器人平坦开放区域转向驾驶、转弯动态障碍和存档恢复检查，以及下车车体跳位、疾跑穿入、车体移出场景后移动卡住的修复。包内测试新增三个场景；辅助场景日志统一为 OK，保留每个脚本唯一的整体 PASS 标记，避免把局部通过当作整项通过。

源码联网场景已有记录，但此候选已完成开发服务切换和部分打包联网验证；正常时间自然对局及下述组队/受损网络回归已通过，账号撤销、断线与移动交火检查也通过，发布与开发 API 均已升级为 0.37；离线 SOLO/DUO 可运行。旧 0.36 压缩包已归档，其 SHA-256 为 `31357a83d0fcf6896cf8bc0c6acfa4b3c4c408528626f18f3afa4af169a54895`，已核对未变化。复杂道路寻路、绕障、倒车脱困和商业级完整体验仍未完成。

### 0.37 后端与专服镜像

后端镜像 `iron-meridian-api:0.37-967bc7d9` 的固定 ID 为 `sha256:b34066b045a95f39cb81d12b17b940ab4e2357d3af94f6a523a9a3ca1463bf26`。它在内部 Docker 网络、临时 PostgreSQL 与 Redis 中通过 95 项测试，无跳过；有一项第三方 Starlette 弃用警告。报告为候选目录内 `backend-verification.json`，日志 `logs/backend-tests.log`。

专服镜像 `iron-meridian-candidate:967bc7d92816` 的固定 ID 为 `sha256:98458f71e3d9fc80f1f2c5ea03e8ed2561d012e015f6958d99f534c40533a874`。镜像内执行文件、PCK 和 build.json 与候选包逐字节一致，以非 root 用户运行，禁用网络的离线启动检查通过。报告 `server-image.json`；已部署至独立开发专服 UDP 27031。

最新备份 `artifacts/backups/20260912T061609Z-0c7aa6de` 在独立 PostgreSQL 中恢复，并使用上述新后端镜像执行 0004 幂等启动。55 个账户、109 场对局、163 条玩家结果的全字段指纹保持一致，约束和统计完整性检查通过。报告 `artifacts/candidate-037-startup-restore.json`。没有回灌或替换在线数据库；该演练未替换在线数据库；开发及发布环境后续切换另有记录。

### 0.37 开发环境切换与打包联网

`tools/deploy_candidate_dev.py --candidate-dir artifacts/candidates/0.37.0-dev-967bc7d9-0vrlx33n --with-api` 在房间无人、无有效预约、结果队列为空时备份开发数据库，保留旧 API/专服镜像 ID，然后停止专服并等待旧租约失效，使用已验证的固定镜像启动新 API 和专服。新 API 健康后才启动专服。切换前后 users、matches、results 全字段指纹一致，PostgreSQL/Redis 数据卷保留，API 与专服均为 `unless-stopped`。备份权限为 0600，保存在候选目录 `dev-backup/database.pgdump`；报告 `dev-deployment.json`。失败处理会尝试切回旧镜像，本次未执行故障回退或数据库回灌。

开发 API 8001 / 双人专服 UDP 27031 现为 0.37。启动现有固定镜像使用：

```sh
docker compose --env-file artifacts/duo-dev.env -f compose.duo-dev.yaml -f artifacts/duo-candidate.override.json up -d --no-build
```

两个候选客户端通过真实邀请大厅连续两轮登录、准备、入场与返回，使用同一队伍和新回合。证据 `artifacts/candidate-037-dev-requeue.log`。候选专服与一个已认证的候选客户端还验证机器人队友左右转向驾驶、乘客同步、制动与下车；客户端约 30 FPS，上下行各 30 ms 延迟，停车阶段每帧车体位移小于 0.03 m。日志 `artifacts/candidate-037-bot-turn-{right,left}.log`，完整日志和网络报告前缀 `artifacts/vehicle-login-duo-bot-driver-turn-{right,left}-fps30-delay30-packed-967bc7d9-`。

以上绑定候选归档 SHA-256，不等同于公网长期体验、自然完整对局或全部网络场景验收。后续发布切换见 [0.37 发行记录](RELEASE_037.md)。

### 0.37 正常时间对局与组队回归

同一候选 PCK 完成 solo/duo 两场自然对局，不覆盖胜负、不替换缩圈参数、不加速时间。每场一个自动操作的人类客户端和 15 个正常机器人，均达到 16 个角色、4 辆载具。solo 约 101.4 秒结束，客户端第 14 名；duo 约 117.85 秒结束，客户端所在队伍第 7 名。每场一个真实账户结果正确落库，分模式场次、击杀和胜场增量与结果一致。报告为候选目录 `natural-round-{solo,duo}/verification.json`，汇总日志 `artifacts/candidate-037-natural-{solo,duo}.log`。

两场 `bot_driving_frames` 均为零，不能据此证明机器人在自然对局中的用车时机、协作驾驶或驾驶稳定性。受控机器人驾驶检查与自然对局检查应分别理解。

四个候选客户端组成两个邀请队伍，通过倒地、两次救援中断、成功救援、队伍胜利、四条玩家战绩落库、结果队列序列化重载、分模式统计及结算返回原队伍；实际地图点击标点只对队友可见，合成编码语音在队内转发并解码。日志 `artifacts/candidate-037-party-combat.log`，详细日志前缀 `artifacts/candidate-967bc7d9-voice-relay-network-`。语音检查不替代物理麦克风和耳机试听。

三候选客户端在约 30 FPS、单向 50–100 ms 抖动、3% 丢包、三秒上行中断下通过载具观战、超时停车、网络恢复及下车。报告 `artifacts/vehicle-login-duo-impaired-spectator-fps30-packed-967bc7d9-verification.json`，同前缀 `network.json` 记录真实转发、丢包和中断计数。汇总日志 `artifacts/candidate-037-impaired-spectator.log`。该受控干扰不代表公网长期验收。

### 0.37 其余网络检查与发布

候选包通过行驶中账号撤销、驾驶客户端强制终止及三客户端移动交火。撤销/断线后制动、驾驶座释放、乘客安全下车均正常；30 FPS/单向 30 ms 的交火场景首发命中驾驶员，车体与乘客未承受同发伤害。日志 `artifacts/candidate-037-{revoke,drop,combat}.log`；同候选 SHA 的详细报告在对应 `vehicle-login-duo-*-packed-967bc7d9-verification.json`。

默认包、发布 API 和两台发布专服已切换至本候选；旧版包、镜像 ID、最新备份及切换数据指纹保留。发布端口验证和切换后恢复报告见 [发行记录](RELEASE_037.md)。完整商业级目标仍未完成。

## 0.36 候选（已作为开发版本发布）

- 版本：0.36.0-dev / 协议 17 / 资源 ash-valley-18。
- 源提交：`8245350d`。
- 目录：`artifacts/candidates/0.36.0-dev-8245350d-mdczhhx9/`。
- 压缩包：`IronMeridian-Linux-x86_64.tar.gz`，63,196,528 字节。
- SHA-256：`31357a83d0fcf6896cf8bc0c6acfa4b3c4c408528626f18f3afa4af169a54895`。
- 导入、导出及 42 项包内规则检查通过；压缩包解压到全新目录后的 `play.sh --headless -- --smoke` 默认入口检查通过。
- 实际 OpenGL 的人物动画、倒地动画、语音界面及载具观战检查通过；证据 `artifacts/candidate-036-render.log`，该目录的 `render-verification/` 保存报告与截图。
- 报告为该目录的 `verification.json`，逐项日志在 `logs/`；构建汇总为 `artifacts/candidate-036-build.log`。

此候选包含载具、空间音频、坐姿命中与回溯、观战跟车、机器人直线进圈驾驶及存档恢复处理。游戏包内包含更新后的 0.36 玩家指南。真人仍可在离线 SOLO/DUO 入口运行；在线需要兼容的 0.36 服务。当时发布服务和默认包切换至此 0.36 候选（现已升级 0.37），详见 [发行记录](RELEASE_036.md)。

候选 PCK 已通过以下受控联网联调及下述自然完整对局检查，发布切换及发布端口验证已完成。整体商业级游戏目标也仍未完成。

- 双客户端驾驶/乘坐与发动机音频同步。
- 30 FPS、单向 30 ms 延迟下三客户端移动射击：13.2 m/s 时首发命中驾驶员，乘客和车体未受伤。
- 30 FPS、50–100 ms 单向抖动、3% 丢包及三秒上行中断下的三客户端观战、停车恢复和下车。
- 真人乘坐系统分配的机器人队友驾驶车辆，30 FPS、单向 30 ms 延迟下到达并下车。
- 四客户端两支邀请队伍、救援中断与恢复、标点隔离、合成语音转发、结算后返回队伍，以及 PostgreSQL 四条战绩与分模式统计。

`tools/test_vehicle_login.py --candidate-dir <候选目录>` 在启动前及结束后核对压缩包和运行文件；专服与全部客户端使用候选 PCK。每项 `*-packed-8245350d-verification.json` 记录场景、候选校验和、测试夹具哈希和日志。汇总为候选目录的 `network-verification.json`；队伍联调为 `artifacts/candidate-036-party-combat.log`，原始日志前缀 `artifacts/candidate-8245350d-voice-relay-network-`。这些结果不代表公网长期稳定性或物理麦克风验收。

### 正常时间完整对局

`tools/test_candidate_full_round.py --candidate-dir <候选目录> --mode solo`（或 `duo`）以一名自动操作的真人客户端和 15 名正常机器人运行。服务端测试脚本只观察帧、对局与车辆数量，不改写缩圈、胜负、人物位置或 AI；时间倍率固定为 1。

solo 在游戏时间约 82.3 秒自然结算，真人排名 13；duo 约 99.5 秒结算，真人队伍排名 4。两场均确认 16 名参战者、四辆车、客户端结算、PostgreSQL 一条对应真人战绩，以及该模式场次/击杀/胜场统计变化。检查清理后的日志未发现脚本错误或对象泄漏。报告分别为候选目录的 `natural-round-solo/verification.json`、`natural-round-duo/verification.json`，汇总日志为 `artifacts/candidate-036-natural-{solo,duo}.log`。

这两场没有观察到机器人实际驾驶，因此不增加自然驾驶覆盖；机器人驾驶的证据仍为专项场景。两场短局也不代表五分钟时限结算、16 真人负载、反复重开或公网长期稳定性。

### 精确候选资源的专服镜像

`tools/build_candidate_image.py --candidate-dir <候选目录>` 使用 `infra/packaged-game.Dockerfile`，直接复制候选包的执行文件、PCK 和版本清单；构建后从镜像提取三份文件，与候选包逐字节校验，使用非 root 用户、无网络容器运行离线启动检查。不会启动或替换运行服务。

本候选镜像标签 `iron-meridian-candidate:8245350d2e2c`，已验证具体 ID：
`sha256:d7e86476802eb4299d989ae77854dd8fca85246d12b8f9a113abda8de8753e91`。
报告 `server-image.json`，构建和隔离启动日志在候选目录 `logs/server-image-{build,smoke}.log`。该镜像现已部署至独立开发专服及两台发布专服。

### 开发专服部署与重开

`tools/deploy_candidate_dev.py --candidate-dir <候选目录>` 要求开发 API 与候选兼容、房间无玩家及有效预约、结果重试队列为空。记录旧镜像后停止开发专服，等待旧房间租约过期，再用具体镜像 ID 启动；核对新房间实例、版本及 `unless-stopped` 重启策略。失败路径会尝试恢复旧镜像。数据库、缓存和 API 不参与此次重建。

开发房间 `room-27031` / UDP 27031 已切换成功；报告 `dev-deployment.json`，执行日志 `artifacts/candidate-036-dev-deployment.log`。保持候选镜像的启动配置保存在 `artifacts/duo-candidate.override.json`，使用：

```sh
docker compose --env-file artifacts/duo-dev.env -f compose.duo-dev.yaml -f artifacts/duo-candidate.override.json up -d --no-deps --no-build game
```

两个候选客户端通过邀请大厅连续两轮登录、准备、入场和返回，保留原队伍并使用新回合。证据 `artifacts/candidate-036-dev-requeue.log`，四份客户端日志为 `artifacts/candidate-8245350d-party-requeue-{0,1}-{0,1}.log`。开发 API 8001 返回 0.36 / 协议 17，发布 API 8000 也已升级至 0.36 / 协议 17，并通过发布端口连续两轮邀请入场检查。

候选 PCK 的驾驶者账号撤销及进程强制终止场景也通过，证据 `artifacts/vehicle-login-duo-{revoke,drop}-packed-8245350d-verification.json`。服务端确认输入清除或超时制动、驾驶位释放，乘客通过正常输入安全下车，完成时仍处于 live 阶段。

首次强制断线检查因对局提前结束超时，失败日志保留为 `artifacts/vehicle-login-duo-drop-packed-8245350d-*-early-finish.log`。夹具原先把静止机器人放在初始安全区外；现改为圈内位置，并要求下车检查在 live 阶段完成，防止回合清理产生假通过。最终复测中账号撤销/断线座位释放分别发生在约 5.48 / 12.87 秒。此修改只影响测试场景，不改写游戏缩圈或死亡规则。

### 后端镜像与恢复演练

0.36 后端镜像 `iron-meridian-api:0.36-8245350d` 的具体 ID 为
`sha256:0c04fb918b00618e7c87878d21f758eaf654ce734f72348fcbd2d1c6c5a4b5c8`。
后端源码及协议清单与候选源提交一致，镜像内清单也已核对。数据库仍使用 0004，没有新增迁移版本。

`tools/test_candidate_backend.py --candidate-dir <候选目录> --image <后端镜像>` 在独立内部 Docker 网络中启动临时 PostgreSQL、Redis 和实际 API，不映射宿主端口。95 项后端集成测试全部通过，没有跳过；包括会话、房间、队伍、战绩、迁移、恢复关系、隐私及依赖故障处理。报告 `backend-verification.json`，日志 `logs/backend-tests.log`。测试结束后移除临时容器、网络和数据。

发布库备份 `artifacts/backups/20260912T054031Z-f6132172` 在隔离容器恢复后，使用该后端镜像执行 0004 启动迁移：55 个账号、106 场对局、157 条战绩的全部已有字段和行数保持一致，队伍关系、外键与统计检查通过，两个结果队列均为空。报告 `artifacts/candidate-036-startup-restore.json`。旧 0003 备份升级回归也通过，保留 51 个账号、103 场对局和 151 条战绩的旧字段；报告 `artifacts/candidate-036-legacy-restore.json`。

以上为发布前隔离演练。实际切换已重新检查玩家、预约和结果队列，并创建新备份；已有数据全字段指纹保持一致。切换后的备份再次隔离恢复成功，证据见 [发行记录](RELEASE_036.md)。

## 2026-09-11 的 0.35 候选

- 版本：0.35.0-dev；协议 16；资源 ash-valley-17。
- 源提交：`9e73c12a`。
- 目录：`artifacts/candidates/0.35.0-dev-9e73c12a-veg5o95w/`。
- 压缩包：`IronMeridian-Linux-x86_64.tar.gz`，约 61 MiB。
- SHA-256：`2b4bc239ed615949237f8a4cba572315bc0cfde157d22a28993b4b71f95b0a27`。
- 导入、导出和 27 项包内检查通过。另将压缩包解压到临时目录，通过 `play.sh --headless -- --smoke` 验证默认入口、16 名参战者、换弹、治疗、伤害、胜负、射线、掩体、射速及角色骨架；日志为该目录的 `logs/archive-startup.log`。

解压后桌面运行 `./play.sh`。SOLO 与 DUO 离线入口不需要服务器；在线需要协议 16 的匹配服务。旧 0.34 服务使用协议 15，不兼容此候选包。候选包中附有新版玩家指南和功能文档。

0.34 发布包 SHA-256 仍为 `a8fde10e73b4306a7adb509578862935588f460b8e92b5ba2fa6df72197bd1e6`，已核对未变化。完整商业级游戏目标尚未完成。

## 包内联调与渲染验收

测试工具的 `--candidate-dir` 指向上述候选目录。运行前，`candidate_runtime.py` 检查压缩包 SHA-256，并逐一比较已解包的执行文件、PCK、启动脚本与构建清单是否和压缩包一致。网络脚本还检查候选清单与开发 API 版本一致，防止将源码运行结果误记为候选包验证。

```sh
.venv/bin/python tools/test_rescue_network.py --parties --team-pings --voice-relay --return-to-party --candidate-dir artifacts/candidates/0.35.0-dev-9e73c12a-veg5o95w
.venv/bin/python tools/test_party_lobby_network.py --requeue --candidate-dir artifacts/candidates/0.35.0-dev-9e73c12a-veg5o95w
.venv/bin/python tools/test_candidate_render.py --candidate-dir artifacts/candidates/0.35.0-dev-9e73c12a-veg5o95w
.venv/bin/python tools/test_voice_device.py --candidate-dir artifacts/candidates/0.35.0-dev-9e73c12a-veg5o95w
```

前两个脚本使用独立开发服务和复用测试账号，应顺序运行，避免同一账号的队伍与预约相互干扰。语音驱动脚本需要 [语音文档](VOICE.md) 中的隔离 PulseAudio 测试环境。

本候选已通过：

- 专服和四客户端均从候选 PCK 加载：两支邀请队伍交错入场，扶起/两次中断、共享标点、队友音频解码及实际混音、共享胜负、返回原队伍、PostgreSQL 四条战绩和分模式统计。`artifacts/candidate-network.log`，各客户端和服务日志以 `candidate-voice-relay-network-` 开头。
- 两个候选客户端连接已部署开发服务，通过正式邀请控件连续两轮登录、重置预约、准备及入场；原队伍保留，新回合不同。`artifacts/candidate-party-requeue.log`。
- 真实 OpenGL 渲染：原有九条角色动作和新增三条倒地动作、骨骼蒙皮边界、武器显示/隐藏、复活恢复及麦克风设置界面。`artifacts/candidate-render.log`；逐项日志和截图位于候选目录下 `render-verification/`。
- 候选 PCK 的真实 PulseAudio 驱动采集：440 Hz 虚拟源、监听不发包、模式切换、按键松开后再次发送及本机零回声输出。`artifacts/candidate-voice-driver.log`。它仍不代表物理音频设备验收。

验证报告的 `integration_verification` 记录这些证据；压缩包内容与校验和不变。当时发布服务切换为 0.35.0-dev / 协议 16 / 数据库 0004，默认包与此候选压缩包一致。0.34 归档于 `artifacts/releases/0.34/`；过程见 [运行服务升级](RELEASE_035.md)。

## 0.36 构建检查调整

随包玩家指南已更新载具操作与当前限制。`vehicle_spectator` 的驾驶步骤改在实际物理帧执行：此前在渲染回调之后手动模拟，Godot 无窗口运行时使用不同的运动时间步，导致速度达到 12 m/s 而位移仅约 3.77 m；修正后同一导出包位移约 9.10 m，完整测试通过。诊断日志 `artifacts/packed-vehicle-spectator-diagnostic.log`、修正后日志 `artifacts/packed-vehicle-spectator-fixed.log`。其余新增包内检查的预检日志以 `artifacts/packed-probe-` 开头；预检本身不将失败构建目录升级为通过的候选包，仍需从干净提交完整重建。

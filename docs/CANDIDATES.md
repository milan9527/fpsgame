# 独立 Linux 候选包

`tools/package_candidate.py` 要求干净且已提交的工作区，将当前 Godot 工程导出到独立的 `artifacts/candidates/<版本>-<提交>-<随机标识>/`，不会覆盖现有 `artifacts/IronMeridian-Linux-x86_64.tar.gz`。

运行：

```sh
.venv/bin/python tools/package_candidate.py
```

流程记录源提交、协议清单、每项检查及耗时。导入与导出成功后，使用复制的游戏执行文件和导出的 PCK 运行 42 项检查，覆盖清单一致性、双人分队/救援/观战/共享标点/邀请界面/本地战绩/检查点、单人保存兼容、按键、治疗、机器人投掷、背包、缩圈和语音组件，以及载具驾驶、坡面、座位、命中、音频、观战、存档、机器人驾驶和网络规则。检查必须出现对应成功标记，且不能包含脚本错误、断言失败或对象泄漏。玩家测试数据写入独立临时目录；不访问生产账号。所有检查完成后才生成压缩包，写入压缩包及 PCK 的 SHA-256。

构建失败会保留日志和失败状态，不将失败目录当作通过的候选包。成功报告中的 `scope` 仅说明包内离线规则验证，不代替网络、渲染或物理音频设备验收。后续发布仍需相应回归与服务版本切换。

## 0.36 候选（未发布）

- 版本：0.36.0-dev / 协议 17 / 资源 ash-valley-18。
- 源提交：`8245350d`。
- 目录：`artifacts/candidates/0.36.0-dev-8245350d-mdczhhx9/`。
- 压缩包：`IronMeridian-Linux-x86_64.tar.gz`，63,196,528 字节。
- SHA-256：`31357a83d0fcf6896cf8bc0c6acfa4b3c4c408528626f18f3afa4af169a54895`。
- 导入、导出及 42 项包内规则检查通过；压缩包解压到全新目录后的 `play.sh --headless -- --smoke` 默认入口检查通过。
- 实际 OpenGL 的人物动画、倒地动画、语音界面及载具观战检查通过；证据 `artifacts/candidate-036-render.log`，该目录的 `render-verification/` 保存报告与截图。
- 报告为该目录的 `verification.json`，逐项日志在 `logs/`；构建汇总为 `artifacts/candidate-036-build.log`。

此候选包含载具、空间音频、坐姿命中与回溯、观战跟车、机器人直线进圈驾驶及存档恢复处理。游戏包内包含更新后的 0.36 玩家指南。真人仍可在离线 SOLO/DUO 入口运行；在线需要兼容的 0.36 服务。当前发布服务和默认包仍保持 0.35，已核对默认压缩包校验和未变化。

候选 PCK 已通过以下受控联网联调及下述自然完整对局检查，后续发布切换尚未完成。整体商业级游戏目标也仍未完成。

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
报告 `server-image.json`，构建和隔离启动日志在候选目录 `logs/server-image-{build,smoke}.log`。发布时应使用具体镜像 ID 并另做服务与网络验收；目前尚未部署。

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

验证报告的 `integration_verification` 记录这些证据；压缩包内容与校验和不变。发布服务现已切换为 0.35.0-dev / 协议 16 / 数据库 0004，默认包与此候选压缩包一致。0.34 归档于 `artifacts/releases/0.34/`；过程见 [运行服务升级](RELEASE_035.md)。

## 0.36 构建检查调整

随包玩家指南已更新载具操作与当前限制。`vehicle_spectator` 的驾驶步骤改在实际物理帧执行：此前在渲染回调之后手动模拟，Godot 无窗口运行时使用不同的运动时间步，导致速度达到 12 m/s 而位移仅约 3.77 m；修正后同一导出包位移约 9.10 m，完整测试通过。诊断日志 `artifacts/packed-vehicle-spectator-diagnostic.log`、修正后日志 `artifacts/packed-vehicle-spectator-fixed.log`。其余新增包内检查的预检日志以 `artifacts/packed-probe-` 开头；预检本身不将失败构建目录升级为通过的候选包，仍需从干净提交完整重建。

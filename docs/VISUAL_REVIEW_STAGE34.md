# Stage34：第一人称手套连续形体与包内姿态审阅

本轮仅推进第一人称手部，整体写实目标仍未完成。stage32 的枪械、袖口与迷彩以及 stage33 的 SG/SR 改动保留，不计为本轮新工作。

## 改动与来源

`tools/build_viewmodel.py` 将原有方块掌体、直条手指和四块独立球状指节改为椭圆掌体、连续掌背皮革面、拇指根部和沿曲线逐渐收细的弯指；左右拇指方向镜像。重新生成 `art/first_person.blend` 与 `client/assets/first_person.glb`。保留原骨架、动作与材质参数，本轮没有新增皮肤权重、手指骨骼或材质贴图。

固定机位沿用 stage33：位置 `(17, 0.05, 50)`、yaw `atan2(-18,16)`、pitch `-0.03`。腰射与 ADS 使用各自实际 FOV。默认截图包含三武器的腰射、ADS、换弹 25%/50%/75%，游戏逻辑冻结；换弹采样不能证明连续动作全程没有穿插。

最终截图来源为 `artifacts/realism34-preview/capture/`。导出包从 `/tmp` 启动，隔离 XDG 用户数据、不传工作区 `--path`；外部 `tests/weapon_review_capture.gd` 通过包内 `res://` 加载游戏资源。对照图位于 `artifacts/realism34-comparison/`，上一阶段原图来自 stage33 导出包。

首次完整采集保存 13 张后退出 143，日志 `preview-capture.log` 没有说明原因，不能记为完整采集通过。截图工具新增 `--review-weapon=N`，第三把武器单独补采退出 0，`preview-capture-weapon2.log` 报告 `WEAPON_REVIEW_CAPTURE_PASS frames=5`。两次运行最终保留 15 张唯一姿态图；第三把前 3 张由补采覆盖。

## 验证与运行

本轮日志集中于 `artifacts/realism34-validation/`：

- `build-viewmodel.log`：Blender 生成通过，5 骨骼、Hold/Reload/Throw/Heal、1 蒙皮网格。
- `aim_alignment.log`：108 样本、三武器、ADS 过渡、后坐力、侧倾、射线通过。
- `weapon_visuals_rules.log`：本地/远端快照、挂点、瞄具对齐、缩放、骨骼挂接、网格范围通过。远端快照不等于真实联网测试。
- `weapon_obstruction_rules.log`：射击与弹药权威、旋转掩体、武器长度、蹲姿、重叠、低持枪、恢复通过。
- `preview-smoke.log`：独立导出包单机 16 角色、换弹、治疗、伤害、胜利、射线、掩体、射速、骨骼通过。

上述进程及资源导入、导出退出 0；`import.log` 仍有 dummy renderer 的 `Parameter "t" is null`，不能称无错误导入。实际截图使用 Godot 4.4.1 Forward+ / Vulkan llvmpipe 软件渲染，不能证明实体 GPU 性能。

本地运行 `./artifacts/realism34-preview/Linux/IronMeridian`，保持同目录 `.pck`。预览来自当前未提交工作区，没有发布或部署；摘要见该目录 `verification.json`。

## 实图自审与剩余问题

同机位卡宾枪原尺寸手部裁图显示，原先并排珠状指节改为连续的掌背轮廓；掌体和拇指更圆顺。不过手指仍像短套管，缺少真实关节、受力褶皱和贴合枪体的姿势。画面整体变化有限，不能把手部局部改进称为武器写实完成。

腰射和 ADS 对照保留原瞄具中心，手套没有新遮挡中心。袖口仍偏亮，枪尾直管、握把和大面积空白机匣仍突出；SR 镜筒仍缺少镜片与分划线。换弹手部接触需要专门修正，不能用本轮静态手型替代握持动画工作。

已实看三武器腰射/ADS 对照及 `reload-all-contact.png` 九姿态裁图：换弹中段左手伸到枪体下方，没有可见取弹/送弹接触；25% 与 75% 的接触姿势也过于相似。该问题在三把武器上都存在，后续需要动作与武器挂点协同调整。

本轮未修改第三人称人物或场景。stage31 独立审阅追加的 stage33 蹲姿挂接诊断应继续保留：挂点确实下移，应检查蒙皮与绑定，不应盲目调整枪挂点。重复草簇、裸土地面、相似建筑和单薄远树仍待改善。此前登录 HTTP 404 未解决，本轮未重跑 stage29、未宣称真实联网通过。

下一阶段优先修复三武器换弹取弹/送弹接触，并处理手指比例、袖口亮度与枪托形体；之后继续人物绑定、场景差异化与真实联网主流程。

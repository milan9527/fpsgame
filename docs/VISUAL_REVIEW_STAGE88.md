# Stage88：第一人称手套腕掌形体

本轮接续 stage87，落实 stage31 对第一人称手臂形体及同机位腰射/ADS 的优先要求。状态 **continue**：腕部收束有所改善，仍未解决左掌偏平、袖子偏厚及整个场景写实度问题。

## 修改与实机观察

`tools/build_viewmodel.py` 将掌部纵向截面从8段增加到14段，收窄腕部，增加掌背向指节展开的浅脊、三处宽指节起伏及局部腕部压褶。重建 `art/first_person.blend` 和 `client/assets/first_person.glb`，保留原指节接触路径及材质方案。本轮不是新材质制作；材质规则检查仅证明既有纹理、UV及非金属设置满足测试。

`artifacts/realism88-validation/wrist-before-after.jpg` 是 stage87/88 相同相机截图的未修饰裁切对比：腰射变化较小，半程换弹中右腕收束更明确；左手可见掌面仍像偏平的梯形片，袖筒仍宽厚。不能把网格细节增加等同于已经获得自然的人体形态。

三把武器的腰射与ADS使用相同角色位置 `(17, .05, 50)`、偏航 `atan2(-18,16)`、俯仰 `-.03`。每把另外捕获换弹四分之一、半程、四分之三三个姿态。源码和预览包各15张1280×800截图，使用实际 Godot Forward+ / llvmpipe 软件 Vulkan。截图用于静态形体审阅，不证明硬件帧率或全部运动连续性。

源码画面中未见此次修改新增的明显手掌断裂；ADS中心仍对齐。狙击镜外圈仍能看出多边形轮廓，镜片偏雾；建筑表面平、草簇重复、空间层次不足。上述缺陷仍需后续处理。

预览包的三武器腰射/ADS对照及九个换弹姿态也已审阅：同样存在平板掌面、宽厚袖筒和霰弹枪方厚机匣，没有观察到新增的明显手掌分离。源码与包内两个截图进程均退出0并报告 `WEAPON_REVIEW_CAPTURE_PASS frames=15`。

## 验证与证据

构建、资源导入、PCK导出均退出0。导入日志仍有已有 dummy renderer `Parameter "t" is null.` 错误，不能称为零错误导入。

| 检查 | 源码 / 预览包 | 实际范围 |
| --- | --- | --- |
| glove_surface_rules | PASS / PASS | 90429个UV三角形；法线贴图、非金属材质 |
| aim_alignment | PASS / PASS | 每次108样本、三武器、过渡、后坐、侧倾、射线 |
| reload_contact_rules | PASS / PASS | 每次183接触样本、三武器及握持复位 |
| weapon_obstruction_rules | PASS / PASS | 近墙、旋转、蹲伏、重叠、低持枪、弹药与HUD |
| viewmodel_rules | PASS / PASS | 骨架、瞄具、换弹、投掷、治疗、死亡复位 |
| weapon_visuals_rules | PASS / PASS | 本地与远端快照、附件锚点、骨骼绑定 |
| offline_smoke | PASS / PASS | 16角色、射击、换弹、治疗、伤害、胜利、掩体 |

14个测试子进程及验证主进程退出0。远端快照测试不等于真实联网会话，本轮没有验证实际ENet多人连接；近墙遮挡检查也不代表全地图碰撞验收。

证据目录：`artifacts/realism88-validation/`。

- `test-results.json`、`test-runner.log` 和各测试日志记录实际结果。
- `source-forward/`、`packaged-forward/` 保存全部原始截图；对应 capture 日志记录截图脚本结果。
- `source-aim-pairs.jpg`、`packaged-aim-pairs.jpg`：三武器腰射/ADS对照。
- `source-reload.jpg`、`packaged-reload.jpg`：三武器三个换弹姿态。
- `capture-index.json` 记录截图尺寸、SHA256及源码/包内像素差；像素差不作为完全一致断言。
- `verification.json` 汇总结果和未完成事项；`build.log`、`import.log`、`export.log` 保留构建记录。

## 本地预览与下一步

项目根目录、有图形桌面的终端运行：

```bash
"$PWD/artifacts/realism88-preview/Linux/IronMeridian" --path /tmp
```

保留同目录的 `IronMeridian.pck`。这是 Godot 4.4.1 可执行文件与导出PCK的本地组合，非标准release模板发行包。`artifacts/realism88-preview/README.md` 与 `build.json` 记录启动方法和产物哈希。未发布、未push。

下一阶段应优先重塑左支撑手的掌心弧度、虎口体积和手指分组轮廓，让腰射及换弹中可见的平板掌面发生明确改善，再检查袖口厚度和材质纹理尺度。之后继续建筑入口、道路植被、人物与光照的多机位审阅，并补实际多人及更广地图碰撞验证。不要继续用仅增加浅表细节替代主要形体问题。

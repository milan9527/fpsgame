# Stage70：卡宾枪瞄具形体与材质

2026-09-13，状态 continue。按 stage31 与最新 stage69 的反馈，本轮重建第一人称卡宾枪瞄具；手臂沿用 stage69，整体画质目标尚未完成。

## 实际修改

- `tools/build_assets.py`：原八边形粗框改为圆角薄壁外壳，增加独立后缘与内侧垫圈；原实心高底座改为双支柱镂空支架，补夹爪、固定螺栓和发射器座。
- 调节旋钮采用不对称电池盖/风偏盖、分层密封环、凹槽与边缘防滑纹，区分阳极金属、缎面边缘和橡胶材质。
- 仅重建 `art/carbine.blend`、`client/assets/carbine.glb`。保留瞄准中心、挂点和运行时武器逻辑。

## 实机截图审阅

使用本轮导出的 PCK，在 `/tmp` 启动预览引擎运行 `tests/weapon_review_capture.gd -- --review-weapon=0`。Forward+ / Vulkan / llvmpipe 软件渲染，1280×800，五张腰射、ADS 和换弹姿态图，退出0且 `WEAPON_REVIEW_CAPTURE_PASS frames=5`。

- `artifacts/realism70-validation/carbine-before-after.png`：stage69/70 同脚本固定相机腰射与 ADS 对照。腰射中薄框轮廓可辨；ADS 中圆角外壳替代明显切角，镂空座消除了大块实心板，中央红点仍居中，视野无遮挡。
- `artifacts/realism70-validation/optic-before-after-detail.png`：上述原图裁切放大，非另一个渲染。可见双柱间真实开口、分层旋钮和边缘材质差异；支柱高光仍偏亮，底座仍偏高。
- 已查看腰射/ADS 原图、对照图与 `packaged-forward/weapon-0-reload-half.png`。换弹中瞄具连接连续，但枪托厚重、机匣大平面、手臂管状轮廓仍明显，不能称为整体写实达标。另两个换弹采样保留供复核。

截图为真实游戏渲染的固定姿态采样，不代表连续人工操作或完整地图碰撞验收。场景仍有重复仓库、扇片草和空旷泥地，本轮没有改变这些问题。

## 验证与预览

`artifacts/realism70-validation/stage-results.json` 汇总六项包内验证，均退出0且无运行错误：

- aim_alignment：108样本，三武器，切换、后坐力、侧倾、射线。
- reload_contact_rules：183接触样本，三武器。
- weapon_obstruction_rules：贴墙、弹药、旋转、蹲伏、重叠、低持枪、恢复等规则。
- viewmodel_rules：骨骼、瞄具对齐、换弹、投掷、治疗、死亡重置。
- weapon_visuals_rules：本地与远端快照模型、挂点、包围盒；远端快照测试不是真实联网。
- offline：16演员，换弹、治疗、伤害、胜利、射线、掩体、射速。

Blender、导入、导出、截图日志均保留。导入退出0但仍记录一次 `ERROR: Parameter "t" is null.`，未解决；导出与截图日志无该错误。未重跑材质UV专项规则，不沿用上一轮结果冒充新测试。

本地启动：`./artifacts/realism70-preview/Linux/IronMeridian --path /tmp`。目录内含 PCK、README、build.json 哈希和 verification.json。没有发布、修改后台服务或清理既有修改。本轮没有真实联网、实体GPU或完整人工移动验证；未复测此前 API 问题。

## 下一步

实质重塑卡宾枪机匣/枪托与手臂握持关系，避免继续仅微调瞄具；随后改变仓库体量与用途、道路泥草边界，并补连续移动碰撞、人物光照和真实双客户端验证。

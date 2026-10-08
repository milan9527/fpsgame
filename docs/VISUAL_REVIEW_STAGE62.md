# Stage62 第一人称大形体与材料分区

本轮依据 stage29、30、31 独立反馈，在 stage61 文件基础上改进正常视角可见的武器与袖管，没有重复 stage29 验证。整体目标仍为 **continue**。

## 实际修改

- `tools/build_assets.py`：卡宾枪机匣肩部材质区与四个浅槽；收窄、降低托腮轮廓，加入橄榄色尼龙外壳与带横向浅槽的黑色橡胶接触面。合并到现有枪托网格，保持武器网格结构。
- `tools/build_viewmodel.py`：减小肘腕膨胀、袖管截面厚度和两处褶皱起伏，保留现有骨骼、握持锚点与动作。
- 重建卡宾枪、共享第一人称手臂的 Blender 和 GLB 资源。

## 同机位画面审阅

证据目录：`artifacts/realism62-validation/forward/`。使用既有固定机位脚本，三武器分别检查腰射、ADS、三个换弹阶段。`carbine-before-after.png` 对照 stage61/62 的 Forward+ 腰射和 ADS；ADS 自身有正常瞄准变焦，各阶段相同姿态间比较。

卡宾枪腰射可辨认枪托的两种材料，ADS 下托腮从连续鼓起的表面变成较薄、具有接触垫边界的轮廓。袖管收薄有一定效果，但改动不足以消除僵硬握持感。机匣浅槽在正常视角很小，大片平直侧面仍明显，不能把槽细节计作整体画质达标。换弹手部仍需继续改善自然弯曲和袖口交叠。

场景仍有重复的低矮仓库、均匀草丛、平滑山坡和不足的地表层次。这些正常画面占比更大的问题应成为下一阶段重点；人物及整体光照也尚未完成验收。

截图采用 Xvfb + Forward+ llvmpipe 软件 Vulkan，不代表实体 GPU 性能。最初 Compatibility 两张截图保留在 `after/`，其中草丛发黑；它们不用于与 stage61 Forward+ 比较，该兼容性问题未修复。

## 验证与预览

`artifacts/realism62-validation/tests.json` 七项回归全部通过：108 个瞄准样本、183 个换弹接触样本、抵墙收枪、视图模型、手套表面、武器显示与入口碰撞（32 个雨棚、96 次底部射线）。远端 snapshot 规则通过不等于真实联网验证。

`packaged-smoke.log`：独立导出包在 `/tmp`、独立用户目录中通过 16 演员单机烟测，覆盖换弹、治疗、伤害、胜利、射线、掩体、射击间隔和骨架。没有宣称完整人工移动巡检。

`import.log` 仍出现两条 `Parameter "t" is null` 错误；导入后回归与包烟测可运行，但导入不能称为无错误。`network-probe.json` 记录默认 `127.0.0.1:8000` 的 health/protocol/openapi 三项均404；真实双客户端验证受阻，未修改服务。

本地启动：`./artifacts/realism62-preview/Linux/IronMeridian --path /tmp`。目录附 README、许可证、build.json 哈希和 verification.json。使用 Godot 编辑器可执行文件配套导出 PCK，未对外发布。

下一步优先改善仓库用途与体量差异、建筑周边泥草边界，复核固定机位和移动碰撞；继续机匣大面、自然握持、人物和光照，并解决导入/兼容渲染问题及补真实联网验证。

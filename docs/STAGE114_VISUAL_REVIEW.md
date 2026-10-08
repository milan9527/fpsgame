# Stage114 环境局部改进与独立包验证

2026-09-14。总体目标未完成，状态 continue。本轮没有解决建筑群重复或空旷地形，不应将棚体细节和降低补光等同于环境整体完成。

## 改动与实图判断

- 装卸棚增加屋面接缝、边缘排水槽/立管和 LOADING / 04 标识。正常 approach/canopy 机位可辨认，仍需更丰富的建筑体量与院落用途差异；标识底板仍偏平整。
- 路肩植被按噪声形成不连续群落；阔叶缩小、降低高度与黄绿色偏色。宽幅对照能看到叶片尺度改善，但道路交叉口仍大面积空白，重复仓库和山坡折面依然突出。
- Forward+ 天空环境补光从 0.72 调至 0.52，日光能量及方向不变。遮蔽面稍暗，入口内部仍可读；这不是材质失真已修复的证据。地板依然光滑，细节不足。
- 近树仍有棱角树根、稀疏规则枝层及裸地过渡问题，本轮未修复。

修改位于 `client/scripts/world_visuals.gd` 和 `client/shaders/grass.gdshader`；保留所有原有未提交工作。

## 同机位证据

`artifacts/realism114-validation/before-forward/` 直接复用已归档的 stage113 packaged-forward 原图，不是本轮重新运行旧包。当前包原图在 `packaged-forward/`。双方七个相机记录完全一致，检查记录在 `camera-comparison.json`。

|画面|角色位置 xyz|朝向目标 xyz|yaw / pitch 弧度|
|---|---|---|---|
|depot-approach|17, .05, 46|31, 2.2, 34|-.862170 / .029819|
|depot-canopy|23.5, .05, 42|25, 2, 31|-.135528 / .031516|
|depot-entrance-close|35, .05, 44|35, 1.9, 34|0 / .024995|
|terrain-wide|17, .05, 50|-46, 12, -90|.422854 / .067315|
|depot-interior-fixture|35, .05, 38|35, 3.85, 34|0 / .502843|
|depot-interior-floor|35, .05, 38|35, .3, 32|0 / -.221314|
|forest-eye-level|-111.187126, .05, -72.475166|-111.187126, 4, -82.475166|0 / .230812|

相机眼高偏移 1.6，视口 1280×800，精确值见双方 environment-camera-poses.json。对照：`environment-before-after.jpg`、`entrance-before-after.jpg`、`forest-before-after.jpg`。图像数量不是质量验收标准。

## 功能范围和限制

源码、独立包各十项检查全部通过：瞄准、武器遮挡、单机烟测、入口碰撞、屋顶碰撞、棚下净空、掩体、本地网络状态规则，以及仓库和棚下双向物理行走。详见 functional-results.json 及逐项日志。

独立包仓库角色 x=35，z=44 → 24.97425，反向 z=24 → 43.02611；棚下 x=23.5，z=44 → 18.42486，反向 z=18 → 43.57514。均为物理帧移动，非截图摆位或传送穿门。原始结果在 packaged-forward/traversal.json 和 depot-traversal.json。

现有真实联网测试 runner 需要读取服务密钥并使用认证 fixture；根据本任务禁止读取密钥的约束，本轮没有执行。没有将本地状态规则结果计作真实联网通过。第三人称未重新截图，既有块状护具、靴子及蹲姿问题保留。软件 Vulkan llvmpipe 截图不能验证硬件帧率。

## 下一阶段

优先增加正常宽幅视角可辨认的仓库群体量/院落差异与地面过渡，再处理树根泥土和针叶过渡，避免再次整轮只修单个棚子。保留第三人称人物、第一人称细长手臂/袖口、连续换弹及真实联网验收任务。

本地包：`artifacts/realism114-preview/Linux/IronMeridian`，同目录 PCK；启动方式见预览 README.md。未对外发布。

三枪腰射、ADS 和三个换弹静态时刻均已采集并审阅（`packaged-weapons-contact.jpg`）。准具可见；手臂仍显细长，换弹时枪身遮挡手部，SG8 动作与握持尚需连续实机审阅，未据此判定人物/手部完成。两个捕获脚本通过，见 capture-results.json。预览二进制/PCK 与改动源码 SHA-256 保存于预览 build.json，汇总为 artifacts/realism114-validation/verification.json。

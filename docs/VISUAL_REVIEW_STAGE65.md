# Stage65 — 镂空枪托、袖肘形体与包内实机验证

依据最新 stage64 文件继续工作，并落实 stage31 对第一人称形体和同机位腰射/ADS 的优先要求。未重复 stage29 验证，未推送或发布，保留已有未提交修改。

## 实际改动

- `tools/build_assets.py`：卡宾枪原实心圆厚枪托改为侧轮廓建模、布尔贯通镂空的伸缩枪托，形成上部套管、斜撑与后部支撑；收窄托腮。重建 carbine Blender/GLB，保持原武器锚点与四网格约定。
- `tools/build_viewmodel.py`：减小共享袖管基础半径和肘部鼓包，重塑压缩褶皱为较窄凹槽和较宽隆起，保持动作接触点与已有布料材质。重建 view_arms Blender/GLB。

## 实机审阅

截图直接运行本轮独立包，`--path /tmp`，使用仓库外置 `tests/weapon_review_capture.gd` 驱动包内游戏资源；隔离用户数据。相机位置 `(17, .05, 50)`、俯仰 `-.03` 与 stage64 一致，ADS 保留正常视场变化。

- 原图：`artifacts/realism65-validation/packaged-forward/`，三武器各腰射、ADS、换弹三个时刻，共15张1280×800截图。
- 同机位对照：`artifacts/realism65-validation/carbine-before-after.png`。
- 全部姿态总览：`artifacts/realism65-validation/all-poses-review.png`。
- 已自审总览、卡宾枪原尺寸ADS及换弹中段。枪托不再完全实心，腰射边缘可见空腔，但主要结构接近画面边界，实际观感改善有限；ADS托腮仍占据下方较大面积。袖肘换弹时的折叠更明显，长段前臂仍偏平滑、像软塑料。未发现总览级别的新脱手或瞄具遮挡；不等同逐像素排除穿插。
- 接收机宽大暗面、握持僵硬、重复仓库与植被、空旷泥草地仍明显，不能判定整体写实目标完成。

## 验证与限制

证据目录 `artifacts/realism65-validation/`：

- `build-carbine.log`、`build-arms.log`：Blender生成退出0；`import.log` 退出0但仍有两次空纹理错误，未视为干净导入。
- `tests.json`及六项独立日志：瞄准108样本、换弹183接触样本、抵墙、viewmodel、手套袖管材质、三武器视觉规则全部PASS并退出0。远端快照规则不等于真实联网。
- `packaged-capture.log`：Forward+ llvmpipe 软件Vulkan，15帧PASS且退出0。本轮补齐实际包内图形验证，不代表实体GPU性能。
- `packaged-smoke.log`：16演员，换弹、治疗、伤害、胜利、射线、掩体、射速及骨架PASS，退出0。
- `network-probe.json`：默认 localhost:8000 的 health/protocol/openapi.json 均404；真实双客户端联网未验证，未修改现有服务。
- 未做完整人工移动探索、实体GPU测试及Compatibility黑草复测。人物、建筑和地形本轮未改进。

## 当前预览与下一步

仓库根目录启动：`./artifacts/realism65-preview/Linux/IronMeridian --path /tmp`。

目录内README、许可证、build.json哈希、verification.json可核查。使用Godot编辑器二进制和PCK，并非专用release模板。构建包含当前工作区已有未提交改动。

状态 **continue**。下一阶段应实质改变仓库体量和用途、补足空旷地面边界与障碍物，验证新增移动碰撞并提供包内同机位前后对照；继续解决机匣大平面、袖管塑料感及自然握持，追踪空纹理错误和真实联网验证缺口。

# Stage46 第一人称袖子形体与布料审阅

2026-09-13。整体目标未完成，状态 continue。

本轮在 `tools/build_viewmodel.py` 重做袖子：圆柱截面改为随前臂变化的椭圆截面，增加局部斜向压褶与袖口收束，替换规则周向波纹，加入打包的 ripstop 织物法线。重建 `art/first_person.blend` 与 `client/assets/first_person.glb`。枪体沿用 stage45，手指及握持锚点未改。

## 实际截图审阅

使用最终 Linux 引擎+PCK，在独立工作目录、全新用户数据下运行 `tests/weapon_review_capture.gd`。固定位置 (17,0.05,50)、yaw=atan2(-18,16)、pitch=-0.03；与 stage45 一致。三把武器各腰射、ADS、换弹25%/50%/75%，共15张1280×800截图。ADS保留武器自身变焦，因此同一世界位置和朝向不意味着腰射与ADS相同视场。

- 原图：`artifacts/realism46-preview/capture/`；总览：`artifacts/realism46-validation/hip-ads-sheet.png`、`reload-sheet.png`（后者裁去顶部160像素）。15张姿态均通过总览审阅。
- `carbine-hip-comparison.png`、`carbine-ads-comparison.png` 为 stage45/46 同相机下半屏对照。袖子轮廓更窄且有截面变化，腕部局部褶皱取代部分圆管感；正常视距改善仍有限，迷彩色块较大，袖口边缘仍偏硬。
- 三把武器腰射与ADS未见袖子新增遮挡瞄准中心。SR镜内视野保留。枪身平面、SG枪托材质、支撑手的简化轮廓仍明显。
- 九张换弹定点图未见明显袖子断裂或新增大面积穿插；中段离手姿态保留。掌心接触测试不能证明逐指贴合，SR逐指接触及连续换弹动画仍待检查。
- 画面背景依然有重复仓房、平坦空旷地面、草簇重复与路面边缘生硬的问题。本轮没有改善人物、建筑、地形或光照，不作整体验收。

## 验证与可运行预览

`artifacts/realism46-validation/test-results.json`：七项规则与单机烟测全部退出0，无测试错误。含瞄准108样本、掌心接触183样本、手套UV有效三角形27072、武器贴墙遮挡、换弹/治疗/投掷/死亡复位、16个单机角色及射击伤害等。remote_snapshot为规则测试，不能代表真实联网。

`capture.log`：退出0，`WEAPON_REVIEW_CAPTURE_PASS frames=15`。截图使用 Forward+ / llvmpipe 软件 Vulkan，不代表实体GPU帧率。导入与导出退出0；`import.log` 仍有既有 dummy renderer `Parameter "t" is null`，未将导入声明为无错误。

本地启动 `artifacts/realism46-preview/Linux/IronMeridian`，需保留相邻 `IronMeridian.pck`。这是 Godot 4.4.1 引擎+PCK开发预览，非标准导出模板发布包；同目录 build.json 提供源码/资产及包哈希，verification.json记录验证范围。

真实联网此前HTTP404仍未解决，本轮未重测多人端到端、全图移动碰撞或连续动画。下一阶段应集中改善建筑入口/窗框纵深与院落道路-草地过渡，用移动近景截图验证场景变化，继续人物/光照、SR逐指握持及真实联网诊断。保留未提交修改，无推送或发布。

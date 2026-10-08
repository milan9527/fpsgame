# Stage48 — SR-5 主要形体与通风护木

本轮以stage47为基线，响应stage31第一人称优先反馈；整体状态continue。

## 改动

`tools/build_weapon_variants.py` 将SR平板机匣替换为渐变圆弧截面，方握把替换为掌心鼓起的曲面；圆筒护木替换为渐缩复合材质壳体，贯通内部空腔及五组横向通风槽，取消贴片假开孔。复合材质改为深灰绿。单独重建 `art/marksman.blend` 和 `client/assets/marksman.glb`。手臂沿用stage46，握持锚点与瞄具位置未改。

## 实机审阅

从最终包启动，沿用同一 `tests/weapon_review_capture.gd` 相机与姿态，Forward+软件Vulkan输出五张1280×800原图：`artifacts/realism48-preview/capture/weapon-2-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`。

已查看腰射、ADS原图，以及 `artifacts/realism48-validation/sr-hip-ads-before-after.png` 和 `sr-reload-overview.png`。腰射机匣原有亮平板变为连续圆弧高光，护木侧面开口可见，但被手部遮挡，正常视距下开孔改善有限。ADS准星中心未新增遮挡；镜筒与调节钮仍粗简。三个换弹采样没有明显手臂脱离，不能代替连续动画和逐指穿插检查。武器表面仍偏光滑，袖子迷彩仍程序化；远处建筑重复、地表与植被过渡生硬，未达到整体目标。

## 验证与预览

最终包从隔离工作目录执行：aim_alignment、reload_contact_rules、viewmodel_rules、weapon_finish_rules、weapon_obstruction_rules、weapon_visuals_rules、glove_surface_rules和smoke全部退出0并输出PASS，详见 `artifacts/realism48-validation/test-results.json` 及同目录日志。覆盖瞄准108样本、掌心接触183样本、贴墙射击阻挡和16角色单机流程。remote_snapshot规则通过不等于真实联网通过。

构建、导出与截图退出0；截图日志 `artifacts/realism48-validation/capture.log` 确认frames=5。无头导入仍有既有空纹理错误，实际Vulkan渲染成功。软件渲染不代表实体GPU性能。本轮未重新验证真实多人端到端（此前HTTP404仍未解决）、全图行走碰撞或连续动画。

本地运行 `artifacts/realism48-preview/Linux/IronMeridian`，保留相邻PCK；README.txt、build.json、verification.json记录使用说明、已复核SHA256和测试范围。保留所有未提交修改，未推送或发布。

## 下一步

集中改善建筑入口和窗框纵深、院落道路与草地过渡，保存近景移动截图并验证主要通道碰撞；随后继续人物、手指接触、光照和真实联网诊断，避免将单枪改善视为整体完成。

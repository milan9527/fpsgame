# Stage47 — SG-8 机匣、护木与握把形体（2026-09-13）

本轮按 stage31 第一人称优先反馈继续改善 SG-8。整体目标仍未完成，状态 **continue**。

## 实际改动

- 机匣由侧面挤出形体改为渐缩、圆弧冠部截面，减少后端亮灰平板观感；握把改为带掌心鼓起的变化截面。
- 圆柱护木和突出环箍改为椭圆渐缩护木、六条浅防滑带。复合材质从棕色改为低饱和深灰绿。
- 单独重建 `art/shotgun.blend` 与 `client/assets/shotgun.glb`；生成器支持 shotgun/marksman 单项导出，避免覆盖其他武器修改。本轮未重建 AR/SR，沿用 stage46 手臂与现有握持、瞄准锚点。

## 实机审阅

从最终 `artifacts/realism47-preview/Linux/IronMeridian` + 相邻 PCK 启动，在临时工作目录和独立用户数据目录运行截图脚本。Godot 4.4.1，Forward+ Vulkan，llvmpipe 软件渲染，1280×800。固定角色位置 `(17, .05, 50)`、偏航 `atan2(-18,16)`、俯仰 `-.03`，同机位比较腰射与 ADS（保留各武器正常 ADS 视场变化）。

- 原图：`artifacts/realism47-preview/capture/`，三把武器各腰射、ADS、换弹 1/4、1/2、3/4，共15张。
- 同机位前后对照：`artifacts/realism47-validation/sg-hip-ads-before-after.png`（stage46 / stage47）。
- 已查看全部帧总览：`hip-ads-sheet.png`、`reload-sheet.png`（同 validation 目录）；另查看 SG 换弹中点原尺寸图。
- SG 腰射和 ADS 的机匣后肩出现连续圆弧高光，原来的宽平板观感减轻；深灰绿枪托、握把与手套更协调。照门/准星中心仍开放，未观察到新增中心遮挡。
- 护木大部分被支撑手遮挡，不能仅凭这些图宣称每根手指接触都正确。换弹中点可见右手保持握把附近、左手随弹匣下移；静态样本不能证明整段动画无穿插。三枪仍使用较通用的换弹表现，SG 枪型与供弹细节需继续核对。
- 局限：SG 枪托仍有大块干净表面，枪管细节简化；袖子迷彩、手指形体仍不够自然。仓库立面重复、草丛分布规律、地面空旷平整、远树剪影与光照层次不足。这是武器局部改善，不是整体写实目标验收。

## 验证和预览

`artifacts/realism47-validation/test-results.json`：七项规则测试和单机烟测均退出0并输出 PASS；瞄准108样本、换弹接触183样本、三枪材质/骨骼/锚点、手套表面、贴墙低姿态与射击遮挡、16 actor 单机伤害/治疗/换弹/胜利等通过。测试基于最终包，详细日志位于同目录。

`capture.log` 输出 `WEAPON_REVIEW_CAPTURE_PASS frames=15`，进程退出0。Blender 构建、PCK 导出退出0。无头导入退出0，但 `import.log` 仍保留既有 dummy `texture_2d_get` 空纹理错误；实际 Vulkan 截图流程成功。`diff-check.log` 通过，build.json 记录的文件哈希已复核。

本地启动：`artifacts/realism47-preview/Linux/IronMeridian`（保持相邻 `IronMeridian.pck`）。README、build.json、verification.json 记录启动方式、哈希和验证范围。软件渲染不代表实体 GPU 性能。

本轮未验证真实多人端到端；此前 HTTP404 问题仍未解决，remote_snapshot 规则通过不等同联网通过。未做全图碰撞巡检或连续动画验收。未推送、发布或部署。

下一轮应集中改善建筑入口/窗框纵深与院落路面—草地过渡，拍摄移动近景并验证主要通道碰撞；继续跟进人物、手指接触、光照与真实联网阻塞。

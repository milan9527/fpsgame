# Stage71 — 卡宾枪枪托轮廓与聚合物表面

2026-09-13。状态：continue；仅完成枪托专项，整体写实目标未完成。

本轮修改 `tools/build_assets.py`，重建 `art/carbine.blend`、`client/assets/carbine.glb` 及相关材质纹理。贴腮支承收窄、降低并沿长度渐变，橡胶垫缩短，移除顶部五道深横槽；增加侧面调节拨片、转轴和背带孔。尼龙与橡胶使用不同颜色颗粒和粗糙度。瞄准挂点、握持位置未改，手臂沿用已有版本。

## 实际截图审阅

截图由本轮 Linux 预览包运行生成，Forward+ / Vulkan llvmpipe 软件渲染，1280×800。沿用 stage70 相机：位置 `(17, 0.05, 50)`、yaw `atan2(-18,16)`、pitch `-0.03`；每个姿态等待90次渲染帧。腰射与 ADS 使用相同站位/朝向，ADS 保留游戏自身变焦。

- 对照：`artifacts/realism71-validation/carbine-before-after.png`，上轮与本轮腰射/ADS。
- 五姿态：`artifacts/realism71-validation/all-poses-review.png`。
- 原图：`artifacts/realism71-validation/packaged-forward/weapon-0-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`。

已查看对照、五姿态总览、ADS 和换弹中段原图。ADS 下宽大的条纹盖板变为较窄的渐变橡胶垫；腰射变化较小，换弹可见枪托支撑结构。瞄具中心未见偏移，抽查姿态未见新增明显穿插；不能据此保证整段动画无穿插。细颗粒表面只能轻微改善材质区分，未改变机匣大平面方正的观感。袖管仍偏粗软，手套握持细节不足；仓库重复、草簇分布和地面边界仍影响写实度。

## 验证与预览

源项目和导出包分别通过六项测试：108个瞄准样本、183个换弹接触样本、抵墙遮挡规则、第一人称骨骼/操作规则、武器显示/远端快照规则、16演员单机烟测。导出与五帧截图进程均退出0，包内测试和截图日志没有 ERROR。汇总及原始日志位于 `artifacts/realism71-validation/stage-results.json`、`packaged-tests.json` 和同目录 `*.log`。

导入日志仍有 `Parameter "t" is null`（dummy texture storage）；保留于 `import.log`，尚未解决。当前截图未见明显缺失纹理，不代表导入错误已修复。未做本轮材质UV专项、真实双客户端联网、实体GPU或完整人工移动穿越测试；远端快照规则不能替代联网测试。

本地运行：`./artifacts/realism71-preview/Linux/IronMeridian --path /tmp`。包内附 README、build.json 哈希和 verification.json；这是未提交工作区导出的本地预览，未发布。

下一阶段应集中重塑机匣与握持连接、缩减袖管体积并复核同机位腰射/ADS，避免继续仅增加枪托小零件。随后推进建筑用途/体量、道路泥草过渡和人物光照，补连续移动碰撞及真实双客户端验证。

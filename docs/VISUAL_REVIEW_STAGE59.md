# Stage59：卡宾枪瞄具、枪托与材质

2026-09-13；本轮自审，非独立审阅。整体目标仍未完成。

## 改动与实际画面

- `tools/build_assets.py` 重建 carbine.blend / carbine.glb：瞄具深度40→30mm，内外半径比0.82→0.90；枪托增加有肩线的贴腮面及侧接缝，保留现有瞄准/枪口锚点。
- 机匣、边缘与聚合物增加512²颜色及粗糙度贴图，使用固定种子和按实际尺度投影的UV，随GLB导出。运行时保留贴图UV和粗糙度，避免旧颜色再次乘暗；缓存按源材质实例隔离。
- 实际审阅最终完整腰射、ADS及三个换弹时刻。相同位置、朝向和姿态设置对比Stage58，ADS框壁明显变细，开口更清晰；腰射枪托不再完全光滑，机匣有轻微表面变化，但仍有宽平面，不能称为写实武器完成。
- 手臂本轮未重塑；换弹截图未见新的明显脱离，手指和腕部依然机械。新增纹理远看收益有限，不能用贴图存在替代画质评价。

## 可复核证据

- 最终五张：`artifacts/realism59-validation/final-carbine/weapon-0-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`。
- 同机位前后对比：`artifacts/realism59-validation/comparison-hip.jpg`、`comparison-ads.jpg`；换弹接触：`reload-contact.jpg`。对比上排全图缩小，下排局部放大。
- `after/` 是初次三武器15张诊断截图，卡宾枪曾被运行时旧颜色乘暗，不作为最终卡宾枪验收图。修正后单独重拍五张，`capture-final-carbine.log` 正常退出并报告PASS。
- Forward+、Vulkan llvmpipe软件渲染；截图不是实体GPU性能测试。
- `tests.json`：8项回归全部退出0，含108瞄准样本、183换弹接触样本、抵墙、视图模型、材质、预测和可靠动作规则。预测及远端快照规则属于离线检查，不能代替真实双客户端。
- `packaged-smoke.log`：独立导出包实际启动，16演员单机的换弹、治疗、伤害、胜利、射线、掩体、射击间隔、骨架检查PASS。导入日志仍有dummy renderer空纹理错误，未隐瞒为全无错误；导出退出0。
- `network-probe.json`：localhost:8000三个接口均404，真实联网未验证，未修改后台服务。

## 本地预览与下一步

启动：`./artifacts/realism59-preview/Linux/IronMeridian --path /tmp`，选择Solo。相邻PCK、README、许可证、build.json与verification.json齐备；这是Godot开发可执行文件加导出PCK，不是正式发行模板包。哈希对应本轮未提交工作区。

当前建筑仍重复、院落空旷，草丛和远山树木分布失真，手臂缺乏自然体积，人物与光照仍需进一步审阅。下一阶段应做正常视角可见的手臂体积/腕部连接和材质改善，并推进院落建筑差异、泥草过渡及植被分布；实拍复核移动碰撞。联网需可用接口后补真实双客户端验证。本轮不构成整体目标完成。

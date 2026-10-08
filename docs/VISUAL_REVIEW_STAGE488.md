# Stage488：路肩几何调整与当前预览复验

本轮状态：继续开发，**道路视觉修复未验收，整体目标未完成**。

## 修改与实机环境审阅

收窄道路路肩横断面，将外侧土埂峰值由距中心 8.1m、高 0.38m 调整为 6.5m、高 0.29m；调整入口展宽及材质混合距离。修改位于 `client/scripts/world_visuals.gd` 和 `client/shaders/road_surface.gdshader`。

使用当前导出的 stage488 PCK，在 Forward+ / llvmpipe 下取得道路远景、维修棚入口和宽幅地形截图，与 stage487 原机位比较。三组相机位置和朝向均匹配。证据位于 `artifacts/realism488-validation/comparison/`，逐张人工审阅结论如下：

- `road-horizon-comparison.png`：两侧宽棕色区域仍明显，边缘变化不足以改善整体观感。不能把这次几何调整认定为完成道路过渡。
- `repair-shelter-entrance-comparison.png`：入口可见，屋顶、金属框架和轮胎有一定细节；道路到场地仍显平板，手臂长管状轮廓明显。
- `terrain-wide-comparison.png`：前场大面积灰色地表、重复圆树冠、平滑山体仍存在，前后整体效果接近。

诊断发现，共享 `client/shaders/meadow_surface.gdshaderinc` 使用 `min(abs(p.x)-8.0, abs(p.y)-7.0)` 定义道路距离，并在最终地表色上覆盖宽碎石带。因此 road shader 提前混入共享地表仍得到碎石，而非恢复的自然地面。该共享文件本轮未修改，已保存源码快照；下一阶段应统一道路、地形、入口的距离场及覆盖顺序，不能继续仅调整颜色或路肩峰值。

机位（坐标 x,y,z；其余参数及朝向见 `after/*camera*.json`）：

| 视图 | 相机位置 | 观察目标 |
| --- | --- | --- |
| road-horizon | (2,1.65,61) | (0,3.2,-85) |
| repair-shelter-entrance | (15.5,1.65,39) | (15.5,2.3,27) |
| terrain-wide | (17,1.65,50) | (-46,12,-90) |

## 当前版本功能验证

`artifacts/realism488-validation/functional-processes.json` 记录四项进程均退出 0：

- `roads/graded-road-traversal.json`：24 项道路通行结果通过。
- `shelter/repair-shelter-traversal.json`：32 项结果通过，包含 7 条通行路线及 25 项碰撞检查。
- `aim/aim-damage.json`：三种武器的暴露目标/掩体目标共 6 项伤害结果通过；范围为本地权威逻辑，不等于联网认证与联机交互通过。
- `offline/run.log`：单机冒烟通过，覆盖机器人、换弹、治疗、伤害、胜利与遮挡射线等逻辑。

## 人物审阅

卡宾枪完整四姿势已生成并逐张审阅：`sleeve/process-result.json` 记录未使用姿势过滤、退出 0、耗时 548.883 秒；`sleeve/sleeve-pose-review.json` 保存状态。截图捕获通过不代表人物画质通过：

- `default-spawn.png`：左前臂细长直管状，手套掌部块状，袖口像独立厚环。
- `ads.png`：红点位于画面中央，左手靠近护木；肘腕体积变化不足，厚袖口仍明显。
- `reload-middle.png`：左手持弹匣、右手握枪，基本分工可辨；双臂像直筒，静帧不足以确认插匣路径和接触。
- `reload-complete.png`：恢复持枪与护木附近的支撑位置，弹量由 29/120 回到 30/119；长管状前臂问题恢复出现。

其他武器及第三人称四张补充截图已全部生成并逐张审阅；`contact/process-result.json` 记录退出 0、耗时 628.033 秒，状态及相机见 `contact/contact-review.json`：

- `weapon-1-reload-50.png`：霰弹枪左手持弹匣、右手握枪；右侧枪身占屏较大，直筒袖子、厚袖口和块状手掌明显，不能据此确认插匣接触。
- `weapon-2-reload-50.png`：精确射手步枪瞄具与弹匣可见，双臂仍细长笔直，袖口呈圆筒、掌部缺少体积层次。
- `third-stand-reload-middle.png`：肩部及弯肘呈团块，持枪手与机匣附近较拥挤；另一手下降到腰侧。肩托和手掌接触被身体、装备部分遮挡，未能充分判定。
- `third-crouch-reload-middle.png`：双膝抬高遮挡换弹手及弹匣路径，持枪与膝部间隙很小，不能判定无穿插；远处角色离地，需要连续帧区分跳跃与悬空缺陷。

应优先修复整条手臂的肩肘腕形体及运动约束，不能以继续微调手指代替。第三人称机位约为 (2.8,1.5001,65)，欧拉角约 (-0.13323,2.39066,0)，同机位站蹲对照；下一次增加侧面连续记录以消除接触遮挡。

静态截图即使模拟了逐帧逻辑，也不证明连续动作自然。本轮未覆盖连续换弹的弹匣交换、回握、跑跳落地衔接及完整联网流程。

## 本地预览与后续

运行 `artifacts/realism488-preview/Linux/launch.sh`。PCK SHA256：`3d9a3e1e00583032c7f1be01a17ab3e62a3351c9b006c39e0acf4a1189472863`。源码快照及构建哈希见 `artifacts/realism488-validation/build-manifest.json`。

下一阶段优先修复共享地表距离场与路肩的结构性不一致，再做同机位实机比较和入口通行复验；结合本轮人物截图安排整条手臂形体及接触修复。建筑、地形植被、光照与联网验证仍属于未完成目标。

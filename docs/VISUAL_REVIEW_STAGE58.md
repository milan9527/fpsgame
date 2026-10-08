# Stage58：手套指腹形体与同机位复核

日期：2026-09-13。状态：continue，整体写实目标未完成。

本轮修改 `tools/build_viewmodel.py`，将两手原先收成尖点的末节改为保留厚度的指腹和浅圆顶；圆顶回退到原指尖端点之后，重新分布末段截面，避免曲面折返。重建 `art/first_person.blend` 和 `client/assets/first_person.glb`。沿用已有手套材质、骨架与接触锚点；本轮没有新增材质改善。

## 实机画面审阅

- `artifacts/realism58-validation/after/`：三武器各腰射、ADS、换弹1/4、1/2、3/4，共15张实际Godot截图，采集退出0。固定位置和朝向，ADS使用各武器实际变焦；软件Vulkan Forward+，不代表实体GPU性能。
- `artifacts/realism58-validation/all-poses.jpg`：15张总览，已自审。三种ADS视野保留，未见新增明显枪手脱离；静态采样不能证明整段动画无穿插。
- `artifacts/realism58-validation/carbine-comparison.jpg`：stage57/58采用相同裁切的腰射、ADS和半程换弹对比。正常腰射与ADS改善很小，较丰满指腹主要在换弹露出时可见。
- 另查看原尺寸卡宾枪腰射/ADS、霰弹枪和精确射手步枪半程换弹。左拇指不再快速收为尖钩，但手部姿态仍显机械；宽大光滑枪托、平整机匣和厚重瞄具仍明显。重复仓库、空院落、离散草丛及剪纸感远景树没有解决。本轮是局部修正，不能认定第一人称或整体画面已达标。

## 验证与预览

- `artifacts/realism58-validation/tests.json`：8项检查均退出0且无ERROR，包含108瞄准样本、183换弹接触样本、视模、手套表面、抵墙、预测、可靠动作及16人单机烟测。
- Blender构建、Godot导入、PCK导出均退出0。`import.log`仍记录一条 `ERROR: Parameter "t" is null.`，未解决；导出日志无ERROR。
- 新PCK与Godot开发可执行程序组成当前本地预览：`./artifacts/realism58-preview/Linux/IronMeridian --path /tmp`。独立运行导出包的headless单机烟测退出0，见 `preview-smoke.log`。截图来自工作区运行；没有将工作区截图描述成导出包截图。
- 预览目录中的 `build.json`、`verification.json`记录生成器、模型、程序、PCK、截图和日志哈希及验证限制。这不是原生release-template导出。
- `network-probe.json`：本地8000端口health/protocol/openapi.json均404，真实多人主要功能未验证；预测和可靠动作规则通过不能替代双客户端测试。未改服务或发布。

## 下一阶段

避免继续仅微调遮挡中的指尖：优先改善正常腰射可见机匣、枪托和瞄具的轮廓与金属/聚合物材质分离，保持三武器同机位腰射/ADS复核。随后推进院落建筑差异、泥草过渡、植被分布、人物近景和光照，补入口/移动碰撞实测；API恢复后补真实双客户端验证。

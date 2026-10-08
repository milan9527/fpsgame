# Stage56 第一人称袖管形体与同机位复核

本轮以stage55实际资产为基线，修改 `tools/build_viewmodel.py` 的袖管截面：收窄前臂，加入纵向布料张力起伏及两组局部斜向压褶。重建 `art/first_person.blend` 和 `client/assets/first_person.glb`。未新增枪械材质修改；沿用已有织物法线与枪身材质。握持位置、骨骼与动画轨迹不变。

## 实拍审阅

`artifacts/realism56-validation/after/` 为当前项目的Forward+实机捕获，固定角色位置、朝向及俯仰，三武器各腰射、ADS及三个换弹时刻。`stage55-56-ar-comparison.jpg` 将stage55同机位原图与本轮原图等比例排列，不修改画面内容。

AR对照可见袖管变窄、换弹时左前臂轮廓及压褶明暗更不均匀，粗直筒感有所减轻。腰射尺度下变化较小；ADS中心红点与瞄具窗口清楚，没有因袖管修改遮住瞄线。迷彩仍是偏大的色块，褶皱受力和手腕过渡尚不够自然。枪身宽平面、简化手套仍明显，不能把本轮局部改善当成写实第一人称完成。

环境保持基线：仓库重复、空院落、道路硬边和规律草簇仍突出；远处树木、山坡及人物也尚未达到目标。截图使用Xvfb/llvmpipe软件Vulkan，不代表物理GPU性能；本轮没有重新进行stage29验证。

## 验证与预览

- `artifacts/realism56-validation/tests.json`：10项检查均退出0，瞄准108样本、换弹接触183样本、抵墙遮挡、第一人称/武器视觉/手套/枪身材质规则、预测、可靠动作及单机烟测通过。
- `preview-smoke.log` 与 `artifacts/realism56-preview/Linux/verification.json`：导出包实际启动单机烟测退出0，覆盖16角色、换弹、治疗、伤害、胜利、射线、掩体等。
- `network-probe.json`：三个本机API路径仍404，服务器为SimpleHTTP文件服务。真实双客户端联网没有通过验证；预测和可靠动作仅为规则测试。没有修改后台服务。
- `blender.log` 记录资产生成PASS；`import.log` 仍有既有 `Parameter "t" is null` 错误，导入退出0，不将其隐去。
- 本地启动：`./artifacts/realism56-preview/Linux/IronMeridian --path /tmp`，保留相邻PCK。README与build.json记录使用Godot程序配导出PCK（缺发布模板）以及资产/包哈希。

状态continue。下一阶段应扩大可见收益：改善院落差异与道路泥草过渡，验证入口/移动碰撞并保留第一人称回归；继续人物、植被与光照，API恢复后做真实双客户端测试。

捕获最终正常退出0，日志为 `WEAPON_REVIEW_CAPTURE_PASS frames=15`。已审阅 `contact-sheet.jpg` 三武器全部姿态及AR原图/同机位对照；SG与SR瞄具保持可用，所拍姿态未见新增明显腕部断裂。缩略总览不能排除全部动画时刻的细小穿插。截图SHA256保存于预览目录verification.json。

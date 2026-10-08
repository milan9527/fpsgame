# Stage444：场地边缘试验与当前包复验（未完成总体目标）

本轮对 `service_yard.gdshader` 的矩形边界改用带圆角的距离场、世界尺度侵蚀和较宽透明过渡，并扩大 `world_visuals.gd` 对应支撑平面。实机同机位对照**未显示有意义的道路改善**。不能将这次试验记为道路硬矩形色差已解决，也不能据此继续堆叠色值或噪声微调。

## 环境证据与判断

证据根目录：`artifacts/realism444-validation/`。

- `service-comparison.jpg`：443/444 服务入口全图及地面裁剪。肉眼审阅基本一致，硬边问题仍未定位到具体绘制层。
- `depot-entrance-close-comparison.jpg`：同机位入口近景。实体坡道边沿仍是明显直线；透明场地边缘修改没有改变其几何。
- `terrain-wide-comparison.jpg`：同机位宽幅地形。光滑尖峰山体和重复树冠仍然突出，未在本轮修改。
- `environment-before/` 和 `environment-after/` 保存原始 1280×800 PNG；`camera-comparison.json` 确认两组相机记录完全一致。

相机位置与朝向（Godot 世界坐标，方向为单位向量）：

| 机位 | 相机位置 | forward |
| --- | --- | --- |
| service-approach | (17, 1.600103, 50) | (0, 0.099833, -0.995004) |
| depot-entrance-close | (35, 1.65, 44) | (0, 0.024992, -0.999688) |
| terrain-wide | (17, 1.65, 50) | (-0.409435, 0.067264, -0.909856) |

after 捕获程序正常退出且通过。before 的包装进程退出 143；底层日志有 `ENVIRONMENT_REVIEW_CAPTURE_PASS`，三张 PNG 和相机记录均已恢复，包装状态仍保留失败，未改写成正常通过。

## 当前包功能验证

全部以下检查使用 444 导出包；不是引用旧阶段结果：

- `functions/depot-traversal.json`：雨棚、仓库正门、维修入口六条双向通行路线和两侧墙体碰撞射线通过。
- `functions/road-verge-traversal.json`：道路边缘通行通过。
- `functions/aim-damage.json`：三种武器各自无遮挡命中与掩体阻挡共六种情况通过。
- `functions/offline-smoke.log`：`OFFLINE_SMOKE_PASS`，涵盖 16 个角色、换弹、治疗、伤害、胜利、射线、掩体、射速和骨架检查。

对应 `*-process.json` 保存退出码、脚本/包哈希和耗时。通行与规则断言不证明画质或连续动作自然。

本轮联网未验证。已检查的 `tools/test_foregrip_network.py` 依赖本地认证 API、账号和 `.env` 中的服务凭据，且默认使用源码运行。本轮未读取凭据、未启动该测试，也没有把历史联网结果视为当前包通过。

## 人物与动作审阅

首次四姿势捕获 `poses/` 在只得到 default-spawn 后中断，退出 -15；保留原始失败状态。完整四姿势重试 `poses-full/` 未传入单姿势过滤，638.925 秒正常退出 0，`SLEEVE_POSE_REVIEW_PASS reload_refilled=true`。default-spawn、ads、reload-middle、reload-complete 四张图片均已实际审阅：ADS 视线未见明显遮挡，换弹完成弹量恢复 30/119，但左前臂细长、腕袖衔接生硬，换弹竖起右臂的管状轮廓仍突出。截图与补弹断言通过不代表连续动作自然。

`motion/` 是主动中止的低成本兼容渲染诊断，仅恢复卡宾枪 18 张采样图（帧 000 至 102，步长 6）；`motion/viewer.html` 可逐帧查看。已审阅的 `motion-partial-grid.jpg` 中，换弹伸手与竖起前臂仍有明显管状轮廓，左手伸向画面下沿空区。不能从这些稀疏样本判定弹匣接触或插值过程，不能宣称完整换弹通过。该诊断关闭阴影并裁去远景，也不能作为正常画质证据。

其他武器及第三人称的采样输出为 `contact/`，范围为霰弹枪/狙击枪换弹中点、第三人称站立/蹲姿换弹中点。它们是实机动作采样，不是连续动作验证。

四张均已捕获并实际审阅，程序 759.161 秒退出 0，`WEAPON_CONTACT_REVIEW_PASS`；包和脚本哈希见 `contact/process-result.json`。第三人称站立有方块状肩部和突出的肘部轮廓；蹲姿中前臂、弹匣与膝部区域拥挤，遮挡使精确接触难以判断。人物脸部、手套和靴子仍明显简化。没有验证移动换弹、完整肩肘插值或弹匣插入全过程，不能把捕获通过记为动作自然通过。

已审阅霰弹枪与狙击枪中点：右手位于握把后侧，狙击枪握把与手掌的接触尤其可疑。左手持弹匣，但单张中点不能证明插入轨迹正确。后续应联合调整各武器握持定位和肩肘腕整体形体，不能仅微调袖口或手指。当前镜头也不能完整检查第一人称肩部。

## 本地预览与下一步

运行：`artifacts/realism444-preview/Linux/launch.sh`（需要图形显示环境）。导出和实际捕获已经使用同一可执行文件与 PCK。

PCK SHA256：`d0964fc966f23c4ce714cc4b2b56c536ce93f7b0d35d796379625e4f326e5adc`。构建输入与可执行文件哈希见 `artifacts/realism444-preview/provenance.json`。保留已有未提交修改；本轮未推送或发布。

下一阶段先在相同服务入口机位隔离主路、service-access、service-yard、实体坡道与阴影，确认硬边所属表面，再修改交接几何/材质层。必须得到肉眼可见的同机位改善，不能继续把未奏效的边缘噪声试验算作进展。随后按完整人物截图处理肩肘至腕部整体体积、握持和换弹轨迹，并补三种武器与第三人称连续动作。山体、树冠、建筑空间、光照和当前联网验证仍在总体目标内。

# Stage480 当前预览审阅

本轮状态：继续。道路/场地重复覆盖已修正，但横向色差仍未彻底消除，不能把局部改进判作整体画质完成。

## 修改与当前包

- `client/scripts/world_visuals.gd`：维修场地覆盖面从全地图 224×224 收到实际场地 52×46，中心移到 (-1, 0.044, 33)，命名 `ServiceYardGround`。
- `client/shaders/service_ground.gdshader`：取消场地面重复绘制的道路肩部和骨料带，路肩由已有渐变网格负责；保留场地本身及实际道路碰撞。
- 本地启动：`artifacts/realism480-preview/Linux/launch.sh`。
- PCK SHA256：`00f1d0f2d3b88baf66d9d0d0a235e0c648333b498196445ff99c503eee2418b0`。
- 导出日志：`artifacts/realism480-validation/export.log`。以下当前验证使用此包，stage479 仅用作同机位画面对照。

## 环境实机对照

`artifacts/realism480-validation/environment/process-result.json`：Forward+，1280×800，非诊断降级画面，退出 0，采集通过。三张对照均已人工查看，左侧 stage479，右侧 stage480：

- `comparison/road-horizon-comparison.png`：右侧道路肩部重复浅色边带消失，边缘更连贯；道路横向色差仍可见，路肩细节偏模糊、规律。
- `comparison/repair-shelter-entrance-comparison.png`：入口通道可见，没有明显画面退化；建筑体块和材质仍偏简单。
- `comparison/terrain-wide-comparison.png`：远景整体差异有限，光滑山体、重复树冠和植被排列仍突出。

上面相对路径均位于 `artifacts/realism480-validation/`。`comparison/camera-comparison.json` 保存双方元数据和文件哈希，三组相机匹配。

| 机位 | 相机世界位置 | yaw / pitch（弧度） |
| --- | --- | --- |
| repair-shelter-entrance | (15.5, 1.649999976, 39) | 0 / 0.054113782 |
| terrain-wide | (17, 1.649999976, 50) | 0.422853926 / 0.067315195 |
| road-horizon | (2, 1.649999976, 61) | 0.013697773 / 0.010615044 |

## 当前功能证据

`artifacts/realism480-validation/functional/results.json` 绑定上述 PCK，各测试退出 0，无记录的脚本错误：

- graded_road_traversal_review：8 条道路/肩部路线通过。
- repair_shelter_traversal_review：7 条入口/场地路线及树木通行间距通过。
- aim_damage_review：三种武器无遮挡命中与墙体阻挡，共 6 个案例通过。
- offline-smoke：16 名角色、换弹、治疗、伤害、胜利、射线、掩体、射击间隔、骨架检查通过。

这证明脚本覆盖的单机行为与碰撞，不代表联网或所有可见动作自然。

## 无效尝试与缺口

- 首次导出遗留已删除的 `shoulder_width` 引用，产生 shader 编译错误；已经修复并重新导出。`environment-invalid-shader/`、`functional-invalid-shader/` 保留排错证据，全部排除通过结论；首次功能调用也缺少截图输出环境变量，正确版本已重跑。
- `network-dependency.json`：对本机 `/auth/login` 的未认证空请求返回 404。未读取认证信息，未修改后台服务；当前版本联网主要功能尚未验证，不能将此前检查点的联网结果继承为通过。
- 定点图只用于形体和接触检查，未覆盖连续跑动、瞄准过渡、完整换弹轨迹。

## 第一人称完整四姿势

`sleeve-poses/process-result.json`：未指定单个姿势，完整四姿势运行退出 0、passed=true，549.331 秒，包哈希与上述预览一致。以下四张均已查看：

- `sleeve-poses/default-spawn.png`：左手位于护木，左前臂呈细长袖筒，近肘段不规则鼓起，腕部突然收窄。
- `sleeve-poses/ads.png`：瞄具中心可见；左腕与前臂仍细长。肩肘大部分在画面外，不能据此确认其动作自然。
- `sleeve-poses/reload-middle.png`：左手握住离枪的弹匣，右手留在握把；袖口到手腕过渡僵直，孤立中段不能证明装卸弹匣全程接触。
- `sleeve-poses/reload-complete.png`：左手回到护木，弹药显示 30/119；袖筒形体缺陷仍在。

## 其他武器与第三人称实机补充

`weapon-contacts/process-result.json`：scope 为 `other-weapons-and-third`，四张齐全、退出 0、passed=true，630.752 秒；包哈希与当前预览一致。以下四张均已查看，采集通过不等于动作质量通过：

- `weapon-contacts/weapon-1-reload-50.png`：霰弹枪换弹中段，左手持离枪弹匣；前臂细长、近肘鼓包和袖口突变仍明显，右手与握把边界不够清楚。
- `weapon-contacts/weapon-2-reload-50.png`：狙击枪换弹中段，左手握弹匣；瞄镜和机匣仍有简单体块感，同样存在前臂形体问题。
- `weapon-contacts/third-stand-reload-middle.png`：站姿人物头脸缺乏结构，装备体块简化；左手在腰侧，右手与握把的接触被胸前装备遮挡，肩肘自然程度不能据此判定通过。
- `weapon-contacts/third-crouch-reload-middle.png`：蹲姿膝盖抬到胸前，手、弹匣、膝部相互遮挡，接触和穿插需要近景连续过程核验；远处另一个角色呈离地状态，单帧无法区分跳跃与异常悬空，记录待查。

`weapon-contacts/contact-review.json` 保存位置、相机和换弹时间。第三人称相机约为 (2.8, 1.5001, 65)，朝向旋转 (-0.13323, 2.39066, 0) 弧度。本次仅覆盖其他两种武器的换弹中段、第三人称站/蹲换弹中段；未覆盖完整连续换弹、第三人称行走/跑动/瞄准过渡及联网动作同步，不能据此宣称连续动作自然或接触全程正确。

## 后续结构性修改与验证

1. 人物：优先重做第一人称上臂—肘—前臂—袖口的整体截面和蒙皮过渡，结合肩部约束检查固定臂长下的变形。当前 `tools/build_viewmodel.py` 的袖筒截面/权重与 `client/scripts/first_person.gd` 的双骨 IK 是候选检查位置，尚不能把具体根因当作已证实。每次改动后重跑完整四姿势，并补充连续换弹、瞄准进出与跑动过程的实机证据。
2. 环境：本次边带修复不足以解决道路横向色块；需要隔离场地/路口贴面交叠后再改结构，保留相同机位对照及入口通行回归。光滑山体、重复树冠、简单建筑材质与光照层次仍在总目标内。
3. 功能：保留当前单机与命中/碰撞检查；明确本机联网接口的实际依赖后补做当前包联网主要流程，不能将 404 探测或旧测试算作联网通过。

# Stage126：维修库侧向工作棚与院地用途

本轮整体状态 **continue**。正常接近机位能辨认新的侧棚体量、棚下照明和分缝地坪，局部空院地获得明确用途；仍远未达到整个场景的写实目标。

## 实施与画面判断

- `world_visuals.gd` 新增维修库东侧工作棚：斜金属顶、檐沟、支柱与斜撑、后挡墙、工作台及两处暖色灯具。结构有独立实体碰撞，南侧可进入。
- 约10×16米分缝工作地坪和外侧草带连接已有院地；保持主入口及道路通路。
- 已审阅125/126包的正常接近实机原图。过去暗而完整的侧墙现在呈现屋顶伸出、棚柱遮挡、受光墙面与开放工作空间。棚缘草带有局部变化，不能声称整体植被已写实。
- 门口近景仍有空室内、过平地面、偏暗武器和袖子折面；侧棚灯管偏白亮、地坪分缝较规则，新挡墙仍显厚重。新增附属体量改善这栋车间，但其余重复小屋、规则尖山和稀疏重复树形仍待处理。
- 宽景配对已人工审阅：左侧维修库有新增棚体和受光墙面，但全景变化有限，前景院地仍空。东侧仓库入口原图也已审阅，通透门洞保持清晰，箱体与平滑室内地面的真实感仍不足。

## 可复核采集

`artifacts/realism126-validation/before/` 为125包，`after/` 为126包；均以实际单机场景、Forward+ Vulkan llvmpipe采集1280×800截图，保留HUD。固定模拟用于同机位比较，不能作为帧率或完整战斗验收。

相机精确坐标与朝向保存在两目录的 `environment-camera-poses.json`；actor眼高偏移1.6米：

| 机位 | actor位置 | yaw / pitch（弧度） |
| --- | --- | --- |
| west-workshop-approach | (-17, .05, 49) | 1.030377 / .073611 |
| west-workshop-entrance | (-42, .05, 44) | 0 / .024995 |
| depot-entrance-close | (35, .05, 44) | 0 / .024995 |
| terrain-wide | (17, .05, 50) | .422854 / .067315 |

配对比较与哈希由 `summarize.py` 生成；相机必须逐项相等才输出 `capture-evidence.json`。

四组机位逐项相等，已生成 `*-comparison.jpg`。前置采集退出0；最终采集日志打印 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=4`，四张原图与机位JSON全部落盘，但外层会话退出143，不能记为正常退出。截图证据可复核，异常退出原因未确定。导入和导出包均退出0。

## 验证

新增 `tests/service_bay_traversal_review.gd` 使用实际actor移动：南侧进入终点z31.24992、退出z45.75008；柱阻挡z40.52499、后墙阻挡z27.00005；向上射线命中新棚顶y3.689565。五项均通过，原始数据见 `service-bay-traversal.json`。

最终导出包的九项回归全部退出0且无脚本错误：新增侧棚、道路、维修库与仓库通行，入口碰撞、屋顶碰撞、108样本瞄准、武器遮挡和网络状态规则。另有单机战斗脚本冒烟退出0，日志打印 `OFFLINE_SMOKE_PASS actors=16 reload=ok heal=ok damage=ok victory=ok raycast=ok cover=ok fire_interval=ok rig=ok`。见 `artifacts/realism126-validation/functional-results.json` 及对应日志。这是自动化战斗回归，不能替代完整人工对局。网络状态规则仅是本地规则验证，真实认证联网仍缺授权fixture，未声称联机验收通过。包及记录的源码哈希再次核对通过。

## 本地预览与后续

本地启动：

```bash
./artifacts/realism126-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

同目录必须保留 `IronMeridian.pck`，需要桌面与Vulkan环境。`artifacts/realism126-preview/README.md` 记录操作，`build.json` 记录包和源码哈希。未推送、未发布；保留已有未提交修改。

后续优先减少宽景重复小屋/规则山体，补充有用途的地形和建筑空间；结合第一人称连续动作与第三人称实图修复袖子折面、霰弹枪装填和人物装备/蹲姿/弹匣接触。继续单机战斗、瞄准碰撞回归，真实联网单列待验证。不得以本轮局部改善判定整体完成。

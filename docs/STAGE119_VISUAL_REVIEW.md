# Stage119 环境阶段实机审阅（2026-09-14）

本轮完成西侧建筑轮廓、沿墙地表植被和阴影覆盖距离的一组改进，提供本地 stage119 预览；整体写实目标仍未完成。没有推送或外部发布，保留既有未提交修改。

## 改动与实际观感

- 西侧指定建筑复用已有坡顶/单坡顶组件；西车间 (-42,0,34) 加入通风天窗。保持已有随机数消耗顺序，避免无关布景重排。西车间正常接近机位从棕色平顶方盒变为有坡顶与天窗的绿色工业建筑；入口材质随现有建筑样式切换，入口、室内及背面出口保留。
- 每栋建筑侧院外缘加入无碰撞、不写深度的薄层土壤过渡，沿墙草带使用噪声打散边界。草材质淡出从 24–48m 延长至 42–80m，单元可见范围至 90m。中景墙脚植被更连续，但黄色土带仍偏显眼，地面依然有大块均质空地。
- 太阳阴影覆盖从 110m 调至 170m。此次截图不足以证明整体光照质量有明显提升；仍需检查级联阴影精度与真实 GPU 性能，不能将参数调整当作光照验收。

主要对照（左 stage118，右 stage119；均为导出游戏实机画面）：

- [西车间接近](../artifacts/realism119-validation/west-workshop-approach-before-after.jpg)：坡顶和天窗可辨识；近处草及墙脚草带更加连续。后排墙体、门窗、箱体仍重复。
- [西车间入口近景](../artifacts/realism119-validation/west-workshop-entrance-before-after.jpg)：门洞、照明和背面出口可见；主要变化是样式切换，并非新建完整建筑套件。
- [宽幅地形](../artifacts/realism119-validation/terrain-wide-before-after.jpg)：左侧坡顶进入正常视野，右侧地表过渡及草更明显；道路、广场仍空旷，远山棱面与重复排列的建筑仍是主要缺陷。
- [补充画面索引](../artifacts/realism119-validation/after-review-contact.jpg)：雨棚、室内灯具、室内地板和森林机位。室内仍简陋，树木稀疏、树冠单薄，手臂及武器表面仍偏塑料质感。本轮未完成第三人称与手部连续动作审阅。

## 相同机位复现

使用同一份 `tests/environment_review_capture.gd` 分别加载 stage118/119 导出包，调用单机启动后固定角色位置和视角，Forward+ / llvmpipe，1280×800。截图冻结用于稳定对照，不作为通行证据。下表位置为角色脚点，相机眼高偏移 1.6m；yaw/pitch 为弧度。完整位置、目标点及精度见 before/after 的 `environment-camera-poses.json`；校验确认两组完全一致。

| 机位 | 脚点 (x,y,z) | yaw | pitch |
| --- | --- | --- | --- |
| west-workshop-approach | (-17.0000, 0.0500, 49.0000) | 1.030377 | 0.073611 |
| west-workshop-entrance | (-42.0000, 0.0500, 44.0000) | 0.000000 | 0.024995 |
| depot-approach | (17.0000, 0.0500, 46.0000) | -0.862170 | 0.029819 |
| depot-canopy | (23.5000, 0.0500, 42.0000) | -0.135528 | 0.031516 |
| depot-entrance-close | (35.0000, 0.0500, 44.0000) | 0.000000 | 0.024995 |
| terrain-wide | (17.0000, 0.0500, 50.0000) | 0.422854 | 0.067315 |
| depot-interior-fixture | (35.0000, 0.0500, 38.0000) | 0.000000 | 0.502843 |
| depot-interior-floor | (35.0000, 0.0500, 38.0000) | 0.000000 | -0.221314 |
| forest-eye-level | (-111.1871, 0.0500, -72.4752) | 0.000000 | 0.230812 |

## 功能、碰撞与证据

`artifacts/realism119-validation/functional-results.json`：13/13 通过。包含单机启动、瞄准对齐、武器遮挡规则、入口和屋顶碰撞、雨棚净空与掩体、仓库/服务院/棚架/供水设施通行，以及本地联网状态规则。对应同名 `.log` 位于该验证目录，检查进程退出码、PASS 标记且无脚本错误。

`warehouse_traversal_review` 使用实际物理角色，东西两栋仓库各做正反向穿越：x=35 和 -42，z=44→约24.97、24→约43.03，四条路线通过，未禁用地板。结果详见 `after/traversal.json`。屋顶测试覆盖 11 个坡顶、东西车间通风天窗及门洞射线净空，日志为 `ROOF_COLLISION_PASS roofs=11 slopes=ok shots=blocked doorways=clear`。

两组截图日志均为 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=9`，无错误。`compare-captures.py` 检查相同机位、图像尺寸、两组日志、13项结果，以及 build.json 中源码/测试/预览的8项 SHA256；输出 `verification.json`，全部匹配。截图数量只代表复现覆盖，不代表画质达标。

真实联网没有在本轮测试；本地状态规则不能代替两客户端联机、同步及断线恢复验收。未获取外部认证或读取密钥。软件渲染截图不能代替目标 GPU 帧率及阴影性能测量。静态第一人称画面与瞄准测试不能代替连续开火、瞄准、换弹手部动作及第三人称人物验收。

## 当前本地预览与下一步

预览：`artifacts/realism119-preview/Linux/IronMeridian` 和同目录 `IronMeridian.pck`，构建信息见 `../build.json`，使用说明见 `../README.md`。从项目根目录运行：

```sh
./artifacts/realism119-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

下一阶段优先处理宽景中的远山棱面与空旷中景：以当前 terrain-wide / west-workshop-approach 为固定对照，改进地形轮廓与植被组团，避免仅增加重复道具；复测通行、遮挡与阴影表现。随后继续第三人称人物及第一人称瞄准/开火/换弹连续动作实机审阅，并完成真实联网主要流程。整体目标继续，不能将本轮局部建筑与草带改善判为完成。

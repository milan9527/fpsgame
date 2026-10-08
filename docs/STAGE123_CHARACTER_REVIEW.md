# Stage123：第三人称换弹轨迹与预览回归

接续122动作审阅，第三人称左手从基本停留在护木附近改为离开握持点、经过弹匣区域、下探腰侧，再返回握持点。修改 `tools/build_operator.py` 并重建 operator.blend/operator.glb；没有改动本轮环境几何、地表或光照。整体目标仍为 continue。

## 实机审阅

证据根目录：`artifacts/realism123-validation/`。

- `reload-comparison.jpg`：已查看前后八个相同采样时刻；下探与回握现在明显。`before/` 与 `after/` 各保存39帧及 action-timeline.json，`review.html` 可逐帧比较。390模拟步包含走、跑、蹲行、射击、换弹。相机位置、旋转、动作、弹量和蹲伏状态逐帧匹配，见 action-verification.json。
- 第三人称机位从人物(17,0.3,50)开始，跟随偏移(2.8,1.5,-3)，朝向人物+(0,0.95,0)，FOV42；每帧精确位置/朝向均在JSON。Compatibility/llvmpipe，960×540。采样约5Hz，画面缓冲有延迟，不代表运行性能或逐帧接触验证。
- 左手仍没有实际取出独立弹匣；霰弹枪仍共用动作。身体装备块状、脸部过暗、前臂折面、握持接触与蹲姿仍需改善，不能称人物动作验收完成。
- 新包独立加载PCK，以 Forward+/llvmpipe 1280×800 完成入口、室内地板及宽幅地形截图，日志 `packaged-environment.log` 返回 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=3`，进程退出0。已查看三张原图：仓库入口可辨认，但室内单调，中央地缝仍可见；道路空旷、重复小屋、规则植被与山体形状仍明显。第一人称袖子硬折面仍存在。本轮环境图属于包内回归，不作为环境改进证据。
- 包内机位文件：`packaged-environment/environment-camera-poses.json`，包含人物脚点、眼高、目标和yaw/pitch。入口脚点(35,.05,44)，yaw0/pitch.024995；宽景(17,.05,50)，yaw.422854/pitch.067315；室内(35,.05,38)，yaw0/pitch-.221314；眼高均1.6。

## 验证与局限

`functional-results.json` 八项均退出0：换弹轨迹、瞄准、武器遮挡、入口碰撞、屋顶碰撞、本地网络状态规则、仓库实际双向通行、动画蒙皮。换弹测试覆盖三武器时长及站/蹲姿，左手行程约.619–.622米，右手/武器锚点最大漂移低于.01米；动作结束回到握持点。仓库通行沿x=23.5从z44到18.425及z18到43.575通过，见 depot-traversal.json。

初次动画检查因旧“四材质”断言失败，保留 animation_rules-initial.log；更新为既有五材质且明确验证靴子皮革名称后通过。重跑日志首行Terminated来自旧进程终止，当前测试退出0。Blender构建仍报告 Front shaped plate pocket 无效网格警告，未在本轮修改几何来解决。真实认证联网缺授权fixture，网络规则通过不等于真实联网通过。

## 本地预览与下一步

`artifacts/realism123-preview/Linux/IronMeridian` 与相邻 `IronMeridian.pck` 已导出并实机运行。README.md含启动命令，build.json记录构建输入及包哈希。所有未提交修改保留，未推送或发布。

下一阶段应回到正常机位可辨认的环境组合改进：建筑院落用途/体量差异、路边植被过渡与棚顶受光，保存同机位前后及入口/宽景证据并复测通行。人物后续继续第一人称袖子、霰弹枪装填、第三人称弹匣接触及蹲姿，不能连续只调手部细节。

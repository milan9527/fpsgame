# Stage460：道路混合足迹与当前包人物复核

## 实际修改及画面判断

修改 `client/shaders/road_surface.gdshader`：摄影路面采样从方形网格的四角混合改为旋转、噪声扭曲域中的三角足迹混合，保留世界空间纹理坐标与纹理梯度。目的在于减少横跨道路的轴对齐混合边界，并非修改整体道路色值。

实机前后对照已经人工查看：近景裂纹分布及混合边界有变化，但整体改善有限，不能认定明显横向色差全部消除，也不能将此阶段当作道路/场地整体修复完成。坡肩地形沿用459；本轮没有增加新的几何起伏。入口通道清晰，墙板与混凝土块仍重复；宽幅图中的远山折面和同形树冠依然明显。光照及建筑多样性仍需继续改善。

## 环境证据

`artifacts/realism460-validation/` 内三张 `*-before-after.png` 为459左、460右；`camera-comparison.json` 核对相机位置、forward、yaw、pitch与viewport完全相同。459仅作图像基线，不能继承其进程验证结果。460 `after/process-result.json` 为退出0且passed=true，三张当前包Forward+、1280×800截图完整；软件Vulkan llvmpipe。

- `road-horizon`：位置(2,1.65,61)，forward(-0.01369657,0.01061484,-0.999849855)。
- `repair-shelter-entrance`：位置(15.5,1.65,39)，forward(0,0.054087378,-0.998536229)。
- `terrain-wide`：位置(17,1.65,50)，forward(-0.409435272,0.06726437,-0.9098562)。

## 当前包功能结果

`artifacts/realism460-validation/functions-verified/` 五项process JSON均为passed=true、exit_code=0，日志包含对应PASS标记：graded、shoulder、building、aim、offline。

建筑测试覆盖棚道、前门、维修入口双向移动及两侧实体阻挡。瞄准测试覆盖AR/SG/SR无遮挡命中扣血与有遮挡零伤害。单机smoke记录16 actors及reload/heal/damage/victory/raycast/cover/fire_interval/rig通过。这些为自动化实机场景验证，不等于任意路线人工游玩通过。

本轮没有完成经过认证的双客户端联网验证，不能用旧health/login检查代替。

## 人物审阅与动态覆盖限制

`full-four-poses-retry/process-result.json` 为退出0、passed=true、capture_filter=[]：完整运行并逐张审阅默认持枪、ADS、换弹中点和换弹结束四姿势。首次 `full-four-poses/process-result.json` 记录中断、退出-15，失败保留，不算通过；重试结果单独记录。四姿势使用当前包Forward+、1280×800。

`other-weapons-third/process-result.json` 为退出0、passed=true，SG/SR换弹中点、第三人称站姿/蹲姿换弹中点全部采集且逐张审阅。上述通过仅指采集执行成功，不是人物画质验收。

- AR默认及换弹中点前臂细长、袖管偏直，右腕与握把衔接僵硬，手套偏圆；ADS视线可用，换弹结束左手恢复护木下方接触，但整体手臂形体仍不自然。
- SG/SR中点同样出现细长直臂与圆鼓手套；袖口、手腕和持弹匣动作缺乏自然转折。单张中点不能验证拔出、转移和插入全过程的接触。
- 第三人称站姿头脸折面明显、肩部方块感强；蹲姿时手臂、枪和膝部轮廓拥挤，需其他视角及连续动作核实穿插，不能仅凭此图断言碰撞错误。

`motion/process-result.json` 记录1200秒超时、退出-15、passed=false；`motion/recovery-audit.json` 核对实际保存29张：AR 23帧（000—132，每6帧采样，采样时间线完整），SG仅6帧（000—030）；SR及所有第三人称动态均无覆盖。该序列采用兼容渲染640×400、关闭阴影并裁去远景，仅作动作诊断，不能代表最终画质。已审阅 `partial-first-arm-contact-sheet.jpg` 与 `partial-sg-contact-sheet.jpg`；AR抬枪阶段仍呈细长直袖的V形轮廓，后段恢复默认接触。`motion/viewer.html` 提供本地局部回放，但本轮未在浏览器播放审阅。静态接触误差和离散采样不能证明连续动作自然，整组动态验证仍失败。

源代码复核：`tools/build_viewmodel.py` 的 `solve_elbow` 与 `client/scripts/first_person.gd` 的 `place_reload_hand` 都在目标超出两段骨骼可达范围时调整肩部位置以保持接触。该机制是下一阶段需要量测的候选原因，尚不能仅凭代码断言其造成全部视觉问题。建议同时记录各武器整段换弹的肩部位移、肘部夹角和腕部旋转，并以实机序列审阅；先修改整条手臂比例、稳定肩部与肘部轨迹，再复核袖口/护木/弹匣接触，不再以局部手指修改代替。

## 当前本地预览

`artifacts/realism460-final-preview/Linux/launch.sh`（相邻IronMeridian及IronMeridian.pck）。导出日志 `artifacts/realism460-validation/export.log`，导出退出0。

PCK SHA256：`069c797201d487fa3ae62d7a15593686b0652bb87f9d59fb7e3c56131b9e3777`。

仍为continue：道路整体效果、人物形体/动作、建筑、地形植被、光照及认证联网验证均未整体验收。未推送、未发布。

# Stage473：维修场入口曲线与填土过渡（当前包复核）

本阶段没有完成整体画质目标。道路/场地过渡作了几何与遮罩一致性修改，随后检查当前包人物手臂；未修改人物资产。全部证据位于 `artifacts/realism473-validation/`。

## 本轮修改

- `client/scripts/world_visuals.gd`：路肩填土横断面从窄边扩展为随曲线变化的宽缓坡，保持通行冠顶高度；道路外缘下沉移到可见渐隐区域外，减少路面先穿入底层造成的硬截断。
- `client/shaders/service_ground.gdshader`：场地底层遮罩使用道路同一组17点曲线路径，替换原来两段直线，并扩大不规则填土范围。并非只调色或增草。
- 保留既有未提交工作；导入、导出日志与本轮输入哈希保存在 `build/`。

## 实机画面判断

同机位宽景前后对照显示弯道接入主路的范围更宽，底层填土跟随实际曲线。入口保持开放，招牌没有重新遮挡通路。但近处三角草地区域仍有清楚的灰绿硬边，右侧填土仍见深色细缝；此次改善不能视为道路全部验收。远山光滑、树冠重复、宽景空旷仍存在。

当前默认持枪与瞄准截图里，支撑前臂仍呈细长直筒，袖口突然膨大，手与护木部分接触被遮挡。准星居中并不证明手臂形体或换弹动作自然。人物下一阶段应针对肩肘变形、前臂体积和袖口/手腕连续性作结构修改，避免仅修手指或机匣。

## 证据与边界

当前本地预览：`artifacts/realism473-preview/Linux/launch.sh`。PCK SHA256：`a9711875d104e3a5bf6362cf2bec39d2b84c67faf0d1dc0a546a6b2ecff869b5`。

`before/` 使用stage472包重新采集三机位；`after/` 使用stage473包，采集进程中断，仅入口和宽景图片落盘，不能称整次采集通过。道路机位独立补采至 `after-road/`。原始进程状态全部保留，不用旧阶段通过记录充当本轮结果。

相机记录（完整精度以environment-camera-poses.json为准；坐标/forward）：

- 道路：相机 `(2,1.65,61)`，朝向 `(-0.0136966,0.0106148,-0.99985)`。
- 建筑入口：相机 `(15.5,1.65,39)`，朝向 `(0,0.0540874,-0.998536)`。
- 宽幅地形：相机 `(17,1.65,50)`，朝向 `(-0.409435,0.0672644,-0.909856)`。

当前包路肩、道路接缝、维修棚通行测试已通过，见 `functional/results.json` 及三个 traversal 日志/JSON。覆盖实际角色跨越接缝和入口路线、相关碰撞检查，不代表整个地图所有建筑验证完成。

网络只读探测：8001健康检查返回协议17/schema0004，8000返回404。未运行本轮多人对战、联机伤害同步或认证流程；健康探测不等于联网功能通过。

第一次动作采集中断，仅两帧，`motion/process-result.json` 明确未通过。补采 `motion-culled/` 使用640×400兼容渲染、关闭阴影、剔除远处细节，仅作为动作诊断，不作为正式画质验收；指定霰弹枪第一人称与狙击枪第三人称两个片段，不覆盖完整九片段动作集。

瞄准测试补跑首次遗漏CAPTURE_ARTIFACT_DIR，发现后终止该测试进程并以正确目录再次运行；保留失败/中断日志，不能将运行器配置错误归为游戏缺陷。

## 本轮已完成的当前包验证

三机位相机记录逐项一致，见 `artifacts/realism473-validation/comparison/camera-comparison.json`。对照图位于同目录的 `road-horizon-comparison.png`、`repair-shelter-entrance-comparison.png`、`terrain-wide-comparison.png`。`after-combined/provenance.json` 记录独立补采与中断采集的图片来源。道路远景显示填土沿弯道接入主路，边界有所缓解，但棕色填土侵入主路右车道的范围偏宽，需要收敛；不能称道路过渡已完全解决。

完整四姿势运行没有使用 `--pose` 过滤：`sleeve-poses/process-result.json` exit0、passed=true，四张PNG均已实际审阅，`SLEEVE_POSE_REVIEW_PASS reload_refilled=true`。默认持枪和ADS仍有细长前臂与偏大袖口；换弹中段可见手指围住离枪弹匣，袖口端面呈突兀圆盘，手腕连续性不足，枪身高光显塑料感；完成帧弹量30/119，支撑手回到护木附近，但接触部分被遮挡。肩部在第一人称画外，不能据此确认肩肘自然。四个离散帧不能证明退匣、插匣、松手及回握全过程自然。下一人物修改应集中肩肘链与袖口体积连续性，避免以手指或机匣微调替代。

`functional/aim-final.log` 有 `AIM_DAMAGE_PASS`（运行退出0），`aim-damage.json` 包含三武器各无遮挡/遮挡的6个样本：无遮挡伤害23/73.2014/78，遮挡0，弹药消耗符合预期。`functional/offline.log` 有 `OFFLINE_SMOKE_PASS actors=16 reload=ok heal=ok damage=ok victory=ok raycast=ok cover=ok fire_interval=ok rig=ok`；补充运行记录中offline退出0。测试范围限本地，未证明多人同步。

## 动作覆盖缺口与下一阶段

补采由本轮主动发送SIGINT结束，保留 `motion-culled/process-result.json` 的 KeyboardInterrupt、exit -15、passed=false；仅霰弹枪第一人称0/6帧，尚未采到狙击枪第三人称。远处细节剔除后首帧仍耗时173秒、次帧15秒；两帧不能确认退匣、插匣、回握或连续动作自然。首帧实际审阅仍可见细长支撑臂和圆盘袖口。两个动作目录均生成明确标注不完整的 `viewer.html`，未将其算作动作测试通过，也未覆盖第三人称肩肘。

下一阶段先修正前臂/袖口体积连续性与肩肘链，再完成完整四姿势及其他武器、近距第三人称动态接触审阅；动作采集需要更有效的诊断场景，保留角色、武器与接触对象并明确其与正常世界渲染的差异。道路主路填土范围和近景三角硬边仍需处理，山体植被、建筑光照与联网功能保留在整体目标中。当前预览可本地运行，整体未完成。汇总：`artifacts/realism473-validation/validation-summary.json`。`git diff --check` 退出0；未提交、推送或发布。

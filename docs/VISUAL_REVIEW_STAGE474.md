# Stage474：主路与维修场地覆盖分离、当前人物动作审阅

当前目标未完成；本轮只推进道路过渡并收集下一次人物结构修改依据。保留全部既有未提交修改，未推送或发布。

## 修改和画面判断

`client/shaders/service_ground.gdshader` 在主路边缘限制维修场地覆盖；`client/scripts/world_visuals.gd` 给扫掠土方边缘及首尾添加顶点渐隐，避免仅埋入外围、却在平地交线上露出硬边。碰撞结构未变。

实机宽景与473同机位对比：原先侵入左侧沥青车道的浅色覆盖已退回路缘，白色边线及沥青重新连续。这是可见改善，但前场斜向灰绿色硬边、局部暗缝依然存在，不能宣称道路过渡全部解决。入口近景仍可见通畅入口、棚内地面和后墙；平滑山体、相似树冠、空旷重复场景仍需结构性推进。

对照基线来自 `artifacts/realism473-validation/after-combined`，是复用的旧包实机截图，不算当前包验证。当前包和源码哈希见 `artifacts/realism474-validation/build/provenance.json`。当前环境初次进程收到 SIGTERM，退出 -15，原因未确定，保留 `after/process-result.json`。道路独立补拍 `road-final/process-result.json` 退出0、passed=true；`after-combined/provenance.json` 明确三张截图各自来源，不把中断进程算作整套通过。

`comparison/camera-comparison.json` 记录三个机位的位置、朝向、分辨率完全一致及截图哈希。已审阅道路、入口、宽景三张对照：道路浅色覆盖退至白色边线以外，入口没有新增遮挡；宽景残留硬边仍明显。图见 `comparison/road-horizon-comparison.png`、`repair-shelter-entrance-comparison.png`、`terrain-wide-comparison.png`。

环境机位（位置 / 前向，1280×800，精确浮点值见相机 JSON）：入口 `(15.5,1.65,39)` / `(0,0.054087,-0.998536)`；宽景 `(17,1.65,50)` / `(-0.409435,0.067264,-0.909856)`；道路 `(2,1.65,61)` / `(-0.013697,0.010615,-0.999850)`。

## 人物与武器

当前正常世界画面的默认持枪、ADS、换弹中段显示：左前臂仍是长直管状，肘腕体积变化不足；袖口像独立圆环，换弹时尤其明显。换弹中段左手持弹匣、右手持握把，但这一帧不能验证插匣全程接触。枪身材质及形体仍较简化。

`sleeve-poses-retry/process-result.json` 完整无过滤四姿势采集退出0、passed=true，耗时568.701秒；四张均已实际审阅。换弹完成帧弹量30/119、左手回到护木附近，但接触面被遮挡，长直前臂和圆环袖口仍突出。日志含 `SLEEVE_POSE_REVIEW_PASS reload_refilled=true`，仅确认采集和补弹，不代表动作自然。首轮 `sleeve-poses/process-result.json` 为中断退出-15，保留失败记录。

`isolated-motion/viewer.html` 包含当前包三种武器 × 第一人称、第三人称站姿、第三人称蹲姿的九条换弹序列，共261帧。已查看三组接触表及第三人称原帧：肩袖块状、手臂轮廓僵直仍突出；第三人称主体在640×400图中偏小，无法据此确认精细肩肘、袖口和护木接触。九条时间线完整且进程退出0，但 `recovery-audit.json` 的 full_suite_passed=false：隐藏环境、低分辨率、关闭阴影的诊断不能替代正常预览验收。

采样模拟60Hz、截图10Hz，只覆盖固定相机下换弹；未覆盖采样间穿插、实际实时播放自然程度、移动/转向/开火与换弹混合、联网同步。不得以静态姿势或261帧数量判断动画自然。

## 当前包功能及预览

导入和导出成功，当前预览：`artifacts/realism474-preview/Linux/launch.sh`，PCK SHA256 `b477984496a68cc31547474ccd9b72c5904f114d4ed0c313fe157fe0008326f4`。

`functional/results.json`：道路肩部、路口、维修棚实际移动/碰撞测试及三种武器开放目标命中、墙体遮挡测试均退出0；首次维修棚测试父进程退出143原因未明，已保留记录并重测通过。单机烟测 `functional/offline-result.json` 退出0，日志含16 actors、reload/heal/damage/victory/raycast/cover/fire_interval/rig通过标记。通行验证限脚本覆盖路线，不代表所有建筑和地图通过。

`functional/network-health.json`：8001 health返回200、protocol17/schema0004；8000返回404。仅健康探测，未验证当前包真实双客户端联网、同步与对战。

## 后续重点

先以当前完整四姿势和九条诊断序列为依据，整体重建前臂到肘部的体积、弯曲轮廓及袖口连续拓扑，并配合肩肘运动与回握轨迹；补正常世界下其他武器和第三人称近景连续动作证据。避免只改手指或机匣。随后处理前场残留硬轮廓与暗缝，再推进山体、树冠差异、场景层次、建筑和光照；仍需当前预览真实联网验证。

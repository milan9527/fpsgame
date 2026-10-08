# Stage442 — 主路裂纹去重复与当前冻结包复核

整体目标未完成。生产修改仅 `client/shaders/road_surface.gdshader`：原来固定周期重复的两层照片采样替换为四米单元随机偏移的四点连续混合；照片世界尺度从 0.37 改为 0.65，使用世界 UV 导数 textureGrad，避免随机偏移边界误选 mip。不是对招牌、草簇或武器零件的微调。肩部过渡与道路补修形状沿用当前实现。本次尚不能声称地形、人物和光照整体改善。

## 冻结输入与预览

- `artifacts/realism442-preview/Linux/launch.sh`，任意工作目录可启动。导入和 export-pack 均退出 0，日志在 `artifacts/realism442-validation/{import,export}.log`。
- 当前 PCK SHA256 `b1d2f57ca895e7c627db021ec90b895bef32a1b3284aecbb69d61b4b41b606b1`；对照441包 `b4e22f2f7b65d9dffefe83f52819cee56442c006f96d23423a141c2f20e16f5d`。
- 环境前后均为1280×800、Forward+、llvmpipe，默认正式地图，无道路诊断覆盖。`environment-before/after/environment-camera-poses.json` 保存采集脚本设置的角色位置、朝向和目标（未记录绘制瞬间 Camera3D.global_transform，不能冒称实际相机变换）；两个目录位于 `artifacts/realism442-validation/`。

## 相机与已观察缺陷

眼高为角色位置加1.6米；下列角度为弧度，原始 JSON 为准。

|机位|角色位置|目标|yaw / pitch|
|---|---|---|---|
|service-approach|17,0.00010254,50|17,3.6,30|0 / 0.1|
|depot-entrance-close|35,0.05,44|35,1.9,34|0 / 0.02499479|
|terrain-wide|17,0.05,50|-46,12,-90|0.42285393 / 0.06731519|
|road-horizon|2,0.05,61|0,3.2,-85|0.01369777 / 0.01061504|

实际查看当前 service-approach 与441同机位：服务场地使用不同材质，变化不明显，不能把它当作主路改进证据。当前入口近景确认卷帘门开口完整，室内可望见出口；场内大面积地面仍空，门框/墙体偏直硬，照明均匀。当前 default-spawn 可见大块分叉裂纹减少，但纵向接缝显眼。前臂仍细长、袖管轮廓锥形，山体尖滑，树冠重复。当前主路同机位与宽幅地形最终审阅见下方采集收尾记录。

## 功能与动作证据边界

当前冻结包道路路肩通行、仓库双向入口与侧墙碰撞、三武器六组瞄准伤害/遮挡均退出0通过。原始日志、详细JSON与 `functional-results.json` 在 validation 目录。它们验证本地权威逻辑，不代表真实联网。

四姿势任务未指定 --pose，要求 default-spawn、ads、reload-middle、reload-complete 全部生成并审阅；目录 `artifacts/realism442-poses/`。静态四姿势不证明连续动作自然。

九组动作任务在两张采样图后中断（KeyboardInterrupt，exit -15），`artifacts/realism442-motion/process-result.json` passed=false。它使用兼容渲染、关闭阴影、剔除远景，只能作为运动诊断；当前其他两种武器和第三人称完整动作仍未覆盖，肩肘、袖口、护木与换弹接触未获完整实机验证。439九组动作、440四姿势虽随后完成，属于旧包，只作缺陷参考，不能算442通过。

联网夹具 `tools/test_foregrip_network.py` 会读取 SERVER_SECRET 并启动服务，与本轮禁止读密钥/修改服务的约束不兼容，未执行；不是认证失败，亦未伪造联网结果。

## 下一结构性阶段

四姿势已收尾；下一轮补齐并审阅本包其他武器/第三人称完整换弹，再围绕长锥形前臂重做肘部体积、袖料垂坠和袖口连接；同时保留山体坡面层次、树冠差异、建筑内部/场地使用痕迹和光照的完整目标。不得以本次路面去重复或截图数量宣称完成。

## 环境采集收尾

已逐张查看442主路、入口、服务场地、宽幅地形以及441主路/服务场地对照。主路大分叉裂纹的周期重复明显减弱，近处纵向裂缝仍偏平行；路肩到场地仍有较宽的灰褐带，本次没有改造服务场地独立材质。宽幅地形暴露山体尖锥轮廓、坡面光滑及树冠重复，建筑内部空旷、光照层次不足，均保留为未解决项。

四组原尺寸上下对照位于 `artifacts/realism442-validation/*-comparison.jpg`。前版环境进程退出0且通过；当前版四张全部生成，日志有 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=4`，但监督进程丢失，无法恢复真实退出码，`process-result.json` 记录 supervisor_lost、passed=false，不把日志标记替代已确认的进程退出。前后脚本输入机位相同；未来应补录绘制瞬间相机世界变换，尤其宽幅地形目标与实际画面中心需核对。

完整单机 smoke 包装进程中断（143），游戏日志没有通过标记，未完成；道路与仓库单机通行仍有独立通过证据。当前动作 viewer.html 仅包含2张第一种武器样本，不能证明完整换弹或其他武器/第三人称通过。

## 当前四姿势审阅（完整采集已通过）

- default-spawn：支撑手位于护木下方，长锥形袖管和偏细腕部仍明显，局部布褶没有解决整体形体。
- ads：红点视线无遮挡，支撑手贴近护木；静帧未见明显遮瞄，但不代表移动/开火状态全部通过。
- reload-middle：持弹匣左手与弹匣接触，右手在握把处；两段长袖管及肘部环带明显，袖料从肘到腕缺少可信体积分布。取匣、插匣、回握以及肩肘连续轨迹仍未覆盖。
- reload-complete：弹药显示30/119，支撑手回到护木下方，静帧未见明显脱离；前臂依旧长锥形、腕部偏细，不能据此判断连续回握轨迹自然。

四张已逐张审阅，未使用 --pose 筛选；process-result.json 确认 exited、exit_code=0、passed=true，759.771秒，输入PCK与本轮冻结包一致。日志有 SLEEVE_POSE_REVIEW_PASS reload_refilled=true；four-poses-contact-sheet.jpg 供对照，原图保留1280×800。仅代表当前卡宾枪四个静态时点，不代表三武器或第三人称连续动作通过。

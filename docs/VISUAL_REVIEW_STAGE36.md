# Stage36：橡胶肩垫与实体门槛过渡

本轮依据 stage31 第一人称优先反馈和 stage35 近景问题，重建 AR/SG/SR 肩垫。48点截面、四圈收边替代矩形板，加入11道防滑肋与高粗糙度深色橡胶。保留相机、手臂和动作参数。本轮没有完成手臂形体及换弹接触整改。

## 实机观察

运行导出的 PCK 与本机 Godot 4.4.1 程序，从项目目录外、隔离用户目录采集。固定角色位置 `(17, .05, 50)`、相同朝向；同机位比较腰射与ADS（ADS自身缩放保留），另记录换弹三个时刻。Forward+ 使用 llvmpipe。

AR 换弹中段与 stage35 对照 `artifacts/realism36-comparison/ar-reload-before-after.jpg`：上一轮浅灰矩形肩垫已变为圆角深色橡胶，边缘厚度和横向防滑纹可辨。枪托主体仍方硬，肩垫后盖仍是平面，不能称为复杂曲面写实模型。左手仍在枪体外悬空，手指短粗；本轮没有解决取送弹匣接触。

三武器15张截图均成功采集并实看：`artifacts/realism36-preview/capture/`。汇总为 `artifacts/realism36-comparison/all-hip-ads.jpg` 和 `all-reload.jpg`。SG/SR换弹也能辨认圆角及防滑肋；腰射与ADS未见新增肩垫遮挡瞄准。SR ADS仍像空镜圈，缺少分划与镜片光学表现；大面积枪托平面、重复仓库和均匀草簇依然明显。三次采集各退出0，日志 `capture-0.log` 至 `capture-2.log`。

## 碰撞修复与验证范围

`client/scripts/world.gd` 在仓库两端加入有渲染表面和凸形碰撞的实体混凝土斜坡，衔接20厘米地板；没有删除或禁用地板碰撞。

源项目和包内真实 Actor 穿行均通过，检查仓库 `(35,34)` 两个方向，结果 `disabled_floors=0`、`floor_control=false`。角色从 z=44 穿至24.97425，从 z=24 穿至43.02611。证据：`artifacts/realism36-validation/traversal.json` 与 `packaged-traversal/traversal.json`。此测试覆盖代表仓库的双向中心通道，不代表所有边缘角度均已穷举。

源项目瞄准108样本、三武器外观/挂点/远端快照、枪口遮挡规则通过，日志位于 `artifacts/realism36-validation/`。远端快照不是实际联网验证；此前真实联网登录HTTP404尚未解决，本轮未重测。未重复 stage29 验证。

最终包在项目外、隔离用户数据目录的单机烟测退出0：`packaged-smoke.log` 中 `OFFLINE_SMOKE_PASS actors=16 reload=ok heal=ok damage=ok victory=ok raycast=ok cover=ok fire_interval=ok rig=ok`。本地运行入口为 `artifacts/realism36-preview/Linux/IronMeridian`，同目录PCK必须保留。

导入和 PCK 导出退出0；导入仍出现三条 dummy renderer `texture_2d_get: Parameter "t" is null`，未宣称零错误。沿用本机可执行文件加PCK的预览方式，未重新尝试缺失模板的官方release导出。

## 后续

整体目标未完成。下一轮优先第一人称手指长度/厚度与左手取送弹匣接触，继续同机位腰射/ADS审阅；随后改善SR镜内表现、人物蒙皮、重复仓库布局、植被与地形材质边界，并恢复真实联网主要流程验证。软件渲染截图不能证明实体GPU性能。未推送或外部发布。

# Stage504：场地贴地网格实验与当前包复核

本轮道路修复**尚未达到明显改善的要求**，整体目标继续。当前本地实验预览：`artifacts/realism504-preview/Linux/launch.sh`。PCK SHA256：`036759c2401eeb519ee91edab8229baa2bd8dd26a4f70f2eb54bd6ef0088365a`。

## 修改与视觉结论

`client/scripts/world_visuals.gd` 将 service_yard 的平面覆盖层改为顺应开挖地形的网格；`client/shaders/service_yard.gdshader` 使用场地中心恢复局部坐标，给非停车连接道增加收窄、弯曲的边缘及双车辙。意图消除跨越排水地形的平板和矩形连接口。

503 前图与504后图均重新从冻结预览采集，三机位通过，已逐图审阅：

- `artifacts/realism504-validation/comparison/road-horizon-comparison.png`
- `artifacts/realism504-validation/comparison/repair-shelter-entrance-comparison.png`
- `artifacts/realism504-validation/comparison/terrain-wide-comparison.png`

三组差异很小，不能据此认定道路横向硬矩形色差已经解决。入口开放、纵深可见，但砌块墙脚、规则框架和大面积平滑铺地仍明显。宽幅机位中的山体缺乏细节，树冠重复、地表材质拉伸仍在。当前环境图可见支撑前臂长薄、腕部与护木握持不自然；这些仅为静态观察，不证明动作质量。

下一次道路修改前应对可见色带做单变量诊断（交叉道路、阴影、路面凹凸及覆盖层），锁定实际贡献者；不能再把改变不明显的连接道或颜色微调当作验收。

## 相机与复现

1280×800，Forward+；完整记录在 `before/environment-camera-poses.json`、`after/environment-camera-poses.json`，对照校验在 `comparison/camera-comparison.json`（路径均相对 `artifacts/realism504-validation`）。

|机位|眼睛位置|目标位置|yaw / pitch（弧度）|
|---|---|---|---|
|road-horizon|(2,1.65,61)|(0,3.2,-85)|0.01369777 / 0.01061504|
|repair-shelter-entrance|(15.5,1.65,39)|(15.5,2.3,27)|0 / 0.05411378|
|terrain-wide|(17,1.65,50)|(-46,12,-90)|0.42285393 / 0.06731519|

## 当前版本验证与未覆盖项

导出成功，日志 `artifacts/realism504-validation/export.log`。当前504包瞄准/遮挡6项、建筑入口32项、道路24条路线及单机冒烟退出0；证据 `functions/results.json` 和同目录 JSON、日志。单机冒烟覆盖换弹、治疗、伤害、胜利、射线、掩体、射速及骨架规则，不等于动作自然。

完整四姿势采集未用单个 pose 代替，但初次及重试均被 SIGTERM 中断；SG/SR及第三人称站蹲采集同样中断，无截图。分别保留 `sleeve/process-result.json`、`sleeve-retry/process-result.json`、`contact/process-result.json` 的失败状态。中断来源未确定，不能推断为资源不足或超时。结束核查未发现这些采集进程仍存活。本轮人物四姿势、其他武器及第三人称动作均**未通过**，不沿用503结果。

尚需完成肩肘、袖口、护木、换弹接触及连续动作审阅。当前联网只做端点探测：8001协议接口可达，8000返回404；不是双客户端功能测试，也不是全局联网阻塞。山体植被、建筑、光照和联网目标保留，未推送或发布。

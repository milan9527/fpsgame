# Stage93 — 手部截面、袖口与织物尺度

本轮承接 stage92，按 stage31 的第一人称优先反馈修改手臂资产；未重复 stage29 验证。整体写实目标未完成。

## 实际修改

- `tools/build_viewmodel.py` 收紧袖口及配套闭合片，缩小支撑手虎口体积，压薄掌背和指截面，保留抓握接触侧。
- 重网格化后的手套 UV 按各岛实际表面积统一到 0.12 m 纹理重复尺度，避免自动排布使不同部位纤维尺度悬殊。该算法统一面积尺度，不保证消除岛内拉伸或接缝。
- 重建 `art/first_person.blend`、`client/assets/first_person.glb`。本轮未重制枪械、人物或环境资产；工作区包含前轮未提交修改，不能把累计 diff 全算作本轮成果。

## 实图判断

源码及预览包均使用固定位置/朝向拍摄三武器各五姿态：腰射、ADS、换弹四分之一/二分之一/四分之三；ADS 保留游戏自身 FOV 变化。原图 1280×800，Forward+，Xvfb + llvmpipe 软件 Vulkan。

- `../artifacts/realism93-validation/stage92-93-hip-detail.png` 对照显示袖口收紧、掌面减薄，但幅度有限，不构成第一人称写实完成。
- AR 腰射与 ADS 中手套未明显脱离袖口，中心红点可见；拇指仍像细长管，缺少可信的指节与虎口转折。
- 霰弹枪腰射/ADS 的袖子仍像带鼓包的管道，枪身大平面和材质层次不足；精确射手步枪 ADS 十字线可见，但镜体与镜片依然偏简化。
- AR 换弹半程中支撑手随弹匣下移，静帧未见明显网格孔洞；静态接触检查及五姿态截图不能证明整段动画完全无穿模。
- 仓库体块重复、地表平且斑驳、草丛排布规律，远景树木重复感明显。人物、建筑、地形植被、光照均尚未整体验收。

## 验证边界与证据

构建日志：`../artifacts/realism93-validation/blender-build.log`；导入日志：`../artifacts/realism93-validation/import.log`。Blender 输出掌面法线、UV 尺度、连续手套及骨骼动画检查 PASS。Godot 导入虽退出 0，仍有 `Parameter "t" is null`，不能称为无错误导入。

自动检查、截图采集结果及构建哈希分别见：

- `../artifacts/realism93-validation/test-results.json`
- `../artifacts/realism93-validation/verification.json`
- `../artifacts/realism93-validation/screenshot-index.json`
- `../artifacts/realism93-preview/build.json`

检查覆盖手套材质/UV、三武器瞄准、换弹接触、武器遮挡、视图模型、枪械规则、离线启动、入口与屋顶碰撞、网络状态规则。网络状态规则不等于真实多人会话；本轮未读取认证密钥、未建立真实多人连接。入口/屋顶检查也不等于全地图碰撞验收。软件渲染不代表硬件性能。

源码与预览包各 10 项自动检查已通过：每套瞄准检查 108 个样本、换弹接触 183 个样本、入口 32 处/96 次射线及屋顶 8 处。验证驱动曾退出 143，原因未明；保留已确认的成功结果，以 `--resume` 完成后续检查，中断记录见 `../artifacts/realism93-validation/interruption.json`。没有把中断时尚未确认退出状态的日志当作成功。

两套截图采集均成功退出，共 30 张原图已核对尺寸并记录 SHA256。已审阅[源码总览](../artifacts/realism93-validation/source-forward-contact.jpg)和[预览包总览](../artifacts/realism93-validation/packaged-forward-contact.jpg)，包内三武器五姿态与源码表现一致；截图不能替代连续动画和真实联网验收。

## 本地运行与下一步

在有桌面与 Vulkan 驱动的项目根目录运行：

```bash
./artifacts/realism93-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

可执行文件与同目录 PCK 配套；这是本地预览，不是标准导出模板发行包。说明见 `../artifacts/realism93-preview/README.md`。未 push 或发布。

下一轮优先重塑拇指指节、虎口转折与抓握轮廓，配合同机位近景检验，避免只继续调细微尺寸；随后改善枪身大平面与材质分区。继续修复导入 null 错误、人物与重复环境，并以无需读取密钥的测试配置补真实联网验证。

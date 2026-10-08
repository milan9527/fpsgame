# Stage436：山体断层结构与当前包完整四姿势复验

整体目标未完成。当前本地预览：`artifacts/realism436-preview/Linux/launch.sh`。
对照入口：`artifacts/realism436-validation/review.html`；完整性与来源：`evidence-audit.json`、`build-manifest.json`（均位于该 validation 目录）。

## 修改与实机判断

`client/scripts/world_visuals.gd` 的 ridge_height 增加沿倾斜断层分布、沿走向断续的两级岩肩，改变实际山体网格与法线。不是道路色值或草簇调整。本轮先用435预览重拍道路/场地，确认已有过渡修复在当前基线仍有效，再处理明显的光滑山体。

435/436 的 service-approach、depot-entrance-close、terrain-wide、road-horizon 四组1280×800 Forward+实机图均已逐张审阅；相机JSON完全相同。路面及场地边界未见此前全宽横向硬矩形色差，仍有重复裂纹、宽大空场和碎石纹理平铺感。入口通道及另一端门洞可见，柱体材质噪声偏强，墙面、顶棚仍有方盒感。

新山脊轮廓和斜向坡面变化明显，road-horizon 尤其容易比较；但局部尖峰偏密，远山依然蓝灰光滑，不能把轮廓变尖等同于写实岩壁完成。宽幅图树冠轮廓重复、山体材质层次及光照不足继续保留。

## 固定机位

下表位置为角色坐标；相机眼高加1.6m，朝向单位弧度。原始精度及目标点保存在两侧 `environment-camera-poses.json`。

|机位|角色位置 xyz|yaw|pitch|
|---|---|---|---|
|service-approach|17, 0.00010254, 50|0|0.1|
|depot-entrance-close|35, 0.05, 44|0|0.02499479|
|terrain-wide|17, 0.05, 50|0.42285393|0.06731519|
|road-horizon|2, 0.05, 61|0.01369777|0.01061504|

## 人物与手臂

当前436包运行完整四姿势，未传单个 `--pose`：default-spawn、ads、reload-middle、reload-complete，退出0，733.595秒。四张PNG及 `poses/sleeve-pose-review.json`、`poses/process-result.json` 已保存并审阅。相机位置约(0,1.60036445,90)，yaw/pitch为0。

默认与换弹结束的支撑臂仍呈长锥形，手套偏厚，袖口到腕部比例欠自然。ADS中心准星可见，但枪体遮挡了部分手部接触。换弹中段弹匣分离、左手持匣，右手握把；双前臂形体和腕部衔接仍生硬。结束时恢复持枪、弹药30/119。护木接触未见足以确认的明显悬空，但这些角度不能排除穿插。肩部与完整肘部不在画面内，不能据此判断肩肘自然。

这些是模拟状态截图，未覆盖连续拔匣、插匣、复位接触、移动换弹、打断切枪；当前包其他武器和第三人称动态尚未补拍。435的动作证据不计为436通过。下一阶段应结构性修改前臂轮廓、肩肘和第三人称身体配合，补充侧面近景及完整动作过程，避免继续袖口或手指微调。

## 当前版本验证及异常

- 导入、导出退出0，源码与预览哈希复核一致。PCK SHA256：`534c1dced39954bc3ff49c5dbeddecb4446ddb4a6fb59084ef7f29ffb6c8501c`。
- 建筑双向通行：4条路线及2处护栏碰撞通过；道路边缘5处地面探测及跨坡通行通过。见 `functional-results.json`、`depot_traversal_review.log`、`road_verge_traversal_review.log` 和对应JSON。
- 瞄准：三武器108样本、倾身/后坐力/射线检查通过，游戏退出0；外层驱动随后退出143。分别记录于 `aim-result.json`、`aim-alignment.log`，不将驱动异常抹除。
- 环境基线驱动退出0；修改后驱动退出143，游戏子进程继续写完四张图及 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=4` 后退出观察列表，游戏退出码未收集。`environment-after/process-result.json` 保持 passed=false；独立审计仅确认四图可解码、机位一致及日志完成标记。误启动的重复补拍已取消并保留记录。
- 地形规则测试被中断，只有启动日志，未通过；详见 `interrupted-tests.json`。没有证据支持将终止归因于认证或内存。
- 本轮未复验真实联网及完整伤害/换弹功能集。截图使用软件渲染，不能证明交互帧率达标。

继续保留建筑空间、地形植被、光照、人物动作、武器接触、单机和联网完整目标。未推送或发布，保留已有未提交修改。

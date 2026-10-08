# Stage443：服务道路边缘与当前人物接触检查

整体目标未完成。当前预览为 `artifacts/realism443-preview/Linux/launch.sh`，PCK SHA256 为 `a3fe0a1aa149d16da9907db11d518e52049f414a76cd8f8123840c5731840913`。保留原有未提交修改。

## 实际环境修改与观察

`service_access.gdshader` 沿服务道路中心线控制宽度：入口较窄，往主路逐渐展开，并对一侧边缘作收束；轮迹改成沿道路分布的断续磨损，减弱贯穿弯道的深色圆弧。修改材质覆盖轮廓，没有添加碰撞体。

`artifacts/realism443-validation/service-road-before-after.jpg` 对比442和443实际游戏截图。连续深色车辙显著减弱，入口收束有所改善；浅灰色铺装弯道仍很显眼，建筑地坪横向直线边界仍生硬，不能宣称道路/场地过渡全部解决。入口近景中门洞与室内通道清晰，但墙面、顶棚和地坪层次不足。背景山体光滑尖锐、树冠重复仍未解决。

环境采样脚本新增绘制前 Camera3D 世界位置与前向量记录。三个固定机位为：

| 机位 | 相机位置 | 前向量 |
| --- | --- | --- |
| service-approach | (17, 1.60010, 50) | (0, 0.09983, -0.99500) |
| depot-entrance-close | (35, 1.65000, 44) | (0, 0.02499, -0.99969) |
| terrain-wide | (17, 1.65000, 50) | (-0.40944, 0.06726, -0.90986) |

原图、精确机位及进程记录位于 `environment-before/`、`environment-after/`，基目录均为 `artifacts/realism443-validation/`。两次进程均退出0，三图齐全；`camera-comparison.json` 确认包括实际相机位置和前向量在内的全部记录字段一致。入口及宽幅对照分别为 `depot-entrance-close-comparison.jpg`、`terrain-wide-comparison.jpg`。

## 当前版本功能证据

- `service-and-offline/service-entry-process.json`：退出0；新增维修棚双向入口路线，加仓库/雨棚入口共六次步行与两个侧墙射线检查。详细位置见同目录 `depot-traversal.json`。
- `service-and-offline/offline-process.json`：退出0；`offline.log` 包含 OFFLINE_SMOKE_PASS，覆盖16角色、换弹、治疗、伤害、胜利、射线、掩体、射击间隔和角色骨架检查。
- `functions/road_verge_traversal_review-process.json` 与 `functions/aim_damage_review-process.json`：均退出0；路肩通行和三武器直接/遮挡伤害检查通过，详细数值见同目录JSON。
- 排除 `functions/depot_traversal_review-process.json`：首次运行开始后脚本增加路线，结束才计算脚本哈希，不能证明新增路线已执行。上面的独立复跑在启动前固定哈希，提供有效证据。
- 真实联网本轮未执行；现有夹具会读取 SERVER_SECRET 并启动服务，不在本轮执行范围。单机与静态规则不能替代联网动作、同步和命中验证。

## 人物证据范围与下一步

首轮四姿势和连续动作采样中断，保留 `poses/`、`motion/` 中记录，不计通过。`motion/partial-contact-sheet.jpg` 仅显示第一武器前1.6秒内部分换弹：前臂细长、肘部环带、手套体积偏大；不覆盖换弹结束、其他武器或第三人称。

完整四姿势已无筛选复跑，`poses-retry/process-result.json` 退出0、passed=true，正式 Forward+ 的 default-spawn、ads、reload-middle、reload-complete 四张原图均已逐张审阅。瞄具视线没有明显手臂遮挡；换弹中段可见左手持弹匣和右手握枪，结束支撑手回到护木，弹量由29/120变为30/119。前臂细长锥形、手套鼓胀和肘部亮色接缝仍明显。四张静帧不证明弹匣插入全过程接触正确或动作连续自然；汇总图为 `poses-retry/four-poses-contact-sheet.jpg`。

新增 `tests/weapon_motion_keyframe_review.gd`，为三武器第一人称、第三人称站姿及蹲姿共九次换弹各采样五个时点。当前包进程退出0，45张图及九组换弹结束/弹量断言通过，见 `keyframes/process-result.json`、`keyframes/keyframe-review.json`。它使用60Hz推进和兼容渲染，关闭阴影及剔除远处细节，只用于检查接触。采样完整不能证明中间时点无穿插、连续动作自然、移动换弹正常或正式光照达标。

已审阅 `keyframes/first-contact-sheet.jpg`、`third-stand-contact-sheet.jpg`、`third-crouch-contact-sheet.jpg` 及第一/第三人称中段原图。三武器左手在中段离开支撑位，结束回到护木附近；第一人称前臂过长且单调收锥、手套偏鼓、肘部亮环突兀。第三人称站/蹲姿肩臂仍有棱块感，侧前方机位能看到手臂变化，但人物画面占比不足以确认弹匣接触和袖口穿插。不能据此判定换弹接触全部合格。

下一结构阶段优先重塑整段前臂和肘部截面、过渡曲率及袖口连接，并复核蒙皮与法线，避免继续只调机匣、手指或材质颜色。修改后重跑完整四姿势，补第三人称近景及连续换弹/移动换弹，核对肩肘、护木、弹匣接触。保留建筑内部与入口材质、山体形状和表面、树冠轮廓与分布、场地过渡、光照及真实联网的完整待办。

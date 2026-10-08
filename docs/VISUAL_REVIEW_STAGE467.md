# Stage467 当前包审阅（2026-09-19）

状态：本轮采集与审阅结束，continue；整体目标未完成。道路修改尚未达到明显改善的验收标准。

## 道路／场地修改与实机结论

`client/shaders/road_surface.gdshader` 调整道路摄影骨料尺度、按屏幕覆盖率衰减近景法线，加入破损路缘及露出基层的混合。修改前源码保存在 `artifacts/realism467-validation/source-before/road_surface.gdshader`。

用 stage466 包重新采集 before，再以 stage467 包采集 after，均为 Forward+ 1280×800 实机截图。三组同机位对照逐张审阅，路缘略软、近景颗粒略弱，但道路整体仍像亮碎石；本轮尝试未达到用户要求的明显道路／场地提升，不将材质局部变化当作环境验收。没有重现早期整条横向深色矩形，不代表道路已真实。

入口近景的招牌和通道可辨，入口与场地仍可进入；宽幅图暴露大片平滑场地、重复树冠、光滑且轮廓折线明显的远山。第一人称前臂仍呈长管状。建筑与光照也不能因本轮碰撞通过而视为画质通过。

证据目录：`artifacts/realism467-validation/comparison/`，包括 `road-horizon-comparison.png`、`repair-shelter-entrance-comparison.png`、`terrain-wide-comparison.png` 与 `camera-comparison.json`。原图在同级 `before/`、`after/`。before 435.932 秒、after 394.911 秒正常退出。

| 机位 | 位置 XYZ（米，取近似） | yaw / pitch（弧度） |
| --- | --- | --- |
| 道路正向 | 2, 1.65, 61 | 0.013698 / 0.010615 |
| 建筑入口 | 15.5, 1.65, 39 | 0 / 0.054114 |
| 宽幅地形 | 17, 1.65, 50 | 0.422854 / 0.067315 |

完整朝向向量与数值见 `before/environment-camera-poses.json`、`after/environment-camera-poses.json`。

## 当前包功能与预览

`artifacts/realism467-validation/functional-results.json` 记录同包重新执行的五项检查，均退出 0 且出现对应 PASS 标志：起伏道路通行、路肩通行碰撞、建筑入口通行、瞄准伤害、单机冒烟。日志与原始结果在 `functions-verified/`。这些是脚本检查，不证明所有实时输入流程和联网玩法已覆盖。

`online-availability.json` 记录当前本地 `/protocol` 和 `/auth/login` 都返回 HTTP 404。联网主要功能及双客户端未验证；未修改后台或认证服务。

本地运行：`artifacts/realism467-preview/Linux/launch.sh`。PCK SHA256：`b811d311f08d787167b6b590d0963d7a8ca58ceddd4828a554238c1af5279671`。完整文件指纹见 `artifacts/realism467-preview/preview-manifest.json`。未推送、未发布。

## 人物动作审阅

完整四姿势本轮无 `--pose` 过滤运行，546.846 秒退出 0，`SLEEVE_POSE_REVIEW_PASS reload_refilled=true`；`full-four-poses/` 中 default-spawn、ads、reload-middle、reload-complete 均已逐张审阅。默认与回位图的左前臂仍像长直袖管，袖口到手腕缺少自然形体过渡；ADS 红点视线可用，但护木遮挡左手，不能据此证明接触自然。换弹中段左手持物与弹匣井分离，静态图不足以确认插入过程；结束图弹量为 30/119 且回到持枪姿势。四姿势通过只证明采集及装弹规则，不证明连续动作自然。

SR 第一人称／第三人称站姿两段采集退出 0，每段保存 frame 000—192、间隔 6 帧的 33 张截图，已审阅两张完整联系表及关键原图。第一人称可见举枪倾斜、左手靠近弹匣区域、下移离开画面、返回持枪的过程；前臂长管形、袖口硬且厚重的问题仍明显。后段左手在回位，不能把单帧间隙直接判为接触失败；枪身遮挡仍使实际插入与护木接触不能完整确认。

第三人称可见枪口下倾再回平，双脚基本不动，双臂集中在胸前／弹匣区域。肩肘形体仍像粗圆段，服装及装备块状感明显；当前角度远侧手被枪和躯干遮挡，没有充分展示完整弹匣拔出、插入路径。可见帧未发现明确断肢，但不能据此宣称肩肘、袖口和换弹接触已经自然。

证据在 `sr-motion/viewer.html`、`first-weapon-2-contact-sheet.jpg`、`third-stand-weapon-2-contact-sheet.jpg` 及对应原始 PNG；`motion-review.json` 保存相机及采样状态，`recovery-audit.json` 确认两段文件完整与进程正常退出，明确 `full_suite_passed=false`。这是 60Hz 固定步长下每 6 帧采样，使用 640×400 Compatibility 诊断配置、关闭阴影并裁掉远处细节，不能替代正常画质或实时流畅度验证。本轮没有覆盖 AR／SG 连续动作、移动冲刺、贴墙、投掷、治疗、连续瞄准输入及联网动作；四姿势和这两段采样都不代表全套动作验收。

## 后续

先重做道路沥青胶结表层与松散路肩的材质分层，并联动入口场地过渡；当前缩小颗粒与法线衰减不足，需隔离检查摄影贴图的亮骨料贡献，不能只继续调色或加草。随后依据当前完整人物证据推进肩肘、肌腹、袖口及换弹接触的结构修改。保留山体结构、树冠差异、建筑、光照、连续输入动作与联网验证目标。

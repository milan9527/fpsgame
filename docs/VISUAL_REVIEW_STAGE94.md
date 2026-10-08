# Stage94 — 拇指指节与抓握截面

承接 stage93，继续处理 stage31 第一人称反馈，未重复 stage29 验证。整体写实目标仍未完成。

## 本轮修改

`tools/build_viewmodel.py` 将支撑拇指中心线改成六个控制点，区分近节和远节的走向；收窄中段、压平指腹，并增加指间关节的背侧隆起。右手拇指补上原先遗漏的 `thumb=True`，使其使用拇指专用截面。重建 `art/first_person.blend` 和 `client/assets/first_person.glb`。

本轮没有重制枪械材质、袖子、人物或环境。工作区累计修改属于多轮成果，不能把整个 diff 算作本轮新增。细小关节形体经重网格化和平滑后可能减弱，必须以游戏截图为准。

## 取证方式

源码与包内使用同一截图脚本、固定角色位置和朝向，拍摄三武器的腰射、ADS及三个换弹姿态；ADS保留游戏自身FOV变化。Forward+，Xvfb + llvmpipe 软件Vulkan，原图1280×800。`stage93-94-hand-comparison.png` 使用两轮AR腰射/ADS的相同原像素裁切，无放大或形变。

Godot导入退出0，仍在保存导入场景时报告 `Parameter "t" is null`，调用位置为 `servers/rendering/dummy/storage/texture_storage.h:107`；本轮未修复，不称为无错误导入。

## 同机位审阅结论

已对照 stage93/94 的 AR 腰射和 ADS 原像素裁切：拇指中段稍收窄，但轮廓仍是一段连续弯管，指间转折不够明确。ADS 左侧手指同样保留软管感；这不是显著的写实改善。当前方案依赖细小截面变化，下一轮应改成明确的近节/远节体块和指腹接触面，并在重建后先审阅腰射与 ADS，再决定是否扩大验证。

枪身大面积深灰面缺少可信的材质分区，袖子仍呈平滑长管，地面植被重复且建筑表面平板。本轮没有解决这些主要问题。不能依据功能检查通过宣布画质通过。

AR 换弹半程原图中，支撑拇指绕在弹匣边仍显环状，掌面偏厚；右手握把附近指节也不够清楚。这说明应优先修正抓握形体及接触面，而不是继续只增加织物微纹理。

## 验证边界

网络状态规则不能替代真实多人连接；入口与屋顶检查不能替代全地图碰撞；五个静态姿态不能证明整段动画无穿模；软件渲染不能代表真实显卡性能。本地预览由Godot可执行文件和同目录PCK组成，不是标准导出模板发行包，未向外部发布。

## 最终证据

源码与预览包各10项功能检查通过：手套表面、瞄准、换弹接触、武器遮挡、第一人称规则、武器外观规则、单机、入口碰撞、屋顶碰撞和网络状态规则。连同导出与两次截图采集，验证驱动记录23项成功操作，正常退出0。源码与包内各15张截图，共30张，均为1280×800。已审阅两张全姿态总览，三武器中央瞄准区可见；包内画面同样保留上述抓握、袖子和环境问题。

- 验证目录：`artifacts/realism94-validation/`，包含 `verification.json`、`test-results.json`、`screenshot-index.json`、各项原始日志、`source-forward-contact.jpg`、`packaged-forward-contact.jpg` 和 `stage93-94-hand-comparison.png`。
- 本地预览：`./artifacts/realism94-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`，保留同目录PCK；预览目录的 `README.md` 和 `build.json` 记录运行说明与构建哈希。
- 下一轮应先以明确的指节体块和指腹接触面替换连续管状抓握结构，快速截取同机位腰射/ADS确认可见改善后再扩大验证。本轮不能作为第一人称写实目标完成的证据。

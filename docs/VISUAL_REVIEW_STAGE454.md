# Stage454：道路与维修场地过渡修复，人物缺陷复核

本阶段整体目标仍未完成。当前可运行包：`artifacts/realism454-final-preview/Linux/launch.sh`。
PCK SHA256：`c73a8010dbb4de1915800b673530befb77f40cdfe4623cbe93b1846ab0eab901`。
以下功能结论来自此包；较早的 `realism454-preview`、`after`、`functions-final` 及中断截图不能替代最终包验证。

## 实际修改和同机位审阅

`client/scripts/world_visuals.gd` 与 `client/shaders/service_ground.gdshader`：
维修场地和道路连接土肩改用共享世界坐标岩土材质，实体土肩保持不透明；调整土肩横断面、道路接头高度和两端渐隐埋地，保留连续三角网碰撞。不是仅改招牌、草簇或色值。
首次接头高度测试失败后，修正了接头几何高度，未降低断言标准；最终道路边缘测试通过。

证据根目录 `artifacts/realism454-validation/`：

- `repair-shelter-entrance-comparison.jpg`：建筑入口近景，左侧凸起黄边弱化，灰褐色连接面与维修场地更连续。
- `terrain-wide-comparison.jpg`：宽幅地形，前景醒目的金黄色土肩边界明显减弱。
- `road-horizon-comparison.jpg`：道路纵深与场地连接。道路本体未重做。
- `comparison-audit.json`：stage453 `after-final` 对 stage454 `after-final`，相机元数据一致，记录截图哈希；已实际查看三张对照。

1280×800，相机位置/朝向如下；精确浮点和 forward 向量见 `after-final/environment-camera-poses.json`。

|机位|相机位置|yaw / pitch（弧度）|
|---|---|---|
|repair-shelter-entrance|(15.5, 1.65, 39)|0 / 0.05411378225|
|terrain-wide|(17, 1.65, 50)|0.42285392613 / 0.06731519497|
|road-horizon|(2, 1.65, 61)|0.01369777337 / 0.01061504385|

三张最终环境 PNG 和 `ENVIRONMENT_REVIEW_CAPTURE_PASS frames=3` 均存在，但包装进程未保存终态，退出码未知。`after-final/recovery-audit.json` 明确区分完整截图证据与未验证进程退出，不把原始 running 状态改写为通过。

这些机位没有重现此前描述的道路横向硬矩形，不能据此宣称全场景已消除。远景道路仍空旷；山体光滑、山脊尖锐、树冠重复，前景部分纹理拉伸和规则线纹仍明显。建筑、地形植被和光照目标保留。

## 当前包功能验证

`functions-verified/` 中四个 `*-process.json` 均为退出码 0、passed=true，并绑定上述最终 PCK：

- `shoulder-process.json` / `shoulder-traversal.json`：4 个支撑高度/法线检查和 8 次角色越肩通行。
- `building-process.json` / `depot-traversal.json`：8 次前门、2 次雨棚、2 次维修入口、2 次墙体阻挡、2 次仓库检查。
- `aim-process.json` / `aim-damage.json`：三种武器共 6 项空旷命中/墙体阻挡检查。
- `offline-process.json`：当前导出包单机 smoke。

联网未通过：`online-test.log` 中 `/auth/login` 返回 HTTP 404，双客户端未启动验证。未修改后台服务或认证，也未引用历史联网通过结果。

## 人物、手臂和连续动作

未在本阶段修改人物模型。先审阅当前包，避免连续进行机匣、手指微调。

实际查看了 `contacts-final/weapon-1-reload-50.png` 与 `weapon-2-reload-50.png`，以及 `motion-final/ar-sampled-sheet.jpg`、`sg-sampled-sheet.jpg` 中的多个换弹阶段：
前臂鼓胀、手腕收束过急，袖口出现突然变窄的浅色环；手套指节的圆片和弯钩形手指仍有积木感。SR 同样暴露这一比例问题，枪托和握把的大平面仍明显。应结构性重做前臂—腕—掌—袖口连接和肩肘动作链。

`motion-final/viewer.html` 为本地可播放采样证据，当前保存 AR 23、SG 31、SR 19 帧。固定 60 Hz 模拟、每 6 帧采样；640×400 Forward+，关闭阴影并裁剪远处细节，只用于动作诊断，不验证最终光照材质。AR/SG 图集可观察抬枪、取出弹匣和回收手臂；弹匣插入受遮挡，SR 后半程、完整归位和第三人称尚未覆盖。采样不能证明帧间接触、实操输入和移动中动作自然。

动作及其他武器接触批次为部分采集，已停止本轮这两个采集进程以集中渲染资源完成四姿势；不计完整通过。第三人称站立/蹲伏换弹、肩肘、护木支撑接触仍需实机补证。

完整四姿势曾以不带 `--pose` 的命令启动，但较早批次中断，只有 default/ADS 或零截图，不能算四姿势通过。最后一次完整批次位置为 `poses-full-retry/`，终态以其 `process-result.json` 为准；未同时获得四图、完成标记与成功退出前，人物阶段保持未通过。

## 下一阶段

先收尾完整四姿势与第三人称证据，不重复启动仍在运行的采集。依据当前前臂和袖口缺陷修改整体轮廓与关节过渡，覆盖 AR/SG/SR 换弹抽出、插入、归位的连续过程，再复查瞄准与碰撞。随后继续处理山体结构、树冠轮廓差异和道路沿线空间层次；不以截图数量或本次土肩改善判定整体画质完成。

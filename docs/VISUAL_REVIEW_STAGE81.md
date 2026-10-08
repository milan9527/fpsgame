# Stage81 — 第一人称袖口与手背形体

本轮接续 stage80，使用 stage31 独立审阅要求的同相机腰射/ADS检查；未重复 stage29 验证。

## 实施

- `tools/build_viewmodel.py`：袖口由7圈半径反复突变改为25圈连续收缩曲面，降低褶皱幅度；搭扣由2排改为9排贴合曲面，表面离布料距离由2.5mm降至0.9mm。
- 按左右手实际朝向调整手背，局部最多压平4mm，保留握持侧与指根；降低两手关节皮革凸起厚度。
- 重建 `art/first_person.blend` 与 `client/assets/first_person.glb`。本轮没有重建武器本体，也没有把旧工作区的全部改动算作本轮成果。

## 已审阅的源码实机对比

`artifacts/realism81-validation/comparison-hip-ads.jpg`、`comparison-reload.jpg`：stage80 左列、stage81 右列；原始1280×800 PNG分别保留在两阶段 `source-forward/`。

- 换弹中左腕硬环轮廓减弱，布料收口更连续；手背略扁，搭扣不再形成突出的硬台阶。
- 常规腰射和ADS整体变化较小；同相机下瞄具位置无明显变化。ADS双手多被枪体遮挡，不足以单凭此视角评价完整手型。
- 手指仍显圆钝，左拇指和掌面细节不足。枪身和枪托的大块平面、重复仓库/百叶窗、成簇草和远景树片依然明显。仅完成局部形体修正，整体目标未完成。

## 证据与范围

构建日志位于 `artifacts/realism81-validation/`。`blender-build.log` 有 `VIEWMODEL_ASSET_PASS`。Godot导入退出0，但 `import.log` 仍保留 dummy renderer 的 `Parameter "t" is null` 错误，不声称已修复；导出日志为 `export-pack.log`。

测试与包内截图的最终记录见同目录 `test-results.json`、`capture-status.json` 及预览目录 `verification.json`。测试中的 remote_snapshot 是本地快照检查，不代表真实联网。现有联网脚本依赖读取认证密钥，本轮未执行、未改认证或后台服务。

本地预览：`artifacts/realism81-preview/Linux/IronMeridian --path /tmp`（保留同目录PCK）。软件 Vulkan/llvmpipe 截图用于画面审阅，不是硬件帧率或持续人工游玩证明。

## 下一步

最终包内检查：15张原图（3武器×腰射、ADS、换弹25%/50%/75%）生成成功，截图进程退出0；已审阅 `packaged-contact-sheet.jpg` 全部画面，并放大检查 `packaged-forward/weapon-2-reload-half.png`。无明显新增瞄具错位，但精确射手步枪换弹时左拇指仍呈细长弯管，枪托和瞄具显得粗大、缺少真实结构，必须继续改进。源码另有5张原图，共20张。

源码及预览包各8项检查均有退出0和PASS记录（合计16项）：手套表面、瞄准108样本、换弹接触183样本、近墙阻挡、视图模型动作、武器视觉、本地入口碰撞、单机烟测。外层验证进程最终返回143，原因未确定；16项子进程记录已完整保存并逐项核查，不将外层异常描述为正常退出。详细证据及文件SHA256见 `test-results.json`、`capture-status.json` 和预览目录 `build.json`、`verification.json`。

优先改进第一人称枪体的机匣/护木轮廓和金属、聚合物材质分区，避免连续小修袖口；继续同机位三武器腰射、ADS、换弹核验。人物、建筑差异、地形植被、光照与不读取密钥的真实联网验收仍待推进。状态 continue。

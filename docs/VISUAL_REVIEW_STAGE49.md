# Stage49：SR 镜筒形体与同相机腰射/ADS 复核

本轮延续实际 stage48 检查点，响应 stage31 第一人称优先反馈，没有重跑 stage29。整体目标仍为 **continue**。

## 改动

`tools/build_weapon_variants.py` 的 SR 镜筒由连续锥面改为分段壳体、调节环和前缘环；调节环加入径向防滑起伏，细分提高到 128。壳体、哑光调节环与吸光内壁分别设材质。增加旋钮密封座、端盖和顶部刻度。保留原内孔尺寸插值及瞄准锚点，重建 `art/marksman.blend`、`client/assets/marksman.glb`。

手臂和手套沿用已有阶段，没有将其计为本轮新改善；通过换弹接触检查与静态截图复核。

## 实机画面审阅

打包版本运行 Godot 4.4.1 Forward+ / Vulkan llvmpipe，保存 1280×800 截图：

- `artifacts/realism49-preview/capture/weapon-2-hip.png`
- `artifacts/realism49-preview/capture/weapon-2-ads.png`
- 同目录 `weapon-2-reload-quarter.png`、`weapon-2-reload-half.png`、`weapon-2-reload-three-quarter.png`

与 stage48 使用同一检查脚本、固定角色位置与朝向，腰射与 ADS 各自对应比较。已目视检查原始腰射、ADS 和换弹拼图：

- `artifacts/realism49-validation/sr-hip-ads-before-after.png`
- `artifacts/realism49-validation/sr-reload-contact.png`

腰射时分段镜筒、调节环轮廓比原来的光滑锥体更易辨认；ADS 中心和分划线保持可见，外圈变厚，内孔没有明显新增遮挡。底部原有小凸起依然可见，不能称为完善光学模拟。侧旋钮高光仍过硬，镜体整体仍厚重，缺少真实制造细节。换弹静态姿态可见袖口与持枪手，不能据此推断整个连续动画无穿插。

背景建筑仍重复，墙面纹理泛化、地面泥草交界生硬，树林形体单一；人物、光照和场景密度仍需实质提升。本轮只完成一个武器阶段，不能代表整体画质达标。

## 验证与预览

`artifacts/realism49-validation/test-results.json`：打包版本 8 项检查全部退出 0，无 ERROR 行：

- aim_alignment：108 样本，三个武器、过渡、后坐力、侧倾与射线。
- reload_contact_rules：183 接触样本。
- viewmodel_rules、weapon_finish_rules、weapon_visuals_rules、glove_surface_rules。
- weapon_obstruction_rules：遮挡、低持枪、蹲姿、旋转、弹药权威及恢复。
- smoke：16 actors，换弹、治疗、伤害、胜负、掩体与射击间隔。

截图日志 `capture.log` 报告 `WEAPON_REVIEW_CAPTURE_PASS frames=5`，退出 0。构建、导入、导出日志均位于同一 validation 目录；无头导入仍有既有空纹理错误，不将退出 0 描述为无警告导入。

本地预览：`artifacts/realism49-preview/Linux/IronMeridian`，旁边保留 `IronMeridian.pck`。`build.json` 保存源码/资源/包哈希，`verification.json` 保存检查结果与限制，`README.md` 提供启动方式。

真实多人此前 HTTP 404，本轮未重测；remote_snapshot 检查不代表联网成功。全地图行走碰撞、连续动作和硬件 GPU 性能也未完成验证。

## 下一阶段

优先选当前截图中的建筑与院落，实质改善门窗进深、入口结构及泥土/道路/草地过渡，在相同相机保存前后截图并检查入口碰撞。另需诊断已有联网 HTTP 404，进行真正双客户端验证；不要以继续细修单个镜筒替代整体环境目标。

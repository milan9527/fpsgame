# Stage38 — 换弹左手与弹匣接触

本轮以stage37实际资源为基线，承接stage31对第一人称画面的优先要求；未重复stage29验证。改善换弹形态与接触，不声称本轮重建了武器几何或材质，更不代表整体写实目标完成。

## 实现与实际截图

`client/scripts/first_person.gd` 将抽插弹匣限制在换弹20%–80%之间，伸手和收手时弹匣留在座内；手掌对准弹匣侧面，前臂朝手腕调整方向和长度，每帧清除旧覆盖，防止姿态带入持枪和ADS。

最终本地包截图：`artifacts/realism38-preview/capture/weapon-{0,1,2}-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png`，共15张。三武器同一相机位置和朝向，腰射/ADS采用各自游戏视场；换弹检查25%、50%、75%。汇总 `artifacts/realism38-captures/all-weapons.jpg`，stage37/38步枪对照 `artifacts/realism38-captures/comparison-carbine.png`。已实看汇总及各武器换弹中段原图。

- 中段左手现在跟随抽出的弹匣，减少原来悬在弹匣与握把之间的脱离感；25%/75%取送阶段仍保持接近弹匣。腰射/ADS未见新遮挡或错位。
- 接触点误差通过不等于真实抓握：五骨手臂没有独立手指动画，手指仍像贴着弹匣，前臂使用伸缩拟合，不能当作完整人体IK。换弹中段弹匣接近画面底缘。
- 枪托大平面、SG棕色块面、SR空心镜圈仍突出；手套细节常被袖口遮挡。建筑重复、地面草簇重复、远树纸片感仍明显，人物和整体光照也尚未完成。

## 验证与边界

`artifacts/realism38-validation/` 保存日志：

- `reload_contact_rules.log`：三武器183个抽插样本，检查实际骨骼变换下的手掌与弹匣接触误差小于1mm；伸手/收手弹匣归座、换弹后覆盖清除通过。
- `aim_alignment.log`：108样本瞄准、过渡、后坐力、倾身和射线通过。
- `weapon_visuals_rules.log`：三武器外观、挂点、库存和远端快照规则通过；快照测试不是实际联网验证。
- `weapon_obstruction_rules.log`：枪口遮挡、低姿态、蹲伏、旋转枪长、弹药和恢复等规则通过。
- `packaged-offline.log`：项目目录外、隔离用户数据运行包内单机烟测通过，含16角色、换弹、治疗、伤害、胜利、射线和掩体。
- `export.log`：PCK导出成功。预览采用本机Godot4.4.1程序加PCK，缺少release模板限制未解决。

首次并发包截图中武器0保存五帧并打印PASS后发生X连接断开，进程退出1，伴随静态字符串退出错误；`packaged-capture-0.log`完整保留，不能计作干净成功。武器1退出0但有X11鼠标抓取错误，武器2退出0。武器0另以隔离数据目录顺序重跑，退出0、五帧PASS且日志无ERROR，见 `packaged-capture-0-retry.log`。Forward+ Vulkan使用llvmpipe，不证明实体GPU性能。

本轮未复验实际联网，此前登录HTTP404仍未解决。未推送、发布或部署。

## 本地预览与下一阶段

入口 `artifacts/realism38-preview/Linux/IronMeridian`，相邻 `IronMeridian.pck` 必须保留；说明和SHA256在预览目录 `Linux/README.txt`、`build.json`；`verification.json`记录已核验的程序/PCK哈希与15张可解码截图尺寸。在有图形桌面的环境运行入口即可进入本地游戏。

下一阶段优先改善枪托厚度/收边与SR镜内光学，再细化手指包握；继续人物、建筑地形植被光照和真实联网验证。整体状态continue。

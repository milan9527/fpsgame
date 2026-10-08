# Stage43：卡宾枪导轨比例与布料袖口

整体状态为 **continue**。本轮保留此前未提交修改，未推送或发布。

## 实现

- `tools/build_assets.py` 将卡宾枪原有约50毫米宽的16根方块导轨齿替换为约21.2毫米宽、10毫米节距的46段燕尾截面，增加连续底座与小倒角，修正截面面朝向；保留瞄具、枪口挂点。
- `tools/build_viewmodel.py` 将圆柱袖口替换为七环椭圆收束布面，加入轻微褶皱起伏，沿前臂方向绑定；沿用布料材质。重新生成两组 Blender/GLB。本轮没有重做枪身材质或逐指骨骼。

## 实际截图审阅

最终独立 PCK 使用 Godot 4.4.1 Forward+、Xvfb 和 llvmpipe 软件 Vulkan 截图，原图1280×800。固定角色位置、偏航和俯仰，腰射与 ADS 保留各自正常 FOV。与 stage42 对应姿态比较，未重复 stage29 验证。

`artifacts/realism43-comparison/carbine-hip-ads.png` 显示导轨明显缩窄，腰射中旧有宽梯子形状减轻，ADS 中央仍可见红点与目标，没有新增中心遮挡。`cuff-rail-detail.png` 为原始像素裁切：袖口轮廓变化较小，收束更贴近手腕，但不能据此宣称手臂已经写实。卡宾枪机匣、枪托仍有大片光滑平面，手套仍有圆管和块面感。

三种武器的腰射、ADS 与三个换弹时点共15张原图保存在 `artifacts/realism43-preview/capture/`，已通过 `all-hip-ads.png` 六格和 `all-reloads.png` 九格对照图审阅全部姿态，并审阅导轨与袖口细节对照。袖口变化不是精确的手部接触修复：SR 换弹中点手指与弹匣间隙仍需处理，掌心规则不能证明指尖接触正确。建筑盒状轮廓、重复草簇、光滑山坡与远树剪影仍明显，人物和环境本轮没有改善。

## 验证与预览

- 最终资源六项规则测试通过：瞄准108样本、换弹掌心183样本、武器遮挡、武器外观、表面材质规则与第一人称骨架行为。
- 最终独立 PCK 从 `/tmp` 启动，单机烟测通过：16角色、换弹、治疗、伤害、胜利、射线、掩体、射速与骨架。
- 日志在 `artifacts/realism43-validation/`。最终导入退出0，但仍记录 dummy renderer 的 `texture_2d_get` 空纹理错误。首轮截图在导轨面朝向修正前中止；`offline-smoke.log` 对应错误的启动参数，也中止且不计入测试。有效日志为 `capture-final.log` 和 `packaged-smoke.log`。
- 本轮没有真实多人端到端验证；此前 HTTP404 尚未解决。遮挡规则和单机烟测不等于全地图碰撞巡检。软件渲染截图不证明实体 GPU 性能。

预览入口：`artifacts/realism43-preview/Linux/IronMeridian`，需要相邻 `IronMeridian.pck`。这是引擎二进制加 PCK 的本地开发预览，缺少 release 导出模板。包内 `build.json`、`verification.json` 记录来源、哈希、测试和截图证据。

下一阶段应提升全景收益：建筑入口与窗框纵深、草丛疏密和地面过渡，补近景及移动截图；继续处理逐武器手指接触和枪身表面，安排真实联网 HTTP404 诊断及主要通道碰撞巡检。不能把本轮局部形体改善当作整体目标完成。

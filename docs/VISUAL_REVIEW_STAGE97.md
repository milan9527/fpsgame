# Stage97 — 机匣凹面与资产法线保留

本轮状态：continue。整体写实画面目标尚未完成，不能将这次局部改善视为完成。

## 实际修改

- 卡宾枪机匣侧面两条浅矩形槽改为带斜端和结构边缘的布尔凹面，重建 `art/carbine.blend` 和 `client/assets/carbine.glb`。
- 为机匣与护木生成低幅度切线空间金属法线。修复 `world_visuals.gd` 在运行时覆盖资产法线的问题，保留导入的贴图与强度；测试覆盖实际模型中的两个烘焙法线材质。
- 本轮未重塑手臂，沿用 Stage96 资产。不能把之前的袖褶工作计为本轮改善。

## 实际截图审阅

证据目录：`artifacts/realism97-validation/`。`stage96-97-receiver-comparison.png` 为固定世界相机的前后腰射/ADS原生像素裁切；ADS本身有正常视场变化。完整截图位于 `source-forward/` 与 `packaged-forward/`。

源码卡宾枪腰射、ADS和半程换弹原图显示：矩形切口感有所降低，金属微表面保持克制，但枪身主体仍是较大的平滑黑色块面。ADS前后变化很小，准星居中且视野没有明显新增遮挡。换弹时右手接触生硬、掌面厚，支撑手仍有块状手套感；袖子仍像长筒。HUD投掷物区域与下部武器/袖子有重叠。下一轮需要成组调整机匣轮廓与握持手形，不能继续仅靠微小凹槽和法线变化。

背景依然存在重复稀疏草丛、空旷地表、重复立面与偏方块的建筑，远景树木与山体层次有限。本轮没有改善人物、建筑、地形植被或光照。

## 验证范围与局限

最终驱动退出0：源码及PCK预览各11项功能检查，共22项通过，加导出与两次截图采集共25条成功记录，保存30张截图。已查看两组截图总览、源码卡宾枪腰射/ADS/半程换弹及包内腰射/ADS原图，包内未见明显缺失材质。证据见 `test-results.json`、`verification.json`、截图总览和 `screenshot-index.json`。检查覆盖单机流程、三把武器、108组瞄准样本、换弹接触规则、武器遮挡、门口/屋顶碰撞及联网状态规则。接触规则通过不代表手形已经自然；联网状态规则不等于真实多人会话验证。

Blender构建成功，Godot导入退出0，但导入日志仍有 dummy texture storage 的 `Parameter "t" is null` 错误，尚未解决。保留早期不适用于烘焙材质的断言失败日志 `weapon-finish-legacy-assertion.log`；修正断言后重新完整验证，不能以早期结果代替最终结果。

截图使用 Xvfb + Forward+ / llvmpipe 软件Vulkan，不代表真实GPU性能。真实多人和更广泛场景碰撞尚未验证。

本地预览：`artifacts/realism97-preview/Linux/IronMeridian`，需保留相邻PCK。从项目根目录运行：

```bash
./artifacts/realism97-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus
```

这是 Godot 4.4.1 可执行文件加导出PCK，非标准导出模板发行包。未push或发布。

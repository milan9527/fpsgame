# Stage72：机匣凹槽、握把截面与袖子体积

2026-09-13。状态 **continue**。这是第一人称模型的一次局部重建，整体写实目标尚未达成。

本轮修改 `tools/build_assets.py`：移除卡宾枪侧面的厚斜筋和叠加面板，在机匣实体上切出凹槽，使用齐平销钉；降低金属亮边和法线强度。握把从平面挤出改为七层椭圆截面的连续曲面，并修正面朝向。修改 `tools/build_viewmodel.py`，压扁袖子截面、调整弯曲中心和底部下垂量。重建两个 Blender 文件及 GLB，保留瞄具、握持挂点与既有动作。

## 实际截图审阅

来自本轮导出包的 Forward+ Vulkan / llvmpipe 软件渲染，1280×800。沿用 stage71 固定角色位置 `(17, .05, 50)`、朝向与俯仰；每个姿态推进90帧。腰射和ADS保持相同站位/朝向，ADS保留游戏自身变焦。未重复stage29验证。

- `artifacts/realism72-validation/carbine-before-after.png`：stage71/72同机位腰射和ADS对照。腰射机匣的粗亮斜筋消失，表面更平整暗哑；凹槽在全图尺寸下不突出。主体仍像方形机加工块，尚未消除积木感。
- `artifacts/realism72-validation/all-poses-review.png`：五姿态拼图。腰射、ADS及换弹25%/50%/75%均已查看；另查看腰射和换弹50%原图。袖子下垂和不对称截面有变化，但腰射对比幅度有限；换弹时仍显宽厚，手指/手掌解剖和握持外形仍需改善。
- `artifacts/realism72-validation/packaged-forward/`：五张未经拼接的实际游戏截图。ADS红点和视线无明显新偏移，当前画面没有发现新增大面积破面；截图不能证明所有动态接触或穿模均正确。
- 建筑仍重复、草丛分布与地面过渡生硬、山体光滑，整体远未达到目标方向。人物本轮没有新增实机审阅证据。

## 验证与预览

`artifacts/realism72-validation/stage-results.json` 汇总源项目和包内各六项检查，均退出0：108瞄准样本、183换弹接触样本、武器抵墙/遮挡规则、第一人称骨骼动作、武器快照以及16演员单机烟测。截图脚本报告 `WEAPON_REVIEW_CAPTURE_PASS frames=5`，无运行错误。对应原始日志保存在同目录；快照测试不代表真实双客户端联网通过。

导出退出0。本地启动：

```sh
./artifacts/realism72-preview/Linux/IronMeridian --path /tmp
```

同目录提供 PCK、README、许可说明、build.json 哈希和 verification.json。该包已用于上述截图和包内检查，未上传发布。

仍有明确限制：`artifacts/realism72-validation/import.log` 出现一次 `Parameter "t" is null.` 导入错误，未解决；真实联网、实体GPU性能和完整人工连续移动碰撞未验证。自动抵墙与射线规则通过不能替代后两类验证。

## 下一阶段

应转向可明显改变画面的大项：建筑用途/体量差异、道路泥草边界，并结合连续移动碰撞和真实双客户端检查。第一人称仍需整体机匣轮廓、手掌手指及衣袖结构改善，避免继续仅添加小零件。人物和光照也需后续实际游戏截图审阅。

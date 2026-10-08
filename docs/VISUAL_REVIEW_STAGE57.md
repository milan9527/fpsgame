# Stage57：护木截面与袖料迷彩尺度

日期：2026-09-13。状态：continue，整体写实目标未完成。

本轮按 stage31 的第一人称优先反馈，在 stage56 基础上修改了两项资产：

- `tools/build_assets.py`：AR 护木由矩形壳体改为前端收窄的八边形截面，加入斜切侧面、空腔、通风孔和下侧防滑条；保留原有瞄准及枪口锚点。
- `tools/build_viewmodel.py`：袖料及补强片 UV 同步增加 2.6 倍重复率，缩小之前过大的迷彩块。保留 stage56 袖管形体及骨骼。

两份 Blender 源文件及 GLB 已重建，日志位于 `artifacts/realism57-validation/blender-carbine.log` 和 `blender-viewmodel.log`。

## 实拍审阅

`tests/weapon_review_capture.gd` 在 Godot 4.4.1 Forward+ / Vulkan llvmpipe 下生成实机画面；人物位置 `(17, 0.05, 50)`、朝向及俯仰与 stage56 一致。腰射、ADS 各自保留正常视野倍率。截图来自当前工作树，导出包另作独立单机烟测。软件 Vulkan 不能代表实体 GPU 性能。

原图：`artifacts/realism57-validation/after/`。AR 同机位对照：`artifacts/realism57-validation/carbine-comparison.jpg`，左 stage56、右 stage57，依次腰射、ADS、换弹中段；仅缩放排版，未修饰游戏画面。

截图进程退出 0，共 15 张，覆盖三武器腰射、ADS 与三个换弹阶段。已自审 `contact-sheet.jpg`、AR 对照及腰射/ADS 原图、精确射手步枪换弹中段原图；不是独立审阅。换弹手指仍偏细、弯曲呈钩状，伸臂袖料有纵向条纹感，后续需继续改善。

实际收益与局限：

- 迷彩从大块斑纹变为较细的布料图案，腰射及换弹伸臂时最明显。袖管仍显偏直，褶皱与手套的体积关系仍需改善。
- 护木斜面和收窄结构取代矩形截面，但被支撑手及机匣遮住较多，正常腰射收益有限，ADS 中更不明显。不能将此算作枪械积木感已解决。
- AR 腰射和 ADS 未见新增明显穿插；ADS 红点及目标可见。机匣的大平面、粗厚机械件和瞄具轮廓仍较简化。
- 建筑重复、空院落、草丛离散和地表衔接问题仍明显。本轮未改善人物全身、建筑、地形或光照，不代表总体画质完成。

## 验证及预览

`artifacts/realism57-validation/tests.json`：10 项检查退出码均为 0，无记录到的运行错误。包含三武器瞄准 108 样本、换弹接触 183 样本、视图模型、武器材质、手套表面、抵墙碰撞、预测、可靠动作及 16 人单机烟测。网络规则测试不等于真实联网验证。

本轮 `/health`、`/protocol`、`/openapi.json` 仍由 `http://127.0.0.1:8000` 返回 404，详见 `network-probe.json`。真实双客户端联机仍未验证；未修改后台服务。

导入退出 0，但 `import.log` 仍记录两条 `Parameter "t" is null`；导出成功，保留该问题，不宣称导入完全无误。导出包烟测退出 0 并输出 `OFFLINE_SMOKE_PASS`，见 `preview-smoke.log`。

从仓库根目录启动：

```sh
./artifacts/realism57-preview/Linux/IronMeridian --path /tmp
```

目录内为 Godot 可执行文件与相邻 PCK，附授权文件、README、构建哈希及验证清单；属于开发预览。保留既有未提交修改，未推送或对外发布。

下一阶段应优先推进院落建筑差异与道路泥草过渡，补实拍和入口/移动碰撞验证；继续细化可见机匣和手臂体积，并补人物近景、光照审阅。API 恢复后验证真实双客户端。

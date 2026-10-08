# Stage96 — 袖子连续布面与支撑拇指弯折

本轮以 Stage95 实际文件为起点；已读取 Stage29、30、31 独立审阅反馈，没有重跑 Stage29。目标仍未完成。

## 修改与画面判断

`tools/build_viewmodel.py` 将多层鼓包式袖褶改成连续布面、斜向窄压褶和纵向收束，缩小支撑手虎口并调整拇指中间关节位置；重新生成 `art/first_person.blend`、`client/assets/first_person.glb`。本轮没有改进枪械结构或材质参数，不能将这些部分计为完成。

`artifacts/realism96-validation/stage95-96-hand-comparison.png` 为同机位腰射和 ADS 原生像素裁图。腰射袖子斜向压褶比 Stage95 明确，减少部分光滑鼓包；拇指有更明显的转折。ADS 下变化较小，袖子仍显筒状，布面缺少真实厚度和自然垂坠；拇指仍像折弯硬条，与护木接触不自然。

单独查看源码 `weapon-0-hip.png`、`weapon-0-ads.png`、`weapon-0-reload-half.png`：准星视野保持可用；换弹时袖褶可见，但掌面仍厚，手指抓握关系不够可信。枪机匣大平面、简化瞄具、重复建筑和均匀草丛仍明显。人物与其他场景未在本轮做新视觉验证。

## 验证范围

源码及预览包各10项规则/功能检查覆盖单机流程、瞄准、换弹接触、枪口遮挡、第一人称骨架、三武器显示、门口及屋顶碰撞、联网状态规则，详见 `artifacts/realism96-validation/test-results.json`。联网状态规则不是实际多人会话，本轮未验证真实联网。

最终驱动退出0：20项功能检查、导出与两次截图采集共23条成功记录，保存30张截图并核对截图哈希及6个构建文件哈希，见 `verification.json`。已查看源码及包内两张15帧总览，以及包内卡宾枪腰射、ADS原图；包内画面同样保留清晰斜褶和上述形体缺陷，未见该组截图中的武器或手臂缺失。总览审阅不等同于逐张原图细查。

使用未修改的 `tests/weapon_review_capture.gd`，固定位置与朝向，三武器各采集腰射、ADS、换弹三个时刻；ADS 保留游戏本身视野缩放。截图通过 Xvfb + llvmpipe Forward+ 渲染，不代表硬件性能。导入退出0，但 `import.log` 仍有 `Parameter "t" is null`，尚未修复。

本地预览运行命令：`./artifacts/realism96-preview/Linux/IronMeridian --path /tmp --rendering-method forward_plus`。同目录 PCK 必须保留；这是 Godot 可执行文件加导出资源包，不是标准导出模板发行包。构建及截图哈希分别见预览目录 `build.json` 与验证目录 `screenshot-index.json`。

下一阶段应成组改善枪械机匣/护木材质和握持手形，避免持续孤立微调拇指；随后推进人物、建筑差异、植被布局与光照。另需排查导入错误、补真实联网与更广泛碰撞验证。

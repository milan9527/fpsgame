# Stage54 第一人称袖管形体与机匣分层

本轮落实 stage31 和最新 stage53 的第一人称优先反馈：扩大肘部布料体积、收束腕部，加入沿袖管的弯曲中心线和更明显的局部褶皱；AR机匣侧面改为轮廓肩线、内凹检修面板及齐平销钉。重建 `art/first_person.blend`、`art/carbine.blend` 及对应GLB，保留已有材质与握持锚点。本轮不重复 stage29 验证，也不将局部进展视作整体目标完成。

## 实际画面审阅

当前本地PCK通过 Godot 4.4.1、Forward+、Xvfb 1280×800、llvmpipe 渲染。沿用 `tests/weapon_review_capture.gd` 的固定位置 (17, 0.05, 50)、方向和俯仰，对比腰射和正常FOV下的ADS。截图为运行游戏场景的受控姿态捕获，不代表人工完整游玩或物理GPU性能测试。

`artifacts/realism54-validation/stage53-54-ar-comparison.jpg` 左列为stage53、右列为stage54。对照确认腰射左袖的弯曲、肘部鼓起和腕部收束比此前明显；ADS袖子轮廓变化可见，红点中心仍清晰。AR换弹半程原图可见袖管弯折与织纹，未见明显袖口断裂。机匣侧面零件有分段，但在正常画面尺寸下改善小于袖管，枪身仍平暗，不能称为写实枪械已经完成。

原图位于 `artifacts/realism54-validation/after/`。本记录为开发进程自审，不是独立审阅。有限姿态与缩略图不能排除所有动画瞬间的细小穿插。人物、建筑和环境本轮没有改动：仓库重复、院落空旷、草丛分布规律、远山光滑和整体光照平淡仍明显。

已审阅 `artifacts/realism54-validation/contact-sheet.jpg` 中三武器全部15个姿态；三种ADS瞄具中心可见，狙击镜原图分划线清晰。截图日志含 `WEAPON_REVIEW_CAPTURE_PASS frames=15`，但工具报告进程最终退出143，原因未确定，不能记为正常退出0。15张原图均可解码，截图产物完整；这不消除退出异常。

## 验证与可运行预览

`artifacts/realism54-validation/tests.json` 汇总当前包10项检查，均退出0且有PASS：瞄准108样本、三武器换弹接触183样本、抵墙碰撞、视图模型、武器外观、布料/手套表面、枪械材质、预测、可靠动作和16角色单机烟测。预测及可靠动作属于规则验证，不能替代真实联网。

Blender两次构建成功；导入完成但保留既有 `Parameter "t" is null / texture_2d_get` 错误。Linux release导出因缺失模板失败，保留 `export.log`；改用成功导出的PCK配套现有Godot可执行程序，不能称为release模板构建。

项目根目录运行：

```sh
./artifacts/realism54-preview/Linux/IronMeridian --path /tmp
```

保留相邻 `IronMeridian.pck`，进入 SOLO 单机。目录中的README、build.json和verification.json记录启动方法、哈希及验证证据。该包已经用于本轮规则测试和图形截图。

`artifacts/realism54-validation/network-probe.json` 显示本机8000端口的 `/health`、`/protocol`、`/openapi.json` 仍均HTTP404、SimpleHTTP服务器。真实多人受缺失API阻塞；未修改后台服务，未发布、推送或部署资源。

下一阶段优先让院落、道路泥草和植被分布出现实际可见的差异，复核人物近景及光照；保留第一人称姿态回归。API可用后补齐真实双客户端验证。整体状态 continue。

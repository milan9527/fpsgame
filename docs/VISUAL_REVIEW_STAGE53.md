# Stage53 第一人称布料与枪身材质复核

本轮完成袖管加固布片、织物法线与枪身/瞄具哑光材质的开发和当前导出包验证。整体写实目标尚未完成，状态 continue。

## 改动及画面

`tools/build_viewmodel.py` 加入贴合袖管网格的加固布片与织物中尺度法线起伏，重建 Blender 与 GLB。`world_visuals.gd` 降低涂层金属金属度、提高粗糙度，修正机匣与聚合物颜色，并覆盖此前遗漏的 Optic 材质。袖子法线/UV和瞄具材质覆盖加入规则验证。

实际导出包以 Godot 4.4.1 Forward+、Xvfb 1280×800、llvmpipe 渲染，固定角色位置 (17, 0.05, 50)、相机方向与俯仰；ADS 使用正常武器 FOV。`tests/weapon_review_capture.gd` 启动单机场景后固定模拟，捕获三把武器腰射、ADS、换弹四分之一/一半/四分之三共15张。属于受控实机渲染，不是人工完整游玩或硬件性能测试。

已查看全部15张缩略总览、AR腰射/ADS原图及stage52/53对照。枪身蓝灰反光减弱，瞄具外壳与机匣色调统一，袖面可见织纹；红点视野保持清晰，三把枪总览未见明显遮挡瞄准中心或新增大面积穿插。加固布片在正常视角并不醒目，不将网格增加当作显著形体进步。袖管仍偏直、机匣仍有大片平面，迷彩图案与轮廓依然缺少自然衣料的层次；换弹缩略图不能排除所有细小穿插。场景建筑重复、院落空旷，草丛分布和远山仍明显程序化，本轮未改善第三人称人物或环境。

证据：`artifacts/realism53-preview/after/` 原图；`artifacts/realism53-validation/contact-sheet.jpg` 全姿态；`hip-before-after.jpg`、`ads-before-after.jpg` 同机位对照。画面改善有限，不能据此宣告整体目标完成。

## 验证和预览

Blender重建退出0；无头导入退出0但仍有一条 `Parameter "t" is null / texture_2d_get` 错误，不能称为无错误导入。导出退出0；图形捕获退出0并记录 `WEAPON_REVIEW_CAPTURE_PASS frames=15`。

当前导出包10项检查全部退出0，详见 `artifacts/realism53-validation/tests.json` 和同目录日志。包含瞄准108样本、三武器换弹接触183样本、抵墙碰撞、视图模型、武器外观、布料/手套UV法线、23个枪械表面材质、预测、可靠动作和16角色单机烟测。预测和可靠动作是规则测试，不能替代真实多人联机。

本机8000端口 `/health`、`/protocol`、`/openapi.json` 均返回HTTP404，服务器标识SimpleHTTP。真实双客户端联网仍受API缺失阻塞，未修改服务、未伪造结果。

预览：从项目根运行 `./artifacts/realism53-preview/Linux/IronMeridian --path /tmp`，保留相邻PCK。README、build.json、verification.json记录启动方法、哈希和证据。保留未提交工作区，未推送或发布。

下一阶段应做正常游戏尺寸下能明显辨认的袖管弯曲/肘腕受力形体与机匣倒角、零件层次，继续同机位腰射/ADS审阅；还需改善人物、院落差异、道路泥草过渡及光照，并在API可用后完成真实双客户端测试。

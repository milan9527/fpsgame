# Stage67：拉机柄形体、袖口与布料材质

本轮是包内截图自审，不是独立审阅；整体目标仍未完成。

- `tools/build_assets.py`：卡宾枪拉机柄缩小薄颈，左右拨片改为不同长度的弯钩轮廓，亮色横齿改为细小暗色抓握纹，保留动作锚点。
- `tools/build_viewmodel.py`：共享袖口减薄、增加不均匀收褶，袖料增加打包进GLB的高粗糙度纹理。重新生成 carbine.glb、first_person.glb 和本地预览PCK；材质导出信息见 `artifacts/realism67-validation/exported-materials.json`。

## 实际画面

固定位置 `(17, 0.05, 50)`、相同基础朝向，分别检查三武器腰射、ADS和换弹三个时刻，共15张1280×800截图。ADS保留各武器实际变焦。使用独立预览包、工作目录 `/tmp`，Forward+ Vulkan llvmpipe 软件渲染，截图程序PASS且退出0。

- 原图：`artifacts/realism67-validation/packaged-forward/`
- 已审阅全图拼版：`artifacts/realism67-validation/all-poses-review.png`
- stage66/67卡宾枪腰射、ADS、换弹对照：`artifacts/realism67-validation/carbine-before-after.png`

腰射的拉机柄更薄，弯钩轮廓可辨，原来的亮色粗杆感减少；ADS投影仍有横条感。袖口体量降低，袖料更哑光，但褶皱依然偏软、像黏土，手指握持和枪械大面还不够自然。15张截图未见明显新增穿插；静态采样不能证明完整动作无穿插。场景仍有重复仓库、空旷地表、扇形草簇和单薄远景树，不能据此认定达到整体写实目标。

## 验证与限制

包内六项规则测试全部退出0：108个瞄准样本、183个换弹接触样本、抵墙规则、第一人称动作、手套/袖料表面和武器视觉规则。包内单机烟测16演员，装弹、治疗、伤害、胜利、射线、掩体和射速检查PASS且退出0。见 `artifacts/realism67-validation/tests.json`、`smoke.log` 和 `stage-results.json`。未重复stage29验证。

导入日志仍有一次 `ERROR: Parameter "t" is null.`，未解决；导出完成且包内图形截图正常。Compatibility黑草未复测，实体GPU与完整人工移动未验证。本机8000端口 `/health`、`/protocol`、`/openapi.json` 均404，真实双客户端联网未验证；远端快照规则通过不能替代联网测试。未修改后台服务或发布。

本地启动：`./artifacts/realism67-preview/Linux/IronMeridian --path /tmp`。预览目录附README、build.json、verification.json及许可证。

## 下一步

实质改善重复仓库的体量与用途差异、道路泥草边界，补移动碰撞和场景截图；继续袖管布料形体、自然握持、人物光照，并在后端可用时补真实双客户端验证。

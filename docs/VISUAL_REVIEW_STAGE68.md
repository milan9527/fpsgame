# Stage68：袖管形体、独立补强布料与包内验证

本轮状态为 continue，整体目标未完成。保留此前工作树修改；本轮重建共享第一人称手臂，没有将此前枪械修改计作本轮成果。

## 实际修改

- `tools/build_viewmodel.py` 收窄袖肘半径（0.058→0.052），减小中段鼓包，增加定向收褶；压暗橄榄色布料。
- 补强片使用独立深色斜纹材质和打包染色纹理，保留法线、粗糙度。重建 `art/first_person.blend`、`client/assets/first_person.glb`。
- 扩展 `tests/glove_surface_rules.gd`，对独立补强片执行纹理、法线、非金属和有效UV检查。首次检查发现 Solidify 边缘的退化UV；修复为在应用修改器前添加缝边材质槽，让薄边使用无纹理缝边材质，宽面保持斜纹。没有放宽95%有效UV阈值。失败证据保留在 `artifacts/realism68-validation/glove-surface-before-fix.log`。

## 实机画面自审

从本地导出的PCK启动，以 `/tmp` 为运行路径，使用 llvmpipe 软件 Vulkan Forward+。固定角色位置及朝向，保留各武器正常ADS视野变化，生成三把武器的腰射、ADS及25%/50%/75%换弹共15张图。截图脚本完成且退出0。

已查看15姿态总览、卡宾枪stage67/68同机位对照以及卡宾枪腰射/ADS原图：

- `../artifacts/realism68-validation/all-poses-review.png`
- `../artifacts/realism68-validation/carbine-before-after.png`
- `../artifacts/realism68-validation/packaged-forward/`

腰射袖管收窄、明度降低可见，ADS左前臂也减少了原先浅亮的大块布面。补强片分区较细微；袖管仍像柔软管体，折痕缺乏自然受力关系。枪身大面、握持姿态仍不够写实。总览未见明显新增的大面积穿插，但15个静态姿态不能证明连续动画无穿模。

环境依旧存在重复仓库、空旷泥草地、扇片草丛和远树平面感。此次没有改善人物、建筑或环境光照，不能据此认定整体画质达标。

## 验证及预览

证据目录：`artifacts/realism68-validation/`，汇总 `stage-results.json`。

- 六项包内规则测试通过：瞄准108样本，换弹接触183样本，抵墙规则，第一人称骨架，手套/袖料表面，三武器视觉规则。表面检查覆盖4材质、94064三角形。
- 包内单机烟测通过并退出0：16演员，换弹、治疗、伤害、胜利、射线、掩体、射速和骨架。
- `capture.log` 包含 `WEAPON_REVIEW_CAPTURE_PASS`；`build-viewmodel.log` 记录资产重建。`exported-materials.json` 保存导出材质信息。
- 导入仍有一次 `Parameter "t" is null.` 错误；导入和导出进程退出0并不表示该错误已解决。汇总也保留了修复前测试错误。
- 本轮没有真实双客户端联网、完整人工移动碰撞或实体GPU性能验证；未复测此前Compatibility黑草和API 404，不将历史结果当作新测结果。

本地启动：`./artifacts/realism68-preview/Linux/IronMeridian --path /tmp`。
预览目录包含PCK、可执行文件、许可证、README、`build.json`哈希及`verification.json`。来源为包含既有未提交修改的工作树，不是干净提交构建。没有发布、push或修改后台服务。

下一阶段应实质改变仓库体量/用途和道路泥草边界，并补场景移动碰撞与截图；继续手臂受力褶皱、枪械大面和人物画质，后端可用时补真实双客户端验证。

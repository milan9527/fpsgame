# Stage77：手套网格修复、同机位审阅与弹匣归属诊断

本轮整体状态：continue。未达成整体写实画质目标。

## 实际修改

`tools/build_viewmodel.py` 在手部合并前应用已有细分等修饰器（原来直接移除），保留蒙皮的后续重建；掌面统一织物、提高小面积皮革底色；体素融合后按材质边界简化，再生成UV。重建 first_person.blend 和 first_person.glb。
手套表面检查覆盖的三角形从183546降到85836，约减少53%；这是网格成本改善，不是帧率提升的测量。左手14201顶点，主连通块14140、另有61顶点小岛；右手12189顶点单连通块；两手非流形边均0。左手小岛仍需后续判断和清理。

## 真实截图审阅

`artifacts/realism77-validation/packaged-forward/weapon-0-{hip,ads,reload-quarter,reload-half,reload-three-quarter}.png` 为当前导出包、1280×800、Godot4.4.1 Forward+ llvmpipe 软件Vulkan截图。固定相机与stage76一致；capture.log记录5帧PASS，capture-exit.txt为0。
已查看 comparison-all-poses.jpg 与 comparison-hand-crop.png：腰射和ADS构图稳定，未见新的明显破面；枪身暗部、织物规则纹理仍偏人工，手掌形体的可见改善很小，不能称已解决。换弹枪托占比依旧较大。建筑重复盒形、植被铺陈重复、远景山体及光照偏平仍明显。

为避免错误归因，运行独立 magazine-diagnostic.gd，仅在诊断运行中将 Magazine 节点覆盖为无光照橙红材质。`magazine-diagnostic/weapon-0-reload-half.png` 清楚显示此前掌心附近的尖角深色块就是弹匣；不是手套掌部。诊断正常退出0，未改游戏材质或预览包。下一轮应优先修改 tools/build_assets.py 的 carbine Magazine 挤出轮廓、曲面分段与表面结构，保留安装及抓握接触，避免继续盲改手掌。

## 验证与预览

`artifacts/realism77-validation/test-results.json`：源码及包内各7项，14/14退出0且PASS；覆盖手套材质UV、三武器108瞄准样本、183换弹接触样本、枪口遮挡规则、第一人称动作、武器可视规则、16角色单机流程。remote_snapshot检查不等同真实联网，本轮未验证真实多客户端联网、实体GPU或完整人工移动碰撞。
导入日志仍报 `ERROR: Parameter "t" is null.`，后续导出和运行成功；不能将此描述为无错误导入。
本地运行 `./artifacts/realism77-preview/Linux/IronMeridian --path /tmp`；同目录build.json记录实际哈希，verification.json保存测试结果。未推送、发布或提交。
